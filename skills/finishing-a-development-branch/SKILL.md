---
name: finishing-a-development-branch
description: "Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting structured options for merge, PR, or cleanup"
---

# Finishing a Development Branch

## Overview

Guide completion of development work by presenting clear options and handling chosen workflow.

**Core principle:** Verify tests → Detect environment → Present options → Execute choice → Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work." Name the mode you resolved below in the same line, so the transcript records which branch you took.

## Dispatched mode — no human in the turn

**You are in dispatched mode when your instructions came from a curated skill (`$build-tdd`, `$work-issue`) or from an orchestrator that dispatched you — not from a human typing in this turn.** Otherwise assume a human is present and follow the rest of this skill as written. Do not try to infer the mode from context: your caller states it. Mode is a property of the run, not of the skill, so every skill you invoke downstream inherits it.

In dispatched mode there is nobody to answer Step 4's menu, and stopping to present it is a deadlock. Instead:

1. Run **Step 1** (verify tests) and report the result to your caller.
2. Take **no integration action** — no merge, no push, no branch deletion, no discard. You are not the terminal state of a dispatched run; you are one step inside it.
3. Skip **Steps 2, 3, 4 and 5** entirely. Skip **Step 6**: the caller cleans up its own worktree after the PR merges.
4. Return to your caller. It owns integration, and in this pipeline that means `$ship-pr` (push, open the PR, drive it green) then `$merge-cleanup` (hand off to a human by default; self-merge only under explicit operator authorization, via `gh pr merge`).

If tests fail, report the failure to your caller and stop as blocked — the caller's blocker protocol takes over. Do not fix them here.

## The Process

### Step 1: Verify Tests

**Before presenting options, verify tests pass:**

```bash
# Run project's test suite
npm test / cargo test / pytest / go test ./...
```

**If tests fail:**
```
Tests failing (<N> failures). Must fix before completing:

[Show failures]

Cannot proceed with merge/PR until tests pass.
```

Stop. Don't proceed to Step 2.

**If tests pass:** Continue to Step 2.

### Step 2: Detect Environment

**Determine workspace state before presenting options:**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
```

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| `GIT_DIR == GIT_COMMON` (normal repo) | Standard 4 options | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | Standard 4 options | Provenance-based (see Step 6) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Reduced 3 options (no merge) | No cleanup (externally managed) |

### Step 3: Determine Base Branch

```bash
# Try common base branches
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from main - is that correct?"

### Step 4: Present Options

**Normal repo and named-branch worktree — present exactly these 4 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

**Drop option 1 where the base branch is protected.** Check first: does the repo forbid committing or pushing to its default branch — a branch-protection rule, or a house rule like "never push directly to main"? If so, option 1 is not a real choice there, so present the other three renumbered rather than offering a path the repo rejects. Say one line explaining the omission.

**Detached HEAD — present exactly these 3 options:**

```
Implementation complete. You're on a detached HEAD (externally managed workspace).

1. Push as new branch and create a Pull Request
2. Keep as-is (I'll handle it later)
3. Discard this work

Which option?
```

**Don't add explanation** - keep options concise.

### Step 5: Execute Choice

#### Option 1: Merge Locally

**This merge is local, and publishing it is a separate act this skill does not perform.** After it, `<base-branch>` is ahead of its remote; getting it there means pushing the default branch, which many repos forbid and some deny outright. Do not push it as a follow-on to this option. If the work needs to reach the remote, that is option 2.

```bash
# Get main repo root for CWD safety
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"

# Merge first — verify success before removing anything
git checkout <base-branch>
git pull
git merge <feature-branch>

# Verify tests on merged result
<test command>

# Only after merge succeeds: cleanup worktree (Step 6), then delete branch
```

Then: Cleanup worktree (Step 6), then delete branch:

```bash
git branch -d <feature-branch>
```

#### Option 2: Push and Create PR

```bash
# Push branch
git push -u origin <feature-branch>
```

**Do NOT clean up worktree** — user needs it alive to iterate on PR feedback.

#### Option 3: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

**Don't cleanup worktree.**

#### Option 4: Discard

**Confirm first:**
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for exact confirmation.

If confirmed:
```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

Then: Cleanup worktree (Step 6), then force-delete branch:
```bash
git branch -D <feature-branch>
```

### Step 6: Cleanup Workspace

**Only runs for Options 1 and 4.** Options 2 and 3 always preserve the worktree.

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
```

**If `GIT_DIR == GIT_COMMON`:** Normal repo, no worktree to clean up. Done.

Otherwise, decide provenance. A worktree is **ours** when it sits where `$build-tdd`'s pocket-dimension mode puts one: under the sibling root `../<repo>-worktrees/`, or — for a worktree predating that default — under a nested `.worktrees/`/`worktrees/`.

```bash
# Resolve BOTH sides with `pwd -P` before comparing. A symlinked checkout
# can make an unresolved prefix compare report "not ours" and refuse a cleanup
# we own.
WORKTREE_PATH=$(cd "$(git rev-parse --show-toplevel)" && pwd -P)
MAIN_ROOT=$(cd "$(git rev-parse --git-common-dir)/.." && pwd -P)
SIBLING_ROOT="$(dirname "$MAIN_ROOT")/$(basename "$MAIN_ROOT")-worktrees"

case "$WORKTREE_PATH" in
"$SIBLING_ROOT"/?*) OURS=yes ;;                                   # current default
"$MAIN_ROOT"/.worktrees/?* | "$MAIN_ROOT"/worktrees/?*) OURS=yes ;;  # legacy nested
*) OURS=no ;;
esac
```

**If `OURS=yes`:** we created this worktree — we own cleanup.

```bash
cd "$MAIN_ROOT"
git worktree remove "$WORKTREE_PATH"
git worktree prune  # Self-healing: clean up any stale registrations
```

**If `OURS=no`:** The host environment (harness) owns this workspace. Do NOT remove it. If your platform provides a workspace-exit tool, use it. Otherwise, leave the workspace in place.

## Quick Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | yes | - | - | yes |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| 4. Discard | - | - | - | yes (force) |

## Common Mistakes

**Skipping test verification**
- **Problem:** Merge broken code, create failing PR
- **Fix:** Always verify tests before offering options

**Open-ended questions**
- **Problem:** "What should I do next?" is ambiguous
- **Fix:** Present exactly 4 structured options (or 3 for detached HEAD)

**Cleaning up worktree for Option 2**
- **Problem:** Remove worktree user needs for PR iteration
- **Fix:** Only cleanup for Options 1 and 4

**Deleting branch before removing worktree**
- **Problem:** `git branch -d` fails because worktree still references the branch
- **Fix:** Merge first, remove worktree, then delete branch

**Running git worktree remove from inside the worktree**
- **Problem:** Command fails silently when CWD is inside the worktree being removed
- **Fix:** Always `cd` to main repo root before `git worktree remove`

**Cleaning up harness-owned worktrees**
- **Problem:** Removing a worktree the harness created causes phantom state
- **Fix:** Only clean up worktrees under the `../<repo>-worktrees/` sibling root, or a legacy nested `.worktrees/`/`worktrees/`

**Comparing an unresolved path against a resolved one**
- **Problem:** A symlinked checkout makes the provenance test report "not ours", so Step 6 refuses to remove a worktree it created
- **Fix:** Run both the worktree path and the main repo root through `pwd -P` before the prefix compare

**Presenting the menu when nobody is in the turn**
- **Problem:** A dispatched run stops mid-pipeline waiting on an answer, or takes an integration action its caller forbids
- **Fix:** Resolve the mode first. In dispatched mode, verify tests, report, and return — see Dispatched mode above

**No confirmation for discard**
- **Problem:** Accidentally delete work
- **Fix:** Require typed "discard" confirmation

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Delete work without confirmation
- Force-push without explicit request
- Remove a worktree before confirming merge success
- Clean up worktrees you didn't create (provenance check)
- Run `git worktree remove` from inside the worktree
- Present a menu, merge, push, or discard in dispatched mode
- Push `<base-branch>` after an Option 1 merge

**Always:**
- Resolve dispatched vs interactive mode before anything else
- Verify tests before offering options
- Detect environment before presenting menu
- Present exactly 4 options (3 for detached HEAD, or 3 where the base branch is protected)
- Get typed confirmation for Option 4
- Clean up worktree for Options 1 & 4 only
- `cd` to main repo root before worktree removal
- Run `git worktree prune` after removal
