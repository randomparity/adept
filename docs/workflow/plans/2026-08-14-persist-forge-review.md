# Persist the forge whole-branch review

## Goal

Retain `$forge`'s whole-branch review until `$quest` publishes and verifies it in the pull request's
`WORK:REVIEW` annotation, then dispose of the ignored artifacts safely.

The implementation adds one narrow Bash helper for body composition, exact GitHub readback, and
cleanup ordering. Forge owns production/retention; quest owns publication after PR creation.
Standalone deliver and return-to-town remain unchanged.

Tech stack: Bash 3.2, GitHub CLI, `jq`, existing public-safety and shell fixture infrastructure.

## Global Constraints

- Bash 3.2, `#!/usr/bin/env bash`, `set -euo pipefail`, ≤100-character source lines, repository
  tab indentation; no associative arrays, `mapfile`, or `readarray`.
- Add no package dependency. Preflight `gh`, `jq`, `mktemp`, `awk`, Git, and the platform's
  recoverable-delete command (`trash` on macOS or `gio trash` on Linux) before publication.
- `.agent/` remains ignored scratch. Never put host paths, rejected content, or auth data in public
  output.
- One active quest controller is supported. Do not retry ambiguous writes, enumerate unrelated PR
  comments, delete comments, or add locking/reconciliation protocols.
- Existing `WORK:REVIEW` summary fields and sentinels remain intact and precede the forge payload.
- A required forge-review failure is terminal; only a verified no-review mode is `not required`.
- Full guardrail is `just verify`; CI runs the same chain through `just ci`.
- Architecture: host `arm64`; targets `none declared`; relationship `no-target-declared`.

## File map

- Create `skills/quest/scripts/publish-forge-review`: one-shot publication/readback/disposal helper.
- Create `tests/fixtures/quest/publish-forge-review-test.sh`: deterministic behavior fixtures.
- Modify `skills/forge/SKILL.md`: retain successful final review and expose handoff paths.
- Modify `skills/quest/SKILL.md`: carry handoff, call helper after PR creation, stop on failure.
- Modify `skills/quest-log/SKILL.md`: document the distinct forge payload inside `WORK:REVIEW`.

## Task 1: Implement and test one-shot review publication

### Interfaces

Command:

```text
skills/quest/scripts/publish-forge-review \
  <repo> <pr> <required|not-required|failed> <review-or-reason> <ledger> <summary-file>
```

Required mode consumes a regular non-empty review. Not-required consumes a public-safe verified
mode reason. Failed mode always exits before GitHub access. The summary file contains compact fields
only, without outer markers. Success prints only the verified comment URL. Failure is nonzero and
public-safe, and retains every artifact not already recoverably disposed.

### Steps

1. Create `tests/fixtures/quest/publish-forge-review-test.sh`. Use a temporary Git repository,
   ignored `.agent/sdd/`, fake `gh` in `PATH`, fake recoverable-delete command, repository fixture
   cleanup helpers, and an exit trap.

2. Add seven failing behavior groups:

   - `PFR-1`: required safe review posts one complete annotation; fake exact-ID readback matches;
     verified ledger line precedes trash calls; source/body disappear only afterward.
   - `PFR-2`: public-safety match or scan fault posts nothing and retains the review/body.
   - `PFR-3`: required publishes; verified not-required publishes summary-only; failed posts
     nothing; missing/empty required review fails.
   - `PFR-4`: comment failure, missing identity, and ambiguous nonzero-after-write stop without a
     retry and retain evidence.
   - `PFR-5`: exact comment read failure/mismatch writes no verified/disposed ledger line.
   - `PFR-6`: ledger append/readback and partial trash failures never claim closed lifecycle and
     report remaining private paths only to the operator stream.
   - `PFR-7`: review lines containing outer markers, sentinel, and summary fields remain indented;
     summary input containing either outer marker is rejected before GitHub access.

3. Run the fixture bare. Expected red result: command not found.

```sh
./tests/fixtures/quest/publish-forge-review-test.sh
```

4. Create `skills/quest/scripts/publish-forge-review` with functions `fail`, `preflight`,
   `validate_inputs`, `compose_body`, `post_comment`, `read_comment`, `append_ledger`, and
   `dispose`. Keep each under 100 lines and complexity ≤8. Implement this exact order:

```text
validate six arguments and mode
preflight every command, including recoverable delete, before GitHub mutation
failed: exit with the supplied public-safe reason before body creation/GitHub
required: require review regular/non-empty/readable; not-required: validate reason
validate summary as UTF-8 text without NUL; reject whole-line outer marker/sentinel
create one body temp beside ledger with mktemp; trap retains it on failure
write outer marker, compact summary, forge heading, four-space-indented review or not-required line,
  and outer sentinel
run repository scripts/check-public-safety.sh against that exact body
post exact body with gh pr comment --body-file; capture returned comment URL or stop without retry
resolve the exact comment API identity from that URL; read its body once and compare exact content
append and read back review-publication-verified with comment identity
recoverably dispose review (required mode) and body; append/read back disposed with former paths
print verified comment URL
```

Use body files for every dynamic GitHub payload. Never interpolate review/summary text into shell
code. Capture and branch on command status explicitly. A failed delete reports what remains and does
not append the disposed line.

5. Fake `gh` implements only `pr comment --body-file` and exact `api <comment-url>` readback. It can
return failure before write, failure after write, missing URL, mismatched body, and exact success.
Fixtures assert status, post count, body bytes, ledger order, trash calls, and retained files.

6. Run focused checks:

```sh
./tests/fixtures/quest/publish-forge-review-test.sh
shellcheck -x skills/quest/scripts/publish-forge-review \
  tests/fixtures/quest/publish-forge-review-test.sh
shfmt -d skills/quest/scripts/publish-forge-review \
  tests/fixtures/quest/publish-forge-review-test.sh
```

Expected: fixture cases pass; ShellCheck/shfmt emit nothing.

7. Mutation proof: temporarily move disposal before verified ledger readback, run the fixture, and
   observe PFR-1 fail. Restore the passing implementation without touching unrelated files.

8. Commit explicit paths:

```sh
git add skills/quest/scripts/publish-forge-review \
  tests/fixtures/quest/publish-forge-review-test.sh
git commit -m "feat: publish forge reviews durably"
```

### Acceptance criteria

- All seven behavior groups pass with Bash 3.2-compatible syntax.
- Exact checked body is the exact posted/read-back body.
- No disposal happens before durable verification.
- Every failure retains usable evidence and never retries a GitHub write.

## Task 2: Wire retention and publication into the workflow

### Interfaces

- Consumes Task 1's six-argument command and verified comment-URL result.
- Forge produces `retained for PR publication` only after review closure and all in-run consumers.
- Quest carries exact review/ledger paths and invokes the helper after deliver creates the PR.

### Steps

1. Update `skills/forge/SKILL.md` final-review resume table and cleanup:

   - closed without retained/disposed resumes at retention marking;
   - append retained-for-publication with review and ledger paths; keep the review;
   - retained marks forge complete and exposes both paths to caller;
   - required review failures remain terminal;
   - remove build-phase trash; quest publication now owns disposal.

2. Update `skills/quest/SKILL.md` seams and Ship It:

   - persist forge mode, review path/reason, ledger, branch, `BASE_BRANCH`, and guardrails after
     build;
   - required failure cannot reach delivery; verified not-required mode remains distinct;
   - after deliver creates PR, write compact summary fields to a temp file and invoke:

     ```sh
     skills/quest/scripts/publish-forge-review \
       "$REPO" "$PR" "$FORGE_MODE" "$FORGE_REVIEW_OR_REASON" \
       "$FORGE_LEDGER" "$REVIEW_SUMMARY"
     ```

   - nonzero parks the quest with evidence retained; never independently post another WORK:REVIEW;
   - carry the verified comment URL into the ship-to-handoff seam.

3. Update `skills/quest-log/SKILL.md`: issue-backed quest `WORK:REVIEW` contains the compact summary
   followed by a labelled, indented forge payload. Whole-line marker matching continues to select
   only the outer annotation.

4. Run focused and structural gates. Anatomy rule 4 leaves skill prose to adversarial review rather
   than sentence-pinning tests.

```sh
./tests/fixtures/quest/publish-forge-review-test.sh
just shape-check
just public-safety
just records
```

Expected: all exit 0.

5. Commit explicit paths:

```sh
git add skills/forge/SKILL.md skills/quest/SKILL.md skills/quest-log/SKILL.md
git commit -m "feat: carry forge reviews through quest shipping"
```

### Acceptance criteria

- Forge retains and reports a successful required review.
- Quest cannot ship after failed required review.
- PR receives one verified WORK:REVIEW with distinct summary and forge payload.
- Return-to-town sees a closed scratch lifecycle without modification.

## Final verification

1. Run focused fixture/mutation proof.
2. Run `just verify` bare; accept only the documented manifest-version warning.
3. Review `git diff main...HEAD` for naming, function length, complexity, private paths, and excess
   surface.
4. Confirm clean status before branch review.

## Rollback

Reverting implementation commits restores ephemeral forge-review behavior and leaves any ignored
retained artifacts for operator inspection. A verified PR comment is public history and remains;
there is no schema, migration, or external cleanup.
