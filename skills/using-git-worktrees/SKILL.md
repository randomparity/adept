---
name: using-git-worktrees
description: "Use when starting feature work that needs isolation from current workspace or before executing implementation plans - ensures an isolated workspace exists via native tools or git worktree fallback"
---

# Using Git Worktrees

## Overview

Ensure work happens in an isolated workspace, always **outside** the repository tree. Prefer your platform's native worktree tools. Fall back to manual git worktrees when no native tool is available, or when the native tool would nest the worktree inside the repo.

**Core principle:** Detect existing isolation first. Then use native tools. Then fall back to git. Don't fight the harness — except on placement, where a worktree inside the repo is never acceptable.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Mode

Interactive mode is the default. Dispatched mode applies only when a caller or
orchestrator explicitly states it, and the resolved mode remains in effect for this run.

At a failed baseline gate, written authority is deliberately narrow.
An applicable caller instruction or repository rule must explicitly address the failed baseline.
Generic dispatch, autonomy, or task-completion language does not resolve the gate.
Apply normal instruction priority when multiple sources address the gate.
If instruction priority does not yield one unambiguous action, return the blocker.

## Step 0: Detect Existing Isolation

**Before creating anything, check if you are already in an isolated workspace.**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

**Submodule guard:** `GIT_DIR != GIT_COMMON` is also true inside git submodules. Before concluding "already in a worktree," verify you are not in a submodule:

```bash
# If this returns a path, you're in a submodule, not a worktree — treat as normal repo
git rev-parse --show-superproject-working-tree 2>/dev/null
```

**If `GIT_DIR != GIT_COMMON` (and not a submodule):** You are already in a linked worktree. Skip to Step 2 (Project Setup). Do NOT create another worktree.

Report with branch state:
- On a branch: "Already in isolated workspace at `<path>` on branch `<name>`."
- Detached HEAD: "Already in isolated workspace at `<path>` (detached HEAD, externally managed). Branch creation needed at finish time."

**If `GIT_DIR == GIT_COMMON` (or in a submodule):** You are in a normal repo checkout.

Has the user already indicated their worktree preference in your instructions? If not, ask for consent before creating a worktree:

> "Would you like me to set up an isolated worktree? It protects your current branch from changes."

Honor any existing declared preference without asking. If the user declines consent, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

**You have two mechanisms. Try them in this order.**

### 1a. Native Worktree Tools (preferred, unless they nest)

The user has asked for an isolated workspace (Step 0 consent). Do you already have a way to create a worktree? It might be a tool with a name like `EnterWorktree`, `WorktreeCreate`, a `/worktree` command, or a `--worktree` flag. If you do, check **where it puts the worktree** before using it.

Native tools handle directory placement, branch creation, and cleanup automatically. Using `git worktree add` when you have a native tool creates phantom state your harness can't see or manage. So use it — unless it nests.

**Refuse it if it nests.** If the native tool would place the worktree inside the repository tree (under `.codex/`, a project-local `.worktrees/`, or any other subdirectory of the working copy), do not use it. Go to Step 1b and run `git worktree add` against an external path yourself. Whole-tree tooling — linters, type checkers, test discovery, search — walks a nested worktree and then fails your commit on another agent's in-flight code. Harness-managed cleanup does not buy back that cost.

Otherwise, use the native tool and skip to Step 2. Proceed to Step 1b only if you have no native worktree tool, or the one you have would nest.

### 1b. Git Worktree Fallback

**Only use this if Step 1a does not apply** — you have no native worktree tool, or the one you have would nest the worktree inside the repo. Create a worktree manually using git.

#### Directory Selection

**Worktrees live outside the repository tree.** Never nest one inside the working copy — not `.worktrees/`, not `worktrees/`, not under `.codex/`, not any other subdirectory. Whole-tree tooling (linters, type checkers, test discovery, search) walks a nested worktree and fails your commit on another agent's in-flight code. A `.gitignore` entry does not fix this; those tools do not all honour it.

Follow this priority order. Explicit user preference always beats observed filesystem state, but it does not override the placement rule above — if your instructions name a path inside the repo, say so and use an external one instead.

1. **Check your instructions for a declared worktree directory preference.** If the user has specified an external one, use it without asking.

2. **Check for an existing sibling worktree root:**
   ```bash
   root=$(cd "$(git rev-parse --show-toplevel)" && pwd -P)
   ls -d "$(dirname "$root")/$(basename "$root")-worktrees" 2>/dev/null
   ```
   If found, use it.

3. **If there is no other guidance available**, default to `../<repo>-worktrees/` — a sibling of the repository root.

#### Create the Worktree

```bash
# LOCATION: the sibling worktree root, outside the repo tree.
REPO_ROOT=$(cd "$(git rev-parse --show-toplevel)" && pwd -P)
LOCATION="$(dirname "$REPO_ROOT")/$(basename "$REPO_ROOT")-worktrees"

# BRANCH_NAME: the branch your instructions assigned you. Dispatching commands
# name it explicitly (e.g. `feat/<short-slug>-<issue>` from $work-issue). If
# nothing assigned one, derive it from the work you are about to start and
# report the name you chose.
BRANCH_NAME="feat/<short-slug>-<issue>"

path="$LOCATION/$BRANCH_NAME"

mkdir -p "$(dirname "$path")"
git worktree add "$path" -b "$BRANCH_NAME"
cd "$path"
```

#### Safety Verification

**Confirm the worktree really landed outside the repo before working in it:**

```bash
case "$(pwd -P)/" in
  "$REPO_ROOT"/*) echo "NESTED — relocate this worktree outside $REPO_ROOT" ;;
esac
```

**If it printed:** remove the worktree (`git worktree remove`), pick an external path, and create it again. Do not paper over it with a `.gitignore` entry.

**Sandbox fallback:** If `git worktree add` fails with a permission error (sandbox denial), tell the user the sandbox blocked worktree creation and you're working in the current directory instead. Then run setup and baseline tests in place.

## Step 2: Project Setup

Auto-detect and run appropriate setup:

```bash
# Node.js
if [ -f package.json ]; then npm install; fi

# Rust
if [ -f Cargo.toml ]; then cargo build; fi

# Python
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi

# Go
if [ -f go.mod ]; then go mod download; fi
```

## Step 3: Verify Clean Baseline

Run tests to ensure workspace starts clean:

```bash
# Use project-appropriate command
npm test / cargo test / pytest / go test ./...
```

**If tests fail:**

- **Interactive mode:**
  Report the failures, ask whether to proceed or investigate, and wait.
- **Dispatched mode with resolving authority:**
  Report the failures, then follow the explicit applicable instruction or repository rule.
- **Dispatched mode without resolving authority:**
  Report the failures as a blocker and return to the caller.
  Do not ask an unavailable user, infer permission to continue, or start implementation.

**If tests pass:** Report ready.

### Report

```
Worktree ready at <full-path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already in linked worktree | Skip creation (Step 0) |
| In a submodule | Treat as normal repo (Step 0 guard) |
| Native tool, places worktree outside the repo | Use it (Step 1a) |
| Native tool, would nest inside the repo | Refuse it, use Step 1b |
| No native tool | Git worktree fallback (Step 1b) |
| `../<repo>-worktrees/` exists | Use it |
| It does not exist | Check instruction file, then default `../<repo>-worktrees/<branch>` |
| Instructions name a path inside the repo | Say so, use an external path anyway |
| Worktree landed inside the repo | Remove it, recreate outside — never gitignore around it |
| Permission error on create | Sandbox fallback, work in place |
| Tests fail in interactive mode | Report failures + ask + wait |
| Tests fail in dispatched mode with explicit authority | Report failures + follow it |
| Tests fail in dispatched mode otherwise | Return failures as a blocker |
| No package.json/Cargo.toml | Skip dependency install |

## Common Mistakes

### Fighting the harness

- **Problem:** Using `git worktree add` when the platform already provides isolation
- **Fix:** Step 0 detects existing isolation. Step 1a defers to native tools.

### Skipping detection

- **Problem:** Creating a nested worktree inside an existing one
- **Fix:** Always run Step 0 before creating anything

### Nesting the worktree inside the repo

- **Problem:** Whole-tree tooling walks it — linters, type checkers, test discovery and search see another agent's in-flight code and fail your commit on it
- **Fix:** Create it at a sibling path outside the repo root; verify with the Step 1b check

### Assuming directory location

- **Problem:** Creates inconsistency, violates project conventions
- **Fix:** Follow priority: explicit instructions > existing sibling worktree root > default `../<repo>-worktrees/`

### Proceeding with failing baseline tests

- **Problem:** Can't distinguish new bugs from pre-existing issues
- **Fix:** In interactive mode, report failures and wait for the answer. In dispatched
  mode, follow only authority that explicitly addresses the failed baseline; otherwise
  return the blocker.

## Red Flags

**Never:**
- Create a worktree when Step 0 detects existing isolation
- Use `git worktree add` when you have a native worktree tool (e.g., `EnterWorktree`) that places the worktree outside the repo. If you have it and it does not nest, use it.
- Skip Step 1a by jumping straight to Step 1b's git commands, without first checking where the native tool would place the worktree
- Create a worktree inside the repository tree — including a project-local `.worktrees/`, even a gitignored one
- Skip baseline test verification
- Treat generic dispatch or task-completion instructions as permission to proceed after a
  failed baseline

**Always:**
- Run Step 0 detection first
- Prefer native tools over git fallback, unless the native tool would nest the worktree inside the repo
- Follow directory priority: explicit instructions > existing sibling worktree root > default `../<repo>-worktrees/`
- Verify the created worktree resolves outside the repository root
- Auto-detect and run project setup
- Verify clean test baseline
- Preserve the interactive decision gate or return unresolved dispatched failures to the
  caller
