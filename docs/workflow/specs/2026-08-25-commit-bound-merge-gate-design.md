# A commit-bound merge gate — design (issue #235)

Spec for the four-part pre-merge gate and the SHA-bound merge-ready handshake that
`$campaign`, `$quest`, and `$return-to-town` will state. Decision record:
[ADR 0035](../../adr/0035-the-merge-gate-binds-to-a-commit.md). Charter: `WORK:SCOPE`
token `q235-ee19d60c` on issue #235, interaction unattended.

> **Status: designed, not implemented.** An operator rescope on 2026-08-25 landed ADR 0035
> and these documents on their own, leaving the three `SKILL.md` files untouched. **Issue
> #249** carries the implementation and this spec and its plan are what it builds from.
> Nothing described below is in force in any shipped skill yet.

## Problem

The documented merge precondition is "CI checks green + `mergeStateStatus`
`CLEAN`/`MERGEABLE`". It is a property of what GitHub reports about a pull request now,
not of a commit. Issue #235 reports three ways it passed over reviewed work. The reported
incidents are in `randomparity/hmc-mcp`, which is not reachable from this repository:
they are evidence about shapes, **not verified facts**, and nothing below rests on them.

The shapes are checkable here:

1. In `$quest` the pull request opens inside step 8 (`skills/quest/SKILL.md:585`, `:594`)
   and the author is not finished until step 9's hand-off (`:721`), after head verification
   (`:602`–`:607`) and review-summary publication (`:610`–`:662`). The review loop is
   step 6 and has ended by then, so the window is narrower than issue #235 describes but
   real: `skills/return-to-town/SKILL.md:202`–`203` says hand-off "comes some way *after*
   its pull request first reads green + mergeable", and nothing on GitHub distinguishes
   the two states.
2. `gh pr view --json headRefOid` reads the pull-request API. `git ls-remote origin
   refs/heads/<branch>` reads the ref. When they disagree, checks queried through the
   pull request are green *for the older commit*.
3. CI ran the branch head against whatever the base was then. `mergeStateStatus` reports
   `BEHIND` only where the base requires up-to-date branches; `main` in this repository
   requires nothing — `gh api repos/randomparity/adept/branches/main/protection` → HTTP 404
   `Branch not protected`, and `gh api repos/randomparity/adept/rulesets` and `gh api
   repos/randomparity/adept/rules/branches/main` → `[]` at exit 0 (all 2026-08-25), the
   ruleset probes being necessary because the protection endpoint is silent about rulesets
   (ADR 0024). So the field cannot report a moved base here at all.

## Decisions (each traced to its charter criterion)

1. **One gate, four parts, stated in identical words in `skills/campaign/SKILL.md`,
   `skills/quest/SKILL.md`, and `skills/return-to-town/SKILL.md`**, with every `gh` and
   `git` invocation spelled out. Its subject is `HEAD_SHA`, a commit. *(criterion 1)*
2. **`$campaign` is forbidden to merge a pull request for which it holds no
   `MERGE-READY: #<PR> @ <HEAD_SHA>` line, however green GitHub reports it.** The
   `gh pr view <PR> --json headRefName` path stays permitted for recording a branch and
   is forbidden as a merge trigger. *(criterion 2)*
3. **Checks bind to the commit** via `gh run list --commit "$HEAD_SHA"`, and the gate
   states that `gh pr checks` and `statusCheckRollup` inherit pull-request-API staleness.
   *(criterion 3)*
4. **The gate states that `headRefOid` can lag `git ls-remote`**, and takes `git
   ls-remote` as authoritative. *(criterion 4)*
5. **ADR 0035 records the decision**, its consequences, and its rejected alternatives
   with ADR 0019 evidence tags; the `randomparity/hmc-mcp` incidents are marked
   reported-not-verified wherever they appear. *(criterion 5)*
6. **`--match-head-commit` is generalized to every `$return-to-town` merge path**, not
   only restock PR-only mode, so the head is bound at the server rather than compared
   before the merge. Which SHA it binds differs by mode: an issue-backed merge binds the
   gate's `HEAD_SHA`, restock PR-only mode keeps binding the caller's
   `$EXPECTED_HEAD_SHA`. *(necessary consequence of decision 1: parts 1–3 are read-then-act
   and leave a window the flag closes)*
6a. **The gate as a whole governs issue-backed merges only.** Restock PR-only mode has no
   issue for part 4 and no `$quest` run authored its branch, and re-reading its head at
   merge time would invert the guard behind `MERGE_REFUSED` (ADR 0012 routes each
   authorized dependency merge through `$return-to-town`;
   `skills/restock/SKILL.md:758`–`762`). *(necessary consequence of decision 1)*
7. **The handshake is written into the hand-off `WORK:TRAJECTORY` comment** that
   `$return-to-town`'s default path already posts, and the completion report quotes it.
   *(necessary consequence of criterion 2: a handshake the orchestrator cannot read is
   not a gate it can be forbidden to bypass)*
8. **No new gate, script, or test asserts on this prose.** *(criterion 7)*
9. **`skills/deliver/SKILL.md` and `skills/quest-log/SKILL.md` are not edited**;
   their divergence is reported as a follow-up. *(criterion 8)*

## The gate

Verbatim shape the three skills share. `<owner/name>`, `<PR>`, `<branch>`, and
`<BASE_BRANCH>` are the caller's; `$MERGE_FLAG` is the repository's required merge method.

```sh
git fetch origin
HEAD_SHA=$(git ls-remote origin "refs/heads/<branch>" | cut -f1)
API_SHA=$(gh pr view <PR> --repo <owner/name> --json headRefOid --jq .headRefOid)
```

1. **SHA parity** — `HEAD_SHA` non-empty and equal to `API_SHA`. An empty `HEAD_SHA` is
   the branch being gone, not a match and not a lag: `git ls-remote` prints nothing and
   exits 0 for a ref that does not exist, so it takes the blocker path immediately rather
   than entering the re-read. Because `HEAD_SHA` comes from `origin`, the gate covers
   same-repository heads: `gh pr view <PR> --json isCrossRepository` identifies a fork head
   ahead of part 1 and gives it its own blocker. A mismatch between two real values has
   two causes — a lagging
   API (`ls-remote` steady, `headRefOid` catching up) or a live author (`ls-remote` moving)
   — and re-reading tells them apart. Re-read on a backing-off interval and bound it: after
   a few reads that do not converge, hold. Never merge through either.
2. **Checks green for that commit** —

   ```sh
   gh run list --repo <owner/name> --commit "$HEAD_SHA" \
     --json workflowName,event,status,conclusion \
     --jq '.[] | select(.status != "completed" or .conclusion != "success")'
   ```

   Empty output *and* a non-empty run list is green — every run `completed`/`success`, over
   *all* Actions runs for the commit rather than the required set, since required-ness is
   not SHA-addressable. `[]` means no run exists for that commit — CI has not reported,
   which is not the same as nothing having failed, and which splits further: a run not yet
   started resolves (bound the wait, then hold), a repository with no workflows never does.
   Establish the second (`gh api repos/<owner/name>/actions/workflows` empty beside an
   empty `check-runs`) and record part 2 *not applicable* for this run, or the gate
   deadlocks there. `gh
   run list` sees GitHub Actions runs only; where a required check is not an Actions run,
   read `gh api repos/<owner/name>/commits/"$HEAD_SHA"/check-runs` as well, which is
   SHA-addressed the same way.
3. **Merge base current** — `git merge-base --is-ancestor "origin/<BASE_BRANCH>"
   "$HEAD_SHA"`. Exit 0 passes; exit 1 means the base moved, so merge `BASE_BRANCH` in,
   regenerate artifacts, rerun guardrails, and re-run this gate from part 1 against the
   new head. Any other exit is a fault, not a verdict. Run it immediately before the
   merge: nothing binds the base at merge time, so the interval is the exposure.
4. **Author handshake** — a `MERGE-READY: #<PR> @ <sha>` line whose `<sha>` equals
   `HEAD_SHA`, a whole line inside the latest **complete** `WORK:TRAJECTORY` block on the
   issue, read through the quest-log skill's own recipe (both whole-line markers, then
   `last`) so a hand-off whose write died midway counts as absent. The block's
   `author.login` must be the pull request's own author (`gh pr view <PR> --json author`)
   or an account with write permission — pinned outside the comment channel, since anyone
   who can post the handshake can post a hand-off block naming themselves its author. The
   one other permitted author is the merging run's own `gh api user --jq .login` for a head
   it created by refreshing a stale base, which makes part 4 self-attestation there; that
   attestation is derivative only, permitted for a head refreshed from one that already
   carried an author handshake, never for a row that never had one.

Then, and only then:

```sh
gh pr merge <PR> --repo <owner/name> "$MERGE_FLAG" --match-head-commit "$HEAD_SHA"
```

A non-zero exit from any command above is a fault that holds the merge, never an answer.

## Normative guarantees

- **G1** No `gh pr merge` runs without all four parts holding for one `HEAD_SHA`, and
  every `gh pr merge` passes that same `HEAD_SHA` to `--match-head-commit`.
  (decisions 1, 6) The flag binds the head only; part 3's window is narrowed by running
  it immediately before the merge and is not closed — an accepted residual, recorded in
  ADR 0035's Consequences.
- **G2** A refused `--match-head-commit` merge is never retried without re-running the
  gate from part 1: the refusal means the branch moved, so parts 1–4 are stale.
  (necessary consequence of G1)
- **G3** `$quest`'s terminal state is the `MERGE-READY:` line. "PR is green" is not
  terminal and is not a merge trigger for any caller. (criterion 2, decision 7)
- **G3a** A merging run may attest for a head only when that head descends from one that
  already carried an author handshake. No row acquires a handshake by being refreshed.
  (necessary consequence of criterion 2)
- **G4** The handshake names a full 40-character SHA — the one `git ls-remote` returned —
  never an abbreviation and never `headRefOid`. (decision 4)
- **G5** An empty `git ls-remote` result and an empty `gh run list` result are faults, not
  passes. (decision 1)
- **G6** Nothing added by this change greps Markdown for a sentence. (decision 8)

## Components

| File | Responsibility |
|---|---|
| `skills/return-to-town/SKILL.md` | the gate before its merge; `--match-head-commit` on every merge path; the `MERGE-READY:` line in the hand-off `WORK:TRAJECTORY` |
| `skills/campaign/SKILL.md` | the gate in step 6; the handshake prohibition; `headRefName` permitted for recording, forbidden as a merge trigger |
| `skills/quest/SKILL.md` | the gate at step 9; the terminal `MERGE-READY:` line; "PR is green" is not terminal |
| `docs/adr/0035-the-merge-gate-binds-to-a-commit.md` | the decision record |
| `.claude-plugin/plugin.json` | version 2.9.6 → 2.10.0 (MINOR; skills gain a capability) |

## Error handling

Every read in the gate has a distinguished could-not-answer verdict, per ADR 0005:
an empty `git ls-remote`, an empty `gh run list`, a `git merge-base --is-ancestor` exit
outside {0, 1}, and a failed `gh` call are each reported as a fault and hold the merge.
None of them is collapsed into "not ready" — the caller needs to know whether the gate
said no or could not say.

## Testing

No executable code changes, so no unit test is added. The verification is `just verify`
(structural gates: skill shape, plugin version, public safety, ripgrep config, records)
plus reading. Anatomy rule 4 forbids the alternative: a gate asserting that these three
files contain a given sentence is exactly the class this repository removed.

## Out of scope

- **Proposal D**, amending the global `~/.claude/CLAUDE.md`. That file is not in this
  repository and no pull request here can change it, so issue #235's acceptance criterion
  "the global `CLAUDE.md` procedure no longer contradicts its own warning" cannot be met
  by this change. Owned by the operator.
- `skills/deliver/SKILL.md`, `skills/quest-log/SKILL.md` — follow-up (decision 9).
- Any gate, script, or test change; `scripts/` and `Justfile` are untouched.

## Follow-ups

1. **Issue #242** — consolidate the three copies of the gate into one
   `references/merge-gate.md`.
2. **Issue #243** — reconcile `$deliver`'s exit condition and `$quest-log`'s
   `status:awaiting-merge` description with this gate; `$return-to-town` cites
   `$deliver`'s exit condition by name as its own entry condition.
