---
name: return-to-town
description: "Hand off a green, mergeable pull request or merge it when explicitly authorized, then clean merged branches and worktrees. Use after shipping a PR or when asked to merge and clean up completed work."
---
# Hand Off or Merge, Then Clean Up

At entry, resolve the pull request and take one status snapshot before choosing the default
hand-off or operator-authorized merge path:

```sh
gh pr view <N> \
  --json state,mergedAt,mergeable,mergeStateStatus,statusCheckRollup \
  --jq '{state, mergedAt, mergeable, mergeState: .mergeStateStatus,
         checks: [.statusCheckRollup[] | {name, status, conclusion}]}'
```

Interpret `state` before `mergeable` or `mergeStateStatus`:

- `MERGED` is conclusive even when either computed field is `UNKNOWN`. Do not poll those
  fields and do not repeat the default hand-off. Proceed directly to **Post-merge
  reconciliation** below.
- `CLOSED` means closed without merge. Stop without post-merge tracking or cleanup and report
  that the pull request was closed unmerged.
- Only `OPEN` continues below. For an open pull request, retain `$deliver`'s exit condition:
  required checks are green and the pull request is mergeable. Recheck computed fields when
  needed only on this route.

A failed snapshot or an unexpected or missing `state` cannot authorize hand-off, merge, or
cleanup. Stop with the read failure or unexpected value.

When the `OPEN` route satisfies `$deliver`'s exit condition, you are at the hand-off point.

## Default: hand off, do not self-merge

First record the hand-off (quest-log skill): post a `WORK:TRAJECTORY` comment on the
issue with `outcome: handed off — PR #N green+mergeable, awaiting human merge`, guardrail
status, and any surprises. **Leave the issue open and `status:awaiting-merge` intact** — do
not close, do not strip. The eventual human UI-merge auto-closes it and `$resurrection`
strips the residual label (closed-state is authoritative).

Only then tell the user the PR is ready to merge and stop. The tracking write is the durable
hand-off record the resume story depends on — it must happen before this terminal stop.

## Exception: operator-authorized merge

If the operator explicitly authorized merging, you may merge it yourself. The
authorization holds in exactly two cases:

- a direct human instruction this session (including a goal you typed asking for
  these issues to be *merged* — distinct from a `$trial-loop` stop goal, which
  never authorizes a merge), or
- you are the **`$campaign` orchestrator itself** and merging is its stated
  completion condition.

Authorization does **not** inherit through delegation. If you are a `$quest`
run that a `$campaign` dispatched — inline or as a subagent — you are **not**
authorized: stop at hand-off (green + mergeable) and let the orchestrator merge.
When you do merge:

- Use the repo's required merge method. Per common convention, **do not squash
  code PRs** — squashing collapses the small logically-scoped commits that
  `git bisect` relies on. Use `--rebase` (linear history) or `--merge` unless
  the repo says otherwise. Squash is acceptable only for pure doc/spec
  review-iteration PRs.
- When several sibling PRs are in flight, **merge serially**: merge one, then
  for each remaining PR re-check `mergeStateStatus`; if it went
  `BEHIND`/`DIRTY`, merge the updated `BASE_BRANCH` into it — never rebase a
  pushed branch: force-push is denied. Regenerate generated artifacts, rerun
  guardrails, and confirm green + mergeable again before merging it. If the
  repo forbids merge commits (linear history) so a base merge-in is
  unacceptable and a pushed-branch rebase is denied, stop with a named
  blocker. Never merge an unmergeable PR on the strength of
  previously-green checks.

**What the completion report covers.** Merging lands the change; it does not
establish what the merge triggered. A workflow that runs on `BASE_BRANCH` — a
publish, a release tag, a deploy — fires *after* the merge, and `$deliver`'s
green CI ran against the pull request head *before* it, so neither covers it.
Nothing here reads that run. Report the merge landing, not everything
downstream of it, and say plainly that the base-branch run the merge triggered
is unverified, so whoever owns it knows to look. Say it even where the
repository looks like it publishes nothing — nothing here establishes that it
does not. See [true-seeing](../../references/true-seeing.md), *Every claim
needs its own command*.

**Caller contract.** If invoked inside `$quest`, completing the cleanup means
the issue is done — the change landed, and what the merge triggered on
`BASE_BRANCH` is not covered. End your turn with a summary. If running
standalone, the same applies: once cleanup is verified, report and stop.

## Track state on the operator-merge path (quest-log skill)

The default hand-off path already posted its `WORK:TRAJECTORY` above. This section covers the
operator-merge path only:

- **Operator-merge path** (you merged, above): if `Closes #N` did not auto-close the issue,
  close it; strip its `status:` labels; post a `WORK:TRAJECTORY` comment on the issue with
  `outcome: merged via PR #N`, guardrail status, and any surprises.

### Post-merge reconciliation

The operator-path issue writes above run only when this invocation performed the merge. On an
entry snapshot that was already `MERGED`, do not repeat them; verify the merged issue's current
closed state, then perform the shared dependent reconciliation below.

#### Release cleared dependents

After verifying the merged issue is closed, run the `quest-log` skill's canonical
recipe in Bash and call `reconcile_cleared_dependencies apply <owner/name>`. This is the primary
owner of the cleared-dependency `status:blocked → status:ready` edge. Report every readied
dependent and every retained dependent with its actionable reason. Do not limit the scan to
the merged issue's prose or comments: the recipe exhaustively evaluates canonical whole-line
`Blocked by #N` records on all open blocked, non-epic issues. A per-dependent failure does
not prevent other dependents from being evaluated.

## After a merge (yours or the user's)

1. `cd` to the main checkout. If you have been working in an external
   worktree you are standing in the directory step 2 removes, and every
   step below is wrong from there: `git switch` refuses a branch checked
   out elsewhere, and `git worktree remove .` succeeds and takes your
   working directory with it.
2. Remove any external worktree **this run created** for this issue. If the
   harness created it with its own tool — `EnterWorktree`, a `/worktree`
   command, a `--worktree` flag — tear it down with that tool's counterpart.
   Reaching past it for `git worktree remove` leaves the harness holding a
   workspace it still believes is live, the teardown half of the phantom state
   `$forge` warns about on the way in. Otherwise `git worktree remove`,
   then `git worktree prune` to clear any registration a previous removal left
   behind — worktree bookkeeping, not the remote-tracking prune below.
3. Switch to `BASE_BRANCH`.
4. Fast-forward pull.
5. Delete the merged local branch.
6. Prune remote-tracking branches.
7. Verify the working tree is clean.

Worktree removal comes before branch deletion because a branch checked
out in a worktree cannot be deleted at all — the reverse order refuses
every time it matters.

**Step 2's scoping is load-bearing, not a formality.** A worktree another agent created
belongs to that agent, and merging its pull request does not prove it has stopped: a
`$quest` worker stops at hand-off, which comes some way *after* its pull request
first reads green + mergeable. Removing that directory while its owner is still inside it
surfaces as `fatal: Unable to read current working directory` out of that agent's next
push.

So leave it alone and record it as deferred cleanup, naming the worktree path and the
branch it holds — reported to your caller, or carried into your own deferred list when you
are the `$campaign` orchestrator running this inline. Either way the orchestrator is what
acts on it: it holds the end-of-run notification the removal waits on, and its step 6 owns
the retry and the gated deletion. Never `git worktree remove --force` your way past this:
the force *is* the failure mode, not the way around it, and it discards whatever the agent
had not committed.

Step 5 needs no such scoping, because git supplies it: a branch checked out in another
worktree cannot be deleted, by `-d` or `-D`. Take *that* refusal — a branch held by a
worktree you did not create — as the same deferral. A refusal on your own branch, after
step 2 removed your own worktree, is a different thing entirely and is yours to resolve.
