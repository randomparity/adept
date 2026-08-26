# Commit-bound merge gate — implementation plan (issue #235)

**Goal:** make the pre-merge precondition a property of a specific commit plus an explicit
author handshake, stated identically in `$campaign`, `$quest`, and `$return-to-town`.

**Architecture:** prose contracts in three shipped `SKILL.md` files, governed by ADR 0035;
one version bump. No executable code changes, no new gate, no new script, no new test.

**Tech stack:** Markdown skill documents; `just` guardrails (bash 3.2 floor); `gh` 2.98.0
and `git` for the invocations the prose spells out.

> **Status: not executed.** An operator rescope on 2026-08-25 landed ADR 0035 and this plan
> without running it, so no `SKILL.md` has been touched. **Issue #249** is the work item.
> Two corrections were folded into the gate block below after the plan was first written and
> are the ones an implementer is most likely to drop: part 2's rule for a run that exists but
> has not finished, and part 3's `git fetch origin` being part of the check rather than
> preparation for it. The version constraint below also changes on that pass — see Global
> Constraints.

## Global Constraints

- `BASE_BRANCH`: `main`. Branch `feat/merge-gate-sha-parity-235`, in a worktree outside
  the repository tree at `$WORK/../adept-worktrees/<branch>` per the quest
  worktree-placement rule.
- Guardrails: `just verify` (full), `just commit-check` (per commit). Zero warnings.
- Version bump required on every change (ADR 0022). The ADR-only pass shipped `2.9.12`, a
  PATCH — an ADR is neither a skill nor a `references/` entry, so nothing gained a
  capability. **The implementation pass (#249) is a MINOR bump**, because the three skills
  do gain one there. Values are assigned by the dispatching campaign when siblings share the
  line; do not recompute one that was handed to you.
- ADR number `0035` is pre-assigned. `0023` and `0027` stay unallocated
  (`docs/adr/README.md`). There is **no ADR index** — write the record file only; a table
  under `docs/adr/` raises `W-INDEX-TABLE`.
- Anatomy rule 4 (`CLAUDE.md`): nothing automated asserts on prose. This change adds no
  gate, no test, and no grep over Markdown.
- This repository is public. No absolute host paths in committed files —
  `scripts/check-public-safety.sh` denies `/Users/…`, `/home/…`, and `/Volumes/…`; write
  `$WORK` for the checkout root.
- Files owned by sibling workers and not to be touched: `Justfile`,
  `scripts/check-skill-shape.sh`, `site/style.css`, `docs/assets/*.png`,
  `.github/dependabot.yml`. Also out of surface: `skills/deliver/SKILL.md`,
  `skills/quest-log/SKILL.md`.
- Style: match the surrounding prose — em-dash house style, `**bold**` lead-ins on
  normative bullets, fenced `sh` blocks, no trailing whitespace.
- Design authority: [ADR 0035](../../adr/0035-the-merge-gate-binds-to-a-commit.md) and
  the spec `docs/workflow/specs/2026-08-25-commit-bound-merge-gate-design.md`.

## The shared gate block

Tasks 1–3 each insert this block **verbatim**. It is repeated in full in every task below
rather than cross-referenced, because tasks are read out of order.

The block begins with its own `### The merge gate` heading line, so all three files receive
identical bytes. That heading level is correct in all three insertion points, each of
which sits under a `##` step heading.

````markdown
### The merge gate

Its subject is a commit, not a pull request. Read the head from the ref itself and hold
every part against that one value:

```sh
git fetch origin
HEAD_SHA=$(git ls-remote origin "refs/heads/<branch>" | cut -f1)
API_SHA=$(gh pr view <PR> --repo <owner/name> --json headRefOid --jq .headRefOid)
```

Every command below either answers or fails. A non-zero exit from any of them — `git
ls-remote`, `gh pr view`, `gh run list`, `git fetch` — is a fault that holds the merge, never
an answer and never "not ready". The one command with three answers is part 3's
`git merge-base --is-ancestor`: exit 0 contained, exit 1 base moved, **any other exit a
fault**.

1. **SHA parity.** `HEAD_SHA` is non-empty and equals `API_SHA`. `gh pr view --json
   headRefOid` reads the pull-request API and **can lag `git ls-remote`**; the ref is
   authoritative. `HEAD_SHA` comes from `origin`, so this gate covers same-repository
   heads: check `gh pr view <PR> --json isCrossRepository` first and give a fork-based
   pull request its own named blocker, or its head — which is not in `origin` at all —
   reads as an empty `ls-remote` and gets diagnosed as a deleted branch. An empty
   `HEAD_SHA` is otherwise not a match and not a lag: `git ls-remote` prints nothing and
   exits 0 for a ref that is not there, so the head branch is gone — take the blocker path
   immediately under that name rather than entering the re-read below. A
   mismatch between two real values has two causes and re-reading tells them apart: an
   `ls-remote` value that holds still while `headRefOid` catches up is the API lagging, and
   an `ls-remote` value that keeps moving is an author still pushing. Neither may be merged
   through. Re-read on a backing-off interval and **bound it** — after a few attempts that
   do not converge, take the hold or blocker path rather than spinning, which an unattended
   run would otherwise do indefinitely against a live branch. This part is a diagnosis and
   pre-empt device, not a safety property: `HEAD_SHA`'s authority is the ref, every other
   part keys on it, and the merge binds it — so a mismatch is held to turn an opaque merge
   refusal into a legible one, at the cost of occasionally parking a correct row.
2. **Checks green for `HEAD_SHA`.**

   ```sh
   gh run list --repo <owner/name> --commit "$HEAD_SHA" \
     --json workflowName,event,status,conclusion \
     --jq '.[] | select(.status != "completed" or .conclusion != "success")'
   ```

   Partition on `conclusion`'s vocabulary, not on `!= success` — the `--jq` above is a
   starting filter, not the rule. **Green** is a non-empty list in which every run is
   `completed` at `success`, `skipped`, or `neutral`; `skipped` is what a path-filtered or
   conditional workflow reports on every commit that misses its paths, so treating it as
   failure deadlocks the gate on a very common configuration. **Not yet** is no run at all
   *or* any run not yet `completed`. **Failed** is `failure` or `timed_out`. **Cancelled,
   `action_required`, `stale`, and `startup_failure` hold under their own names** — none is a
   verdict about the code. The set read is *all* Actions runs for the commit, not the
   required set: required-ness
   belongs to a branch rule and is not SHA-addressable, so this is deliberately stricter
   than the "required checks are green" it replaces and will hold on an optional run the
   old wording ignored. Do not substitute `gh pr checks` or `statusCheckRollup`: both read
   the pull-request API and inherit exactly the staleness part 1 is about, so they can
   report green about a different commit. `gh run list` sees GitHub Actions runs only;
   where a required check is not one, also read `gh api
   repos/<owner/name>/commits/"$HEAD_SHA"/check-runs`, which is SHA-addressed the same way.

   `[]` means no run exists for that commit, and that is two conditions. A run not yet
   started resolves — **bound the wait** and take the hold path under that name if none
   appears, as part 1 does. A repository with no workflows never resolves: establish it
   by a **conjunctive** test — `gh api repos/<owner/name>/actions/workflows` empty **and**
   `check-runs` for `HEAD_SHA` empty — and record part 2 **not applicable** for this run,
   never persisted. Both halves are required; either alone skips part 2 over a repository
   whose checks are live but not Actions. Without that the
   gate deadlocks permanently wherever there are no automated checks.
3. **Merge base current.** `git fetch origin`, then `git merge-base --is-ancestor
   "origin/<BASE_BRANCH>" "$HEAD_SHA"`. The fetch is part of this check, not preparation
   for it: this is a local test against a remote-tracking ref, and against a stale one it
   passes wrongly — the exact failure the part exists to catch — so re-fetch here even
   though the block opened with one. Exit 0 passes — the base tip is already in the head,
   so the merge result is the commit CI ran on. Exit 1 means the base moved under a green check: merge
   `BASE_BRANCH` in, regenerate artifacts, rerun guardrails, and re-run this gate from
   part 1, because the refresh produced a new head. Any other exit is a fault, not a
   verdict. `mergeStateStatus` does not answer this: it reports `BEHIND` only where the
   base branch requires up-to-date branches, and stays `CLEAN` otherwise. Run this part
   **immediately** before the merge — nothing binds the base at merge time, so a sibling
   landing in the interval moves it under a check that already passed, and a short
   interval is the only mitigation there is.
4. **Author handshake.** A `MERGE-READY: #<PR> @ <sha>` line whose `<sha>` equals
   `HEAD_SHA`, occurring as a **whole line** inside the latest complete
   `WORK:TRAJECTORY` block **that carries such a line for `HEAD_SHA`** — not the latest
   complete block simpliciter, because the park protocol writes that block type too and a
   hold posted after a valid hand-off would otherwise revoke it. `$return-to-town`'s hand-off
   is what writes the block, and it computes `HEAD_SHA` from `git ls-remote` at that moment;
   read it there rather than relying on a report reaching you. Use the quest-log skill's
   selection rules, not an ad-hoc `jq` over every comment: a block missing its
   `TRAJECTORY:COMPLETE` sentinel is a write that died midway and counts as absent, and
   `last` is what implements latest-complete-wins.

   ```sh
   gh issue view <n> --repo <owner/name> --json comments \
     --jq '[.comments[] | select(.body | test("(?m)^<!-- WORK:TRAJECTORY -->$")
            and test("(?m)^<!-- TRAJECTORY:COMPLETE -->$"))]
           | last | {author: .author.login, body}'
   ```

   **Pin the expected account outside the comment channel.** On a public repository an
   account that can post a `MERGE-READY:` line can equally post a complete-looking hand-off
   block and name itself the author, so "whoever posted the hand-off" is circular on its
   own. The comment's `author.login` must **also** be the pull request's own author —
   `gh pr view <PR> --repo <owner/name> --json author --jq .author.login` — or hold write
   permission (`gh api repos/<owner/name>/collaborators/<login>/permission`). SHA-binding
   does not help against this: `HEAD_SHA` is the public head of a public pull request.

   The one other permitted author is you, where you created the head yourself by refreshing
   a stale base — your own `gh api user --jq .login`. **That self-attestation is derivative
   and never original:** attest only for a head you produced by refreshing one that already
   carried a valid author handshake. A row that reaches part 3 with no handshake for its
   current head takes the hold path — never the refresh path followed by attesting to your
   own work, which would let the refresh mint the handshake this part exists to require. A
   green pull request with no handshake is **pending**, not ready, and a handshake naming a
   different commit is no handshake for this one.

**Scope.** This gate governs issue-backed merges. `$return-to-town`'s restock PR-only mode
is outside it: a dependency pull request has no issue for part 4 and no `$quest` run
authored it, and that mode keeps binding its caller-supplied `$EXPECTED_HEAD_SHA` — the
head restock evaluated — rather than a merge-time read, because refusing a head that moved
after evaluation is the behaviour its `MERGE_REFUSED` outcome depends on.

Only with all four holding for one `HEAD_SHA`, merge — binding that commit at the server,
which is the only place the head can be bound:

```sh
gh pr merge <PR> --repo <owner/name> "$MERGE_FLAG" --match-head-commit "$HEAD_SHA"
```

A refused `--match-head-commit` merge means the branch moved. Re-run the gate from part 1;
never retry the merge on the stale reads.
````

## Files

| File | Responsibility |
|---|---|
| `skills/return-to-town/SKILL.md` | the gate before its merge; `--match-head-commit` on every merge path; the `MERGE-READY:` line in the hand-off `WORK:TRAJECTORY` |
| `skills/campaign/SKILL.md` | the gate in step 6; the handshake prohibition; `headRefName` for recording only |
| `skills/quest/SKILL.md` | the gate at step 9; the terminal `MERGE-READY:` line |
| `docs/adr/0035-the-merge-gate-binds-to-a-commit.md` | committed in the design commit |
| `docs/workflow/specs/2026-08-25-commit-bound-merge-gate-design.md` | committed in the design commit |
| `.claude-plugin/plugin.json` | `2.9.6` → `2.9.12` on the ADR-only pass; a MINOR bump on #249 |

## Task 1 — `$return-to-town` states the gate and binds every merge

**File:** `skills/return-to-town/SKILL.md`

**Interfaces.** Consumes nothing from earlier tasks. Later tasks rely on: the section
heading `### The merge gate` existing in this file; the exact gate block text (Tasks 2 and
3 insert the same bytes); and the `MERGE-READY: #<PR> @ <sha>` line format written by the
hand-off path in this file.

**Where it fits.** This is where the merge actually happens, for both the
operator-authorized path and `$campaign`'s delegated merge, so the gate is normative here
and the other two skills state it because their callers reach a merge through them.

**Step 1.1 — insert the gate under *Exception: operator-authorized merge*.** After the
sentence "When you do merge:" and before the existing bullet list, insert the shared gate
block from *The shared gate block* above, verbatim, followed by a blank line. `<branch>`
is the pull request's head branch, `<PR>` its number, `<BASE_BRANCH>` the repository
default branch, `$MERGE_FLAG` the repository's required merge method.

**Step 1.2 — generalize `--match-head-commit`.** The bullet reading

```markdown
- In restock PR-only mode, pass the actual expected head to GitHub's atomic guard:

  ```sh
  gh pr merge <N> "$MERGE_FLAG" --match-head-commit "$EXPECTED_HEAD_SHA"
  ```

  Never pass the synthetic local-integration commit as the pull-request head.
```

becomes

```markdown
- **Every merge passes `--match-head-commit`**, not only restock PR-only mode — the gate
  above ends in that invocation and there is no merge path here that skips it. What
  differs by mode is the SHA it binds: an issue-backed merge binds the gate's `HEAD_SHA`,
  and restock PR-only mode binds the caller's `$EXPECTED_HEAD_SHA` — the head restock
  evaluated, already validated at entry, and deliberately *not* re-read here, since
  refusing a head that moved after evaluation is what its `MERGE_REFUSED` outcome
  depends on. Never pass the synthetic local-integration commit as the pull-request head.
```

**Step 1.3 — put the handshake in the hand-off.** Under *Default: hand off, do not
self-merge*, the sentence beginning "First record the hand-off (quest-log skill): post a
`WORK:TRAJECTORY` comment on the issue with `outcome: handed off — PR #N green+mergeable,
awaiting human merge`" gains a following paragraph:

```markdown
**That comment carries the handshake.** Add a whole line reading `MERGE-READY: #<N> @
<HEAD_SHA>`, where `HEAD_SHA` is the full 40-character SHA from `git ls-remote origin
"refs/heads/<branch>" | cut -f1` — never `headRefOid`, never an abbreviation. This is the
merge gate's part 4, and the tracker is where it lives so that a later session, or an
orchestrator whose worker report went missing, can read it with one `gh` query. Write it
only once the work is finished; "the pull request is green" is not that moment.
```

**Step 1.4 — correct the entry condition's citation.** The sentence "For an open pull
request, retain `$deliver`'s exit condition: required checks are green and the pull
request is mergeable." gains a following sentence:

```markdown
  That is `$deliver`'s hand-back condition and it is not the merge gate: it reads
  pull-request state, and the gate below reads a commit. Satisfying it means the pull
  request is worth gating, not that it may be merged.
```

**Step 1.5 — amend the serial-merge bullet.** In the bullet beginning "When several
sibling PRs are in flight, **merge serially**", the final sentence "Never merge an
unmergeable PR on the strength of previously-green checks." gains:

```markdown
 Re-run the whole merge gate against each sibling's new head after every merge —
    the refresh rewrites the head, so the previous `HEAD_SHA`, its checks, and its
    handshake are all about a commit that is no longer the tip.
```

**Verification.** `just shape-check` — expect exit 0.
`rg --no-config -c 'match-head-commit' skills/return-to-town/SKILL.md` — expect `3`: the
gate block's `gh pr merge` line, its "A refused `--match-head-commit` merge" sentence, and
the generalized bullet in step 1.2.

**Acceptance criteria.** The file contains the gate block verbatim; no merge path in it
reaches `gh pr merge` without `--match-head-commit`; the hand-off writes
`MERGE-READY: #<N> @ <HEAD_SHA>`; `just verify` is green.

## Task 2 — `$campaign` step 6 states the gate and forbids merging without a handshake

**File:** `skills/campaign/SKILL.md`

**Interfaces.** Consumes the gate block text and the `MERGE-READY: #<PR> @ <sha>` format
established in Task 1. Provides nothing later tasks consume.

**Where it fits.** `$campaign` step 6 is the merge trigger the incident fired through. It
delegates the merge to `$return-to-town`, so it must hold the gate before delegating.

**Step 2.1 — insert the gate into step 6.** Immediately before the paragraph beginning
"As each issue reaches green + mergeable, run `$return-to-town` (you are authorized)",
insert the shared gate block from *The shared gate block* above, verbatim, followed by a
blank line.

**Step 2.2 — replace the merge trigger.** The paragraph beginning "As each issue reaches
green + mergeable, run `$return-to-town` (you are authorized)." has that first sentence
replaced by:

```markdown
As each issue's pull request passes the four-part merge gate above — all four parts, for
one `HEAD_SHA` — run `$return-to-town` (you are authorized), which re-runs the gate and
performs the guarded merge. **Green + mergeable is not that trigger.**
```

The rest of that paragraph is unchanged.

**Step 2.3 — add the handshake prohibition.** Immediately after the paragraph edited in
step 2.2, insert:

```markdown
**Never merge a pull request for which you hold no merge-ready handshake, however green
GitHub reports it.** A worker opens its pull request at `$quest` step 8 and keeps working
through step 6's review loop, so green + mergeable is reached mid-review and nothing on
GitHub distinguishes "the author is finished" from "the author is on review round 1 of 3".
Part 4 of the gate is the only thing that does. A green pull request with no handshake is
**pending** — leave the row in flight and keep draining the queue. Do not spend the
step-5 probe budget asking for it: the line is on the issue, written by the hand-off, and
`gh issue view <n> --json comments` reads it without an orchestrator turn.
```

**Step 2.4 — forbid `headRefName` as a merge trigger.** In step 5, the sentence "When
issue goes **in-flight**, flip status and **read back the actual branch name** from the
worker report or `gh pr view --json headRefName`." gains a following sentence:

```markdown
That second path records a branch and **never triggers a merge**: it reports that a pull
request exists, which is exactly the state the gate's part 4 exists to distinguish from a
finished one.
```

**Verification.** `just shape-check` — expect exit 0. `rg --no-config -c 'MERGE-READY'
skills/campaign/SKILL.md` — expect `1`, the gate block's part 4; step 2.3's paragraph says
"merge-ready handshake" in prose and does not repeat the token.

**Acceptance criteria.** Step 6 contains the gate block verbatim; the merge trigger is the
gate rather than green + mergeable; the handshake prohibition is present and explicit;
step 5's `headRefName` path is marked recording-only; `just verify` is green.

## Task 3 — `$quest` states the gate and makes `MERGE-READY:` its terminal state

**File:** `skills/quest/SKILL.md`

**Interfaces.** Consumes the gate block text and the `MERGE-READY: #<PR> @ <sha>` format
established in Task 1. Provides nothing later tasks consume.

**Where it fits.** `$quest` never merges, and its statement of the gate is what makes its
handshake trustworthy: part 1 is how it learns the SHA it names, and parts 2 and 3 are
what it must have observed before claiming the branch is finished.

**Step 3.1 — insert the gate into step 9.** In `## 9. Hand Off, or Merge if Authorized`,
immediately after the paragraph ending "the reclaim is theirs.", insert the shared gate
block from *The shared gate block* above, verbatim, followed by a blank line.

**Step 3.2 — state the terminal condition.** Immediately after the inserted gate block,
add:

```markdown
**Your terminal state is `MERGE-READY: #<PR> @ <HEAD_SHA>`, not "the PR is green".** You
do not merge, so parts 1–3 are what you observe and part 4 is what you write:
`$return-to-town`'s hand-off puts that line in its `WORK:TRAJECTORY` comment on the issue,
and your completion report quotes it. Emit it only after the review loop has terminated —
an `approve`, or any of the three named non-blocking exits, or an approved continuation
from a budget stop. A pull request that is green while step 6 is still running is not
ready and must not be reported as though it were. If the run parks instead, there is no
handshake to write: say so plainly rather than reporting green.
```

**Verification.** `just shape-check` — expect exit 0. `rg --no-config -c 'MERGE-READY'
skills/quest/SKILL.md` — expect `2`: the gate block's part 4 and step 3.2's terminal-state
paragraph.

**Acceptance criteria.** Step 9 contains the gate block verbatim; the terminal state is
the `MERGE-READY:` line; the emission condition names the review-loop terminations;
`just verify` is green.

## Task 4 — verify the three copies are byte-identical

**Files:** none changed; this task is verification only.

**Interfaces.** Consumes the gate block inserted by Tasks 1–3.

**Step 4.1.** Extract the gate block from each file into a scratch directory and compare.
`$SCRATCH` is any directory outside the repository tree; the block runs from its
`### The merge gate` heading through the sentence that closes it.

```sh
SCRATCH=$(mktemp -d)
for f in skills/return-to-town/SKILL.md skills/campaign/SKILL.md skills/quest/SKILL.md; do
  awk '/^### The merge gate$/,/^never retry the merge on the stale reads\.$/' "$f" \
    >"$SCRATCH/$(basename "$(dirname "$f")").txt"
done
diff "$SCRATCH/return-to-town.txt" "$SCRATCH/campaign.txt"
diff "$SCRATCH/return-to-town.txt" "$SCRATCH/quest.txt"
wc -l "$SCRATCH"/*.txt
```

Expect no output and exit 0 from both `diff` invocations, and three equal non-zero line
counts from `wc` — an `awk` range that matched nothing produces two empty files that also
`diff` clean, so the counts are what separates "identical" from "absent".

**Step 4.2.** Remove the scratch directory: `rm -rf "$SCRATCH"`.

**Acceptance criteria.** Both diffs are empty. This is a one-off check run by hand, not a
gate: anatomy rule 4 forbids committing it, and nothing in the repository asserts it.

## Task 5 — full guardrail run

**Files:** none changed.

**Step 5.1.** From the worktree root, run `just verify` bare — no pipe, no `|| true`.
Expect exit 0. On a workstation the version gate checks only its first two rules and says
so; `BASE_SHA` is CI's to supply.

**Step 5.2.** Confirm `.claude-plugin/plugin.json` reads the version assigned for the pass
you are on — `2.9.12` shipped with the ADR — and that no
file under `docs/adr/` other than `0035-the-merge-gate-binds-to-a-commit.md` was added or
changed: `git diff --name-only main...HEAD -- docs/adr/`.

**Acceptance criteria.** `just verify` exits 0 with no warnings.

## Rollback

Every change is additive prose in three Markdown files plus one version-string edit.
`git revert` of the branch's commits restores the previous gate wording exactly; nothing
is generated, migrated, or persisted outside the repository.
