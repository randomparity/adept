---
name: ship-pr
description: "Push a feature branch, create or update a pull request, and drive it to green CI and a mergeable GitHub state. Use when asked to ship, publish, or prepare completed work for merge, including as the shipping phase of an issue flow."
---
# Ship It: PR Creation and CI Green + Mergeable

Push the branch and drive the PR to **green CI and mergeable state**. Both are
required — CI can be green while the PR is behind, dirty, blocked, or
conflicting against its base.

If you are running as part of `$work-issue`, `BASE_BRANCH` and guardrail
commands are already recorded from `$preflight`. If running standalone,
discover them first.

**Caller contract.** If invoked inside `$work-issue`, completing this step
(green CI + mergeable) means proceed to the next step — do not end your turn.
Stop only on a genuine blocker you have named.

## 1. Final pre-push check

Before the first push, run the **full** local check suite once (not just the
focused tests for the files you touched) — architecture, boundary, and
doc-generation tests often live outside the directories you edited and only
fail in a full run. Fold any fixup commits into the logical commits they
belong to before pushing, because once a branch is pushed to a shared remote
the harness blocks force-push and interactive rebase, so a messy history can
no longer be cleaned up. Keep commits small and logically scoped (do not
collapse them) so a later `git bisect` can pin a regression to a minimal
change.

## 2. Create the PR

Push the branch and open a PR against `BASE_BRANCH` with `gh pr create`. The
body describes only what is in the diff, in plain factual language. Avoid
inflated words such as "critical", "crucial", "essential", "significant",
"comprehensive", "robust", or "elegant". End with `Closes #<issue-number>` only if
an issue number was supplied; omit the trailer for standalone use with no
linked issue.

## 3. Drive to green + mergeable

Poll in a loop — **do not stream**. `gh pr checks <PR> --watch` pipes every
incremental status frame into context for the entire CI run; the intermediate
frames carry no decision value, only the terminal states do.

1. Poll checks with a **bounded, compact** snapshot: `sleep <interval> &&
   gh pr checks <PR> --json name,state || true`, starting at a short interval and
   backing off (e.g. 30s → 60s), reading one small JSON snapshot per poll. Note
   `gh pr checks` exits non-zero (code 8) **while checks are still pending** and on
   failure — decide pass/pending/fail from the parsed `state` fields, not the
   process exit code (hence `|| true`, so a pending run isn't misread as a command
   failure). Alternatively run the plain `--watch` (its live table, no `--json`) as
   a background task and read only its final output. No streaming output enters
   context. Skipped integration jobs that require unavailable hardware or external
   services may be expected; wait on required checks.
2. If a required check fails, inspect the failure, fix it, run relevant local
   guardrails, push, and restart the loop.
3. Poll merge state with `gh pr view <PR> --json mergeable,mergeStateStatus`
   (always request explicit `--json` fields — never a bare `gh pr view`, which
   dumps the full body and comments). Green checks alone are never the exit
   condition — checks run on the branch head, not the merge result.
4. Exit only when required checks are green and `mergeStateStatus` is
   `CLEAN` with `mergeable` equal to `MERGEABLE`.
5. If merge state is `BEHIND`, merge the latest `BASE_BRANCH` into the PR
   branch (a pushed branch cannot be rebased — force-push is denied; rebase is
   an option only before first push). After resolving, **regenerate any
   generated docs or snapshots** the base may have moved (a recurring
   cross-PR conflict zone), rerun guardrails, push, and restart the loop.
6. If merge state is `DIRTY` or `CONFLICTING`, resolve conflicts, regenerate
   generated artifacts, rerun guardrails, push, and restart the loop. If one
   conflict-resolution pass does not clear it, stop and report the blocker
   instead of spinning.
7. If merge state is `UNKNOWN`, retry a small number of times with short
   waits. If it stays unknown, stop and report the current PR state.
8. If merge state is `BLOCKED`, `HAS_HOOKS`, or requires human
   review/approval, stop and report exactly what external action is needed.

**Track state (github-tracking skill).** Once the exit condition holds (required checks
green and `mergeStateStatus` `CLEAN`/`MERGEABLE`) **and** an issue number was supplied,
ensure-create the labels, then set the issue to `status:awaiting-merge` (single-active
swap). Do **not** post `WORK:REVIEW` — standalone `$ship-pr` has no review data; when run
inside `$work-issue`, `$work-issue` owns that write.

Do not sit in a watch loop on an unmergeable PR — when in doubt after one
resolution attempt, surface it to the operator rather than spinning.
