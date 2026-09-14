---
name: deliver
description: "Push a feature branch, create or update a pull request, and drive it to green CI and a mergeable GitHub state. Use when asked to ship, publish, or prepare completed work for merge, including as the shipping phase of an issue flow."
---
# Ship It: PR Creation and Hand-Back

Push the branch and drive the PR to **green CI and mergeable state**. Both are
required — CI can be green while the PR is behind, dirty, blocked, or
conflicting against its base.

If you are running as part of `$quest`, `BASE_BRANCH` and guardrail
commands are already recorded from `$attunement`. If running standalone,
discover them first.

**Caller contract.** If invoked inside `$quest`, completing this step
(green CI + mergeable) means proceed to the next step — do not end your turn.
Stop only on a genuine blocker you have named.

## 1. Final local verification

Identify the final candidate after implementation, review fixes, and
simplification. Use the command and hook coverage recorded by `$attunement`.
The final candidate needs one full local suite result, including checks outside
the edited paths. If a mandatory pre-push hook runs that suite on the exact
branch object being pushed and blocks failure, let the hook own this gate: do
not run an equivalent full suite manually before pushing. Otherwise reuse a
prior successful full result only when [true-seeing](../../references/true-seeing.md)
establishes that its tested inputs, scope, environment, and integration base
still apply; run the full suite before pushing when no applicable result exists.
Focused assembled-branch checks cannot stand in for full coverage. A repository
rule requiring an additional full run still applies; name the rule and both runs.

Fold any fixup commits into the logical commits they belong to before pushing.
Once a branch is pushed to a shared remote, the harness blocks force-push and
interactive rebase, so a messy history can no longer be cleaned up. Keep
commits small and logically scoped (do not collapse them) so a later `git bisect`
can pin a regression to a minimal change.

## 2. Create the PR

**If HEAD is detached there is no branch to push.** An externally managed
workspace can hand you one — `$forge` detects the case and leaves it here,
because this is the first step that needs a branch name. Create one at the
current commit (`git switch -c <name>`) before pushing; derive the name from the
work and say what you chose.

Push the branch. The hook's successful exit counts only for the object it
actually checked. Confirm the pushed branch object's full SHA matches the
checked candidate before recording a full pass. A skipped, failed, cancelled,
or inconclusive hook has no passing result. Diagnose a failed hook before
another push. If HEAD, relevant inputs, the integration base, or the execution
environment change, reassess the assembled-branch and final evidence before
claiming coverage. A new phase alone never invalidates an applicable result or
requires another full run.

Open a PR against `BASE_BRANCH` with `gh pr create`. Its body describes only
what is in the diff, in plain factual language. Avoid inflated words such as
"critical", "crucial", "essential", "significant",
"comprehensive", "robust", or "elegant". End with `Closes #<issue-number>` only if
an issue number was supplied; omit the trailer for standalone use with no
linked issue.
At hand-back, report the actual number of full local runs, including failed
attempts, why each ran, and their observed total duration from the verification
record. Keep unknown durations unknown; do not benchmark solely to fill the
report. Report CI
separately.

## 3. Drive to green + mergeable

This is `$deliver`'s hand-back condition, not authorization to merge. An
issue-backed merge must separately pass ADR 0035's commit-bound four-part gate,
including its author handshake.

Long commands run in the foreground with a raised timeout, and a worker never ends a turn waiting on a completion notification.

Poll in a loop — **do not stream**. `gh pr checks <PR> --watch` pipes every
incremental status frame into context for the entire CI run; the intermediate
frames carry no decision value, only the terminal states do.

1. Poll checks with a **bounded, compact** snapshot: `sleep <interval> &&
   gh pr checks <PR> --json name,state || true`, starting at a short interval and
   backing off (e.g. 30s → 60s), reading one small JSON snapshot per poll. Note
   `gh pr checks` exits non-zero (code 8) **while checks are still pending** and on
   failure — decide pass/pending/fail from the parsed `state` fields, not the
   process exit code (hence `|| true`, so a pending run isn't misread as a command
   failure). No streaming output enters context. Skipped integration jobs that
   require unavailable hardware or external services may be expected; wait on
   required checks.
2. If a required check fails, establish its cause before fixing it. Direct correction is allowed
   only when the current failure artifact or an already-recorded investigation identifies a
   specific cause and the correction follows from that evidence. Familiarity, a plausible fix, or
   stale evidence from another failure is not enough. Without current causal evidence, run
   `$detect-curse`, then apply only the evidence-backed correction, run relevant local guardrails,
   push, and restart the loop. If the same artifact recurs after the same correction with no new
   evidence, stop instead of repeating the diagnose-fix cycle. **Never re-run a failed check hoping
   for green** — see [true-seeing](../../references/true-seeing.md), *Flaky tests*.

   That rule bites only where the check is actually nondeterministic: the same
   check passed on an earlier run of this same commit, or passes again with
   nothing pushed between. Then read the log. A runner, network, registry, or
   cache error that fired before the tests ran is infrastructure — re-run once
   and name the external cause in the PR body, because a re-run whose cause you
   can name is diagnosis, and "it was probably infra" is not. A failure the
   repo's own test raised is a determinism defect: fix it, or file it and stop.
   Filing does not turn the check green, so there is no exit condition left to
   reach — report the PR state and the issue reference to the operator, the
   same shape as step 8. Note either outcome in the PR body: a PR that went
   green on a retry looks afterwards exactly like one that went green first
   time, and only you can still tell them apart.
3. Poll merge state with `gh pr view <PR> --json mergeable,mergeStateStatus`
   (always request explicit `--json` fields — never a bare `gh pr view`, which
   dumps the full body and comments). Green checks alone are never the exit
   condition — checks run on the branch head, not the merge result.
4. Hand back only when required checks are green and `mergeStateStatus` is
   `CLEAN` with `mergeable` equal to `MERGEABLE`. This does not authorize a
   merge; ADR 0035's commit-bound gate governs that decision.
5. If merge state is `BEHIND`, merge the latest `BASE_BRANCH` into the PR
   branch (a pushed branch cannot be rebased — force-push is denied; rebase is
   an option only before first push). After resolving, **regenerate any
   generated docs or snapshots** the base may have moved (a recurring
   cross-PR conflict zone), reassess assembled-branch coverage, run affected
   checks, and establish final full evidence as in step 1 before pushing and
   restarting the loop.
6. If merge state is `DIRTY` or `CONFLICTING`, resolve conflicts, regenerate
   generated artifacts, reassess assembled-branch coverage, run affected
   checks, and establish final full evidence as in step 1 before pushing and
   restarting the loop. If one
   conflict-resolution pass does not clear it, stop and report the blocker
   instead of spinning.
7. If merge state is `UNKNOWN`, retry a small number of times with short
   waits. If it stays unknown, stop and report the current PR state.
8. If merge state is `BLOCKED`, `HAS_HOOKS`, or requires human
   review/approval, stop and report exactly what external action is needed.

**Track state (quest-log skill).** Once the exit condition holds (required checks
green and `mergeStateStatus` `CLEAN`/`MERGEABLE`) **and** an issue number was supplied,
ensure-create the labels, then set the issue to `status:awaiting-merge` (single-active
swap). Do **not** post `WORK:REVIEW` — standalone `$deliver` has no review data; when run
inside `$quest`, `$quest` owns that write.

Do not sit in a watch loop on an unmergeable PR — when in doubt after one
resolution attempt, surface it to the operator rather than spinning.
