---
name: clean-branches
description: "Sweep local branches whose work has landed: classify every local branch, delete the merged and squash-merged ones after one confirmation, remove their worktrees, and report every deletion and skip. Use when asked to clean merged or gone branches or prune stale local branch state."
---
# Clean Merged Branches

Repo-wide hygiene sweep for local branches whose work has landed. `$merge-cleanup` deletes
the one branch it just merged, in flow; this collects what that never sees — PRs merged in
the GitHub UI, by another session, or before this config existed. Read → plan → one
confirmation → apply.

**Success and no-op must be distinguishable in the output.** That is the whole point of this
command: the (since-disabled) `commit-commands` plugin's `/clean_gone` grepped `git branch -v` for `[gone]`, but
`-v` never prints tracking info and git's actual text is `[origin/<branch>: gone]`, so the
loop body never runs. It exits 0, prints nothing, deletes nothing — identical to a clean
repo. Do not use it. Every path below either names what it did or says plainly that nothing
matched.

## Steps

1. **Refresh tracking state.** `git remote get-url origin`, then `git fetch --prune`. Both the
   ancestry test and the `not fully pushed` row are claims about `refs/remotes/origin`, and a
   stale one is worthless. Check the remote explicitly: `git fetch --prune` exits **0** in a
   repo with no remotes and in one whose only remote is named something else, and the sweep
   would then read an empty remote-head set, call every branch `not fully pushed`, and report
   that as a fact. Stop and say so if there is no `origin` or the fetch fails (offline, auth) —
   do not evaluate a single branch against stale or absent state.

   **Then pin `gh` to that same remote.** Every git test below reads `refs/remotes/origin`,
   while `gh` resolves a default repository of its own, and on a fork clone the two are
   different repositories. Confirm `gh repo view --json nameWithOwner` matches `origin`'s URL
   and stop if it does not, or pass `--repo <owner>/<name>` on every `gh` call in this sweep.
   Unpinned, step 2 returns the parent's default branch while ancestry runs against the fork's,
   step 5's protected set describes the parent, and row 7's recovery fetches a parent pull
   request number from the fork.
2. **Resolve the base branch.** `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`;
   without `gh`, `git symbolic-ref --short refs/remotes/origin/HEAD` and strip the `origin/`.
   Every ancestry test below runs against `origin/<base>` — the ref you just fetched, not a
   local base that may be behind. **Stop if the name does not resolve, or if
   `git rev-parse --verify -q origin/<base>` does not** — the `symbolic-ref` fallback exits 128
   whenever `origin/HEAD` was never set, and `gh` answers about the remote, so in a
   single-branch clone it names a ref that was never fetched. The base is the reference for
   every ancestry test as well as row 1's whole test, and without it row 6 fatals on every
   branch and every pushed branch falls through to row 7's API call. Never guess `main`.
3. **Enumerate candidates** — every local branch — with plumbing, not porcelain:

   ```bash
   git for-each-ref --format='%(refname:short)%09%(upstream:short)%09%(upstream:track)' refs/heads
   ```

   Repo-wide on purpose. Filtering here on `%(upstream:track)` equal to `[gone]` found only
   branches whose upstream ref had been deleted, which made the `merged` and
   `squash-merged` rows below unreachable for the leftovers this sweep exists to collect: a
   branch created by `git worktree add <path> -b <branch> origin/<base>` tracks the *base*, so
   its track field reads empty until its first commit and `[ahead N]` after — gaining a
   `behind` component only once the base moves — and pushing it with `-u` moves that to
   `[behind N]` or empty. A repo with
   `deleteBranchOnMerge: false` then keeps the remote head after the merge, so a pruned fetch
   cannot produce `[gone]` either. Both tracking fields are still read — the `not fully pushed`
   row needs them — but neither decides who gets looked at.

   Enumerating more does not delete more. Every branch runs the full classification below, and
   only `merged` and `squash-merged` delete.
4. **Read the remote heads, once**, for the `not fully pushed` row:

   ```bash
   git for-each-ref --format='%(refname:strip=3)' refs/remotes/origin
   ```

   One command for the whole sweep; intersect names locally rather than probing per branch.
   `refs/remotes/origin/HEAD` contributes the name `HEAD`, which is harmless: git rejects
   `HEAD` as a branch name, so it can never match a local branch.
5. **List the protected branches**, once, for row 2:

   ```bash
   gh api --paginate "repos/{owner}/{repo}/branches?protected=true&per_page=100" --jq '.[].name'
   ```

   Paginate: the default page is 30 branches and truncation is silent, so a repo protecting a
   `release/*` pattern over more live branches would fail open on the branches row 2 exists to
   protect. Unless the call **succeeds**, the set is unknown rather than empty — a missing
   `gh`, a rate limit, a 403, and a non-GitHub `origin` all yield empty stdout. Row 2 then
   cannot fire, so mark every plan line whose action is *delete* — rows 6 and 7 both — as
   protection-unverified and read them before confirming; do not guess protection from branch
   names.
6. **Map worktrees.** `git worktree list --porcelain` — records separated by blank lines,
   each with a `worktree <path>` and, when a branch is checked out, `branch refs/heads/<name>`.
   A detached worktree emits `detached` instead and never enters the map; a `locked` record is
   a skip, since `git worktree remove` refuses one and the plan should not promise it. The
   first record is the main checkout, and nothing marks the *current* one — compare each
   `worktree <path>` against `git rev-parse --show-toplevel` to find it. Map branch → **set**
   of paths: `git worktree add --force` allows one branch in two worktrees, and a 1:1 map
   would let the plan promise one removal and then fail the deletion.
7. **Classify every candidate** (table below) before touching anything.
8. **Plan → confirm.** Present one table — `branch → classification → action` — including the
   skips and their reasons, and naming the path of every worktree the plan would remove.

   **Every removal line carries its ignored-file inventory.** Run
   `git -C <path> status --porcelain --ignored` while assembling the plan, and put the count
   and the root-level entries on the line:

   ```text
   delete feat/x (PR #42) — remove worktree /path/to/wt — destroys 2 ignored: .env, node_modules/
   ```

   Not on request. The invariant below makes every deleted branch's commits recoverable from
   the remote; ignored files under a removed worktree are the one thing in this sweep that
   nothing restores, so they are the only part of the plan the operator cannot check
   afterwards. A single confirmation over a list of paths, with one generic sentence saying
   ignored files go too, does not put `.env` in front of anyone.

   Take one explicit confirmation, then apply. A failure on one branch does not abort the
   sweep.

## Classification

Test each branch against these rows **in order; first match wins.** The order is load-bearing
now that enumeration is repo-wide: the base branch is an ancestor of `origin/<base>`, so an
unordered table would classify it `merged` and delete it.

| # | Candidate | Test | Action |
|---|---|---|---|
| 1 | base branch | name equals `<base>` | skip, name it |
| 2 | protected | name is in step 5's protected set | skip, name it |
| 3 | checked out where the sweep must not reach | branch is the HEAD of the main checkout, of the worktree the sweep is running in, of a locked worktree, or of more than one worktree | skip, name it |
| 4 | not fully pushed | neither push evidence holds: no `refs/remotes/origin/<branch>` in step 4's set **containing** the tip (`git merge-base --is-ancestor <branch> refs/remotes/origin/<branch>`), and no `%(upstream:track)` of `[gone]` whose `%(upstream:short)` is `origin/<branch>` | **skip, never delete** |
| 5 | dirty or unreadable worktree | the branch has a worktree and `git -C <path> status --porcelain` is non-empty or does not exit 0 | skip, name it |
| 6 | merged | `git merge-base --is-ancestor <branch> origin/<base>` succeeds | delete |
| 7 | squash-merged | not an ancestor, but `gh pr list --head <branch> --base <base> --state merged --json number,title,headRefOid --limit 20` returns a PR whose `headRefOid` satisfies `git merge-base --is-ancestor <branch> <headRefOid>` | delete; the plan line names that PR |
| 8 | unmerged | neither — no ancestry, and no merged PR containing this tip (or no `gh`/GitHub remote, or the merged head sha could not be obtained) | **report, never delete** |

**Row 2 is new because enumeration is.** Under the old `[gone]` predicate a long-lived
integration branch was never a candidate. Now it is: merge `release/1.2` into the base with
`--no-ff` and leave it in place, and it is an ancestor of `origin/<base>` with a live remote
head — indistinguishable by any local test from a feature branch nobody cleaned up. The
remote's protection setting is the signal that tells them apart, so read it; where it cannot
be read, the confirmation is the last guard and the plan has to say so.

**Row 3** covers the sweep's own worktree because `git worktree remove` will happily remove the
directory you are standing in and leave you with no working directory. It covers a branch in
two worktrees because `git branch -d` refuses a branch checked out anywhere, so removing one
of the two paths destroys a directory and still cannot delete the branch.

**This sweep has no liveness signal, and enumeration is now repo-wide, so any *other* linked
worktree it reaches may belong to an agent that is still running.** A dispatched worker's
pull request merges some way before the worker itself stops, and in that window the branch is
an ancestor of the base and the worktree is live. **The hard constraint below — do not run the
sweep while a campaign or a dispatched worker is in flight — is the only guard against this.**

Do not read row 5 as a second one. It catches a worker that left modified or untracked files,
which a worker that ended cleanly does not, and neither does one that has committed and is
mid-`push` — the state the incident behind this rule was actually observed in. A clean
`status` means nothing about whether a process is inside that directory.

**Never delete a branch whose commits are not on the remote.** Row 4 states a rule that used
to be an accident of enumeration — a branch with no upstream yielded an empty track field and
was never a candidate. State it positively: a branch is deletable only on *evidence that it
was pushed*, never on the absence of evidence that it was not. That evidence is a remote head
under the branch's own name that contains the branch tip, or a `[gone]` track field naming a
head that had the branch's own name.

The containment half of the first clause is what keeps a *stale* remote head from vouching
for a branch that reused its name. Push `feat/x`, merge it, delete the local branch, and with
the head ref kept, `origin/feat/x` outlives the work; start unrelated `feat/x` from
`origin/<base>` and a name-only test calls it pushed, after which row 6 sees a tip at the base,
calls it merged, and takes its worktree — and the ignored files under it — with it. Requiring
the remote head to contain the tip rejects that, and rejects the smaller case of a branch
carrying commits not yet pushed, which is the same guarantee said the other way round.

Both halves of the `[gone]` clause are load-bearing, because `[gone]` is a fact about
*whatever the branch tracks*, not about the branch. `git switch -c mine origin/theirs` sets
the upstream to a colleague's branch and pushes nothing; when their pull request merges and
GitHub deletes their head, `mine` reads `[gone]` while `refs/remotes/origin/mine` never
existed — and `mine` is now an ancestor of the base. Unscoped, the clause would delete it.
Scoping `[gone]` to `%(upstream:short)` equal to `origin/<branch>` is what makes it evidence
about this branch.

An upstream on its own is **not** evidence either. `git checkout -b <branch> origin/<base>`
sets one without pushing anything, so testing `%(upstream)` for non-empty would sweep away a
branch started thirty seconds ago.

**A branch pushed without `-u` in a repo that deletes head branches on merge is skipped
forever.** The push sets no upstream, so there is no `[gone]` to read, and the merge prunes
the remote head, so there is nothing left under the branch's own name either. Nothing local
survives to distinguish it from a branch that was never pushed, and the only remaining witness
would be a pull request matched by name alone — which row 7 deliberately refuses as deletion
evidence. The sweep reports it as `not fully pushed`, which is wrong but safe; push with
`-u` (or set `push.autoSetupRemote`) and the sweep collects it.

**Merged but never pushed is a skip, deliberately.** Ancestry proves the commits are in the
base; it does not prove the branch is residue. This sweep collects the residue of shipped
work, and a branch that was never pushed shipped nothing — no remote head, no pull request,
nothing saying the operator was finished with it. A local branch parked at or below the base
is an ancestor, so ancestry alone would collect every bookmark and just-created branch in the
checkout. Row 4 reports such a branch as a skip on every sweep and the operator deletes it by
hand: never-pushed local work is the one thing here that no remote copy can restore. Name its
worktree path in the skip line when it has one — `git branch -d` refuses a branch checked out
anywhere, so the operator has to deal with the worktree first.

**Row 5 sees modified and untracked files but not ignored ones, and removing a worktree
destroys the ignored ones.** `git status --porcelain` says nothing about `.env`,
`node_modules`, or local build state, so a worktree holding only those reads clean and
`git worktree remove` deletes them without `--force`. Under the old predicate almost no
worktree reached this; now every clean merged branch's does. That is why step 8 inventories
them onto the removal line rather than leaving them to a generic warning.

Gating row 5 on `--ignored` instead would skip every worktree holding a `node_modules`, which
is most of them, and turn the sweep back into the no-op this skill was written against. Show,
do not skip. Run the inventory *in* the worktree, as every row 5 test is: passing another
worktree's path as a pathspec fatals with `outside repository` and empty stdout, which reads
as "nothing would be lost" about a directory holding `.env`.

Read the exit code, not just the output. A worktree whose directory has been deleted is still
listed by `git worktree list --porcelain` and still enters the map, and `git status` there
exits 128 with empty stdout — which an output-only test reads as *clean*. That is the same
fail-open as an empty protected set, and it makes the plan promise to remove a path that is
not there.

**Row 7 costs one `gh` call per branch that reaches it**, and repo-wide enumeration sends more
branches there than `[gone]` alone did. The row order is the bound: the sweep spends two
whole-run lookups before the table (steps 2 and 5) and rows 1–6 are then local and free, so
the per-branch call fires only for a branch that was pushed and is *not* an ancestor of the
base — the set that is either squash-merged or genuinely unmerged, small in a working checkout
but not bounded in principle. A checkout carrying dozens of pushed, unmerged branches is that
many serial API calls, and they are the sweep's dominant latency and its whole rate-limit
cost. Rate-limited or without `gh`, those
branches fall to row 8 and are reported rather than deleted, so exhaustion costs a missed
collection, never a wrong deletion.

The squash-merged row exists because a squash or rebase merge rewrites the commits: GitHub
says merged, git ancestry says not. Without it, this skill would report the same leftovers
forever in any repo that squashes.

**Its evidence is the merged pull request's `headRefOid`, not its branch name.** A name proves
that *something* called `<branch>` was merged once, and repo-wide enumeration makes that a
data-loss path: delete a branch after its pull request merges, reuse the name for new work,
and the old merged pull request answers for the new local commits. Row 6 is safe from this
because ancestry is a statement about the commits themselves; row 7 gets the same property by
testing the local tip against the sha that was merged.

Containment, not equality. A local tip *behind* the merged head is ordinary — a reviewer
committing a suggestion in the GitHub UI advances `origin/<branch>` and a plain fetch never
fast-forwards the local branch — and everything it holds is in the pull request, so it is
collectable. A tip *ahead* holds commits the pull request does not, falls to row 8, and is
reported: that is work, not residue. Under a reused name the local commits are not ancestors
of the old head either, which is the property this row exists for.

**Scoped to `<base>`, and to every merged pull request rather than one.** `--head` matches a
head branch *name* across head repositories and says nothing about where the branch landed, so
without `--base` a branch merged into its parent in a stack — and still open against the base
— reads squash-merged here, and the sweep deletes a live working branch of an in-flight stack.
Its commits survive in `refs/pull/<n>/head`, so the invariant below holds, but the operator
loses the branch. `--limit 1` has the matching defect when several merged pull requests share
a head name: it picks one and the row's verdict turns on which. Take every merged pull request
for that head against this base and ask whether *any* of them contains the tip.

**`headRefOid` may not be in the local object database.** That is the same lagging-tip case:
the remote head advanced past what was fetched, and if the merge deleted it, a pruned fetch
never brings the sha down. `git merge-base --is-ancestor` then exits **128** with
`fatal: Not a valid commit name`, which is a missing object, not a verdict. Fetch it once —
`git fetch origin refs/pull/<number>/head`, which survives head-branch deletion and updates
only `FETCH_HEAD` — then re-run `git merge-base --is-ancestor <branch> <headRefOid>`.

**Against the sha, never against `FETCH_HEAD`.** The fetch exists to put the object in the
database, not to become the thing compared. Testing containment in `FETCH_HEAD` would key the
delete decision on a pull request *number* — a name-level inference again, in the row this
change removed one from — and `FETCH_HEAD` is whatever was fetched last, which under a
mispointed `gh` (step 1) can be a different pull request's head entirely.

Any other non-zero exit, and a failed fetch, mean row 8. Neither is a sweep failure.

## The invariant

Check a future widening against this, not against the row table:

> **Every deleted branch's tip is contained in a ref that lives on the remote.** Deletion
> requires `tip` to be an ancestor of `origin/<base>` (row 6) or of a merged pull request's
> `headRefOid` (row 7), and this sweep never deletes a remote ref — there is no
> `git push --delete` anywhere in it.

So a deletion is recoverable: the tip is still on the remote, and the reported sha with
`git branch <name> <sha>` restores the local ref. A new row, or a loosened test, that can
delete a branch whose tip is not contained in a remote ref breaks this — whatever the row
table says, and whatever the row is called.

The row table is how the invariant is currently enforced, not the thing to reason from. It has
been wrong twice: both push-evidence clauses in row 4 and the original row 7 were name-level
tests, and a name is reusable, so each in turn admitted a branch whose tip was on no remote
ref. Enumerating the rows and arguing each is safe is exactly the reasoning that failed. Ask
instead which ref the deletion's containment is anchored to, and whether that ref is remote.

**Ignored files under a removed worktree are the one exception**, and therefore the only
irreversible loss in this design. They are on no remote and in no reflog. That is what the
plan lines in step 8 exist to show.

## Deletion rules

- **Row 6 and row 7 are the only land checks.** Do not read `git branch -d` as a second,
  independent guard: it tests a branch against its own upstream when it has one and against
  your current `HEAD` otherwise, never against `origin/<base>`. On the squash path it prints
  `merged to 'refs/remotes/origin/<branch>', but not yet merged to HEAD` and **succeeds** on a
  branch that is no ancestor of the base. Where the branch has *no* upstream — a push without
  `-u` still leaves a remote head, so row 4 admits it — `-d` compares against `HEAD` instead,
  so its verdict depends on what you happen to have checked out. Neither reading is the one
  rows 6 and 7 made, which is why the `-D` fallback below is the normal path rather than an
  exception.
- Try `-d` first anyway, since its refusals are informative, and fall back to `-D` for a
  branch rows 6 or 7 already classified and for nothing else. Never `-D` a branch classified
  unmerged — that needs the operator naming it after seeing it in the plan.
- Remove a branch's worktree *before* deleting the branch: `git worktree remove <path>`, since
  `git branch -d` refuses a branch checked out in any worktree. Never `--force` — a dirty
  worktree is a skip, not something to bulldoze. Never remove the main checkout or the
  worktree the sweep is running in.

## Output contract

- one `deleted <branch> (<sha>)` line per deletion, plus `removed worktree <path>` when one
  was attached — report the sha1 git prints, since `git branch <name> <sha>` restores it, and
  the path, since nothing restores the ignored files that were under it
- one line per skip, with its reason, and its worktree path when it has one — a skipped branch
  the operator wants gone needs the worktree dealt with first
- `nothing to prune — no branch classified merged or squash-merged` when the delete set is
  empty, printed *alongside* the skip lines and the counts, not instead of them. It is a
  statement about the *delete* set, not the candidate set: repo-wide enumeration leaves the
  latter empty only in a repo with no local branches, so "nothing deleted, six skipped" is
  the ordinary outcome in a tidy repo and the skips are most of what the sweep has to say.
- close with counts: N deleted, M skipped, and the unmerged list if non-empty

## Hard constraints

- **Never delete a branch whose tip is not contained in a ref that lives on the remote.** The
  invariant above; every other rule here serves it.
- Confirm `origin` exists, `git fetch --prune` succeeds, `gh` resolves to that same repository,
  and the base branch resolves — before any evaluation. Every row reads `refs/remotes/origin`,
  and a stale, absent, or misidentified reference is worse than no sweep.
- Candidates are every local branch, read from `for-each-ref` plumbing, never from grepping
  `git branch` output. The ordered rows decide what happens to each, not the enumeration.
- Never delete the base branch, a protected branch, or a branch checked out in the main
  worktree, in the sweep's own worktree, in a locked worktree, or in two worktrees at once.
- Show every removal's ignored-file inventory in the plan before the confirmation. It is the
  only loss in this sweep that nothing can undo.
- Pass branch names and worktree paths as **arguments**, never interpolated into a shell
  string. `git check-ref-format` rejects whitespace but permits `;`, `&`, `$` and `|`, and
  repo-wide enumeration now feeds every local branch — including any created from a remote
  someone else controls — into `gh pr list --head` and `git merge-base`.
- One confirmation before the first deletion; list every branch, and every worktree path the
  plan would remove, before acting on it.
- Never `git worktree remove --force`; never `-D` an unmerged branch.
- Never run the sweep while a campaign or dispatched worker is in flight; it cannot tell a
  live worktree from an abandoned one.
