---
name: executing-plans
description: "Use when you have a written implementation plan to execute in a separate session, reviewing the plan before starting and reporting when complete"
---

# Executing Plans

## Overview

Load plan, review critically, execute all tasks, report when complete.

**Announce at start:** "I'm using the executing-plans skill to implement this plan." Name the resolved mode (below) in the same line.

**Note:** This skill is the no-subagent fallback. If subagents are available, use subagent-driven-development instead — quality is significantly higher with per-task subagents.

## Dispatched mode — no human in the turn

**You are in dispatched mode when your instructions came from a curated skill (`$build-tdd`, `$work-issue`) or from an orchestrator that dispatched you — not from a human typing in this turn.** Otherwise assume a human is present and follow the rest of this skill as written. Do not try to infer the mode: your caller states it. Mode is a property of the run, not of the skill, so every skill you invoke downstream inherits it.

Two things change:

- **Step 3 is not your terminal state.** Do not invoke `finishing-a-development-branch`. Executing the plan is one step inside a longer pipeline — `$review-loop`, `$simplify-changes`, `$ship-pr` and `$merge-cleanup` come after it, and they own integration. Run the caller's guardrail suite, then report to your caller and return.
- **"Raise them with your human partner" means report to your caller.** Step 1.3's concerns, and every stop in *When to Stop and Ask for Help*, go into your completion report as a blocker — outcome, what you need, and where you stopped — following the subagent report contract in the repo's `AGENTS.md`. Do not wait for a reply that will not come, and do not guess past a genuine blocker either.

## The Process

### Step 1: Load and Review Plan
1. Read plan file
2. Review critically - identify any questions or concerns about the plan
3. If concerns: Raise them with your human partner before starting (in dispatched mode, report them to your caller — see Dispatched mode)
4. If no concerns: Create todos for the plan items and proceed

### Step 2: Execute Tasks

For each task:
1. Mark as in_progress
2. Follow each step exactly (plan has bite-sized steps)
3. Run verifications as specified
4. Mark as completed

### Step 3: Complete Development

After all tasks complete and verified:
- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use finishing-a-development-branch
- Follow that skill to verify tests, present options, execute choice

**In dispatched mode, skip this step.** Report to your caller instead — it owns integration. See Dispatched mode above.

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**Ask for clarification rather than guessing.** In dispatched mode there is nobody to ask: report the blocker to your caller and stop. Either way, do not guess past it.

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.

## Remember
- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Reference skills when plan says to
- Stop when blocked, don't guess
- Never start implementation on main/master branch without explicit user consent

## Integration

**Required workflow skills:**
- **using-git-worktrees** - Ensures isolated workspace (creates one or verifies existing)
- **`$design`** - Its `inscribe` phase writes the plan this skill executes
- **finishing-a-development-branch** - Complete development after all tasks (interactive mode only; in dispatched mode the caller owns integration)
