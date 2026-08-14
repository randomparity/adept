# Persist the forge whole-branch review

## Goal

Retain `$forge`'s whole-branch review until `$quest` publishes and verifies it in the pull request's
`WORK:REVIEW` annotation, then dispose of the ignored artifacts safely.

The implementation adds one deterministic Bash helper for the stateful snapshot/comment operation.
`$forge` owns production and retention, `$quest` owns publication after PR creation, and the helper
owns byte framing, ledger transitions, GitHub reconciliation, and exact cleanup ordering. Standalone
`$deliver` and `$return-to-town` remain unchanged.

Tech stack: Bash 3.2, Git, GitHub CLI, `jq`, `iconv`, existing repository shell fixtures.

## Global Constraints

- Bash is 3.2 with `#!/usr/bin/env bash` and `set -euo pipefail`; no associative arrays, `mapfile`,
  or `readarray`.
- Shell source lines are at most 100 characters and tab-indented per repository convention.
- Do not add dependencies. `gh`, `jq`, `iconv`, Git, and the repository public-safety script are the
  only external commands used by the helper.
- `.agent/` remains ignored scratch space. No host path, token, rejected review body, or private
  environment detail enters tracked files or public failure messages.
- One active quest controller per issue is the supported operating model. Duplicate publication
  tokens fail closed and require operator repair; the helper never deletes PR comments.
- Preserve the existing `WORK:REVIEW` summary fields and complete sentinels. The forge review is a
  separate indented payload section.
- A required forge-review failure remains terminal. Only a verified mode in which no forge review
  was required may publish `forge review: not required`.
- Full guardrail: `just verify`. CI hard-gates the same chain through `just ci`.
- Architecture context: host `arm64`; target architectures `none declared`; relationship
  `no-target-declared`.

## File map

- Create `skills/quest/scripts/publish-forge-review`: deterministic publication transaction and
  resume helper.
- Create `tests/fixtures/quest/publish-forge-review-test.sh`: behavior fixtures for publication,
  framing, failure, reconciliation, and cleanup.
- Modify `skills/forge/SKILL.md`: retain the consumed final review for PR publication and expose its
  ledger/path contract.
- Modify `skills/quest/SKILL.md`: carry the retained artifact, invoke the helper after PR creation,
  and treat helper failures as blockers.
- Modify `skills/quest-log/SKILL.md`: document the additional labelled forge-review payload and
  publication-token field within `WORK:REVIEW`; existing summary consumers remain unchanged.

## Task 1: Add the deterministic publication transaction

### Interfaces

- Command: `skills/quest/scripts/publish-forge-review <repo> <pr> <mode>
  <review-or-reason> <ledger> <summary-file>` where mode is `required`, `not-required`, or `failed`.
- Consumes a safe controller-written summary fragment without outer markers; a non-empty forge
  review; an existing forge progress ledger; repository identity and PR number.
- Produces one verified complete `WORK:REVIEW` comment for `required`/`not-required`, a retained
  canonical snapshot until verification when required, and ledger lines for `intent`, `pending`,
  `verified`, and `disposed`. `failed` exits before any GitHub write.
- Exit 0 prints only the verified public comment URL. Nonzero prints one actionable public-safe
  diagnostic and retains evidence.
- Task 2 relies on this exact positional interface and exit contract.

### Steps

1. Create `tests/fixtures/quest/publish-forge-review-test.sh` with a temporary Git repository, an
   ignored `.agent/sdd/` workspace, a fake `gh` executable ahead of `PATH`, and fixtures that record
   comment requests as JSON pages. Use the repository fixture cleanup helpers and a trap so every
   test removes its state.

2. Add failing cases before the helper exists:

   - `PFR-1`: safe review with empty interior lines and no final newline publishes one complete
     annotation; the fake API readback matches; ledger order is intent → pending → verified →
     disposed; source and snapshot are gone only after verification.
   - framing table cases: final LF, CRLF, bare CR, invalid UTF-8, and NUL. Valid cases produce the
     same canonical LF payload; invalid cases never call comment creation.
   - `PFR-2`: public-safety rejection and source/snapshot mutation never publish changed bytes and
     retain evidence. Mutations at both pre-post seams keep the GitHub post count at zero.
   - `PFR-3`: `not-required` publishes a summary-only annotation with its verified public-safe
     reason; `failed` exits before any GitHub write; `required` rejects an absent or empty review.
   - `PFR-4`: older complete annotations and multiple paginated pages do not confuse token
     selection; ambiguous success found by token does not retry; incomplete pagination stops;
     duplicate-token comments stop and print their public URLs.
   - `PFR-5`: comment-size/service rejection retains source and snapshot.
   - `PFR-6`: resume at each ledger seam adopts the same token and paths; incomplete owned temp is
     trashed and recopied; completed snapshot is validated; verified publication plus absent
     artifacts appends disposal without a second deletion.
   - `PFR-7`: review text containing summary-shaped fields and literal outer marker/sentinel lines
     remains indented payload; exact comment-body comparison succeeds without treating those lines
     as structure.

3. Run the fixture bare:

   ```sh
   ./tests/fixtures/quest/publish-forge-review-test.sh
   ```

   Expected: nonzero with `publish-forge-review: not found` before implementation. This is the
   recorded red proof.

4. Create `skills/quest/scripts/publish-forge-review` with these concrete operations in order:

   ```text
   validate six arguments, the mode enum, and mode-specific input
   resolve repository root and require review/ledger beneath its ignored .agent/ tree
   recover the latest complete intent/pending/verified/disposed state from append-only ledger lines
   when no intent exists: mint token, derive temp/final paths, append and read back intent
   canonicalize through iconv into the recorded temp, reject NUL, normalize CRLF/CR to LF,
     force exactly one final LF, verify regular non-empty output, atomically rename temp to final
   compute snapshot byte length and SHA-256; run public safety against that final snapshot
   append and read back pending(token,path,snapshot-length,snapshot-digest)
   indent each canonical line by four spaces and compose a helper-owned temporary body with one
     outer
     WORK:REVIEW block, summary first, publication token field, forge heading, payload, sentinel
   re-read snapshot length/digest after composition and stop on either mismatch
   run public safety against the exact completed body; compute and record body length/digest
   atomically rename the body temporary to its ledger-owned final path; revalidate its digest
   exhaustively collect repos/<repo>/issues/<pr>/comments through `gh api --paginate --slurp`
   reject incomplete/malformed pages; select by exact token plus exact body equality
   if absent, post once with `gh pr comment --body-file`; on failure reconcile before one retry
   collect again; require exactly one exact match and capture comment id/url
   append and read back verified(token,comment-id,snapshot-digest,body-digest)
   re-read the exact comment and require exact body equality
   move source and snapshot to trash with the platform recoverable-delete command
   append and read back disposed(token,former-paths); print comment URL
   ```

   Use functions under 100 lines with one purpose: `fail`, `append_ledger`, `read_state`,
   `canonicalize`, `compose_body`, `collect_comments`, `match_publication`, `post_once`, and
   `dispose_artifacts`. Use explicit `case` handling for every command status. Never interpolate
   body content into a shell command.

5. The fake `gh` supports `api --paginate --slurp` and `pr comment --body-file`. Make failures and
   ambiguous writes selectable by fixture environment variables. The tests assert observable
   files, ledger ordering, request count, exit status, and exact comment JSON—not implementation
   function names.

6. Run focused checks:

   ```sh
   ./tests/fixtures/quest/publish-forge-review-test.sh
   shellcheck -x skills/quest/scripts/publish-forge-review \
     tests/fixtures/quest/publish-forge-review-test.sh
   shfmt -d skills/quest/scripts/publish-forge-review \
     tests/fixtures/quest/publish-forge-review-test.sh
   ```

   Expected: all fixture cases pass; ShellCheck and shfmt emit nothing and exit 0.

7. Verify the tests bite by changing the implementation locally so disposal runs before verified
   ledger readback. Run the fixture and observe `PFR-1` fail. Restore the implementation only after
   the passing version has been staged or committed safely.

8. Commit explicit paths:

   ```sh
   git add skills/quest/scripts/publish-forge-review \
     tests/fixtures/quest/publish-forge-review-test.sh
   git commit -m "feat: publish forge reviews durably"
   ```

### Acceptance criteria

- All seven PFR scenario groups, including all three mode arms, pass on Bash 3.2 syntax.
- No GitHub post, retry, or deletion occurs without its preceding durable/readback evidence.
- Posted bytes derive only from the canonical snapshot that passed public safety.
- Failure output never contains the rejected body or a private path.

## Task 2: Wire forge retention into the quest lifecycle

### Interfaces

- Consumes Task 1's exact six-argument command and comment-URL output.
- `$forge` produces `Final review <range>: retained for PR publication (review <path>)` only after
  the review is closed and all in-run consumers have finished.
- `$quest` carries `<path>` and the forge ledger as durable phase-seam state. It writes the compact
  review summary fragment and invokes Task 1 after `$deliver` creates the PR.

### Steps

1. Update `skills/forge/SKILL.md` final-review resume table and steps 6 onward:

   - closed without retained/disposed resumes at retention marking, not deletion;
   - append the retained-for-publication ledger line and keep the file;
   - a retained line makes forge complete and exposes the review/ledger paths to its caller;
   - retain failed/malformed review behavior as terminal; do not create an unavailable artifact;
   - remove the old build-phase trash instruction and explain that quest publication owns disposal.

2. Update `skills/quest/SKILL.md` phase seams and Ship It step:

   - record forge review path, forge ledger, branch, `BASE_BRANCH`, and guardrails after build;
   - distinguish verified `not required` mode from a required-review failure;
   - after `$deliver` creates the PR, write the compact summary fragment to a temp file and invoke:

     ```sh
     skills/quest/scripts/publish-forge-review \
       "$REPO" "$PR" "$FORGE_MODE" "$FORGE_REVIEW_OR_REASON" \
       "$FORGE_LEDGER" "$REVIEW_SUMMARY"
     ```

   - treat nonzero as a quest blocker with artifacts retained; never post a second `WORK:REVIEW`
     independently;
   - record the helper's verified comment URL in the ship-to-handoff seam;
   - keep the security-review summary fields and existing `WORK:REVIEW` timing.

3. Update `skills/quest-log/SKILL.md`'s annotation table and `WORK:REVIEW` description to state that
   issue-backed quest comments contain the compact summary followed by an indented forge-review
   payload and publication token. Existing latest-complete readers continue selecting the outer
   block; embedded markers are indented and are not structure.

4. Run focused and structural checks. The helper fixture already covers all mode arms; Anatomy rule
   4 leaves the skill prose itself to adversarial review rather than sentence-pinning tests.

   ```sh
   ./tests/fixtures/quest/publish-forge-review-test.sh
   just shape-check
   just public-safety
   just records
   ```

   Expected: all exit 0; the public-safety and shape gates emit no findings; records regression
   cases pass.

5. Commit explicit paths:

   ```sh
   git add skills/forge/SKILL.md skills/quest/SKILL.md skills/quest-log/SKILL.md \
     tests/fixtures/quest/publish-forge-review-test.sh
   git commit -m "feat: carry forge reviews through quest shipping"
   ```

### Acceptance criteria

- Forge retains a successful required review and reports its durable handoff paths.
- Quest cannot ship after a failed required review.
- The PR receives one verified `WORK:REVIEW` whose summary remains distinct from the full forge
  review.
- Return-to-town sees a closed scratch lifecycle and requires no change.

## Final verification

1. Run the focused fixture and its mutation proof again.
2. Run `just verify` bare. Expected: every gate and fixture suite passes with no warnings other than
   the repository-documented Claude manifest version warning.
3. Read `git diff main...HEAD` for naming, function length, complexity, private paths, and
   unnecessary surface. Enforce the ≤100-line and complexity ≤8 limits.
4. Confirm `git status --short --untracked-files=all` is clean before branch review.

## Rollback

Before publication, reverting the implementation commits restores the old ephemeral behavior and
leaves any ignored retained artifacts for operator inspection. After a verified PR comment exists,
reverting does not delete public history; the comment remains the durable review, and no migration
or external cleanup is required.
