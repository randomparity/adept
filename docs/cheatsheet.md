# Skill cheat sheet

One page of "which skill do I run." Full detail lives in each skill's
`SKILL.md`; this is the printable summary. Invoke a skill by typing its slash
command (`/quest 42`) in Claude Code or (`$quest 42`) in Codex, or asking for
it by name — the skill descriptions below are what the harness matches against.

## Start here

| Situation | Run |
|---|---|
| I have one GitHub issue to implement, start to finish | `/quest` |
| I have a rough feature idea that will span multiple PRs | `/saga` |
| I have a batch of issues to clear | `/campaign` |
| I found a bug or gap that isn't an issue yet | `/bounty` |
| I want to know how big/risky an issue is before committing | `/divination` |
| I want the next issue to work, chosen for me | `/seek-quest` |
| My backlog needs type/priority/status labels | `/sort-board` |
| A branch or diff needs review before it ships | `/gauntlet` or `/trial-loop` |
| Something broke and I don't know why yet | `/detect-curse` |
| A PR is ready to become mergeable | `/deliver` |
| A PR is green and ready to merge | `/return-to-town` |
| A merged PR turned out bad | `/counterspell` |
| Dependabot has PRs open | `/restock` |
| Merged branches are cluttering the worktree | `/clear-map` |
| It's been a while since the last run — labels may be stale | `/resurrection` |
| My `AGENTS.md` or `CLAUDE.md` guidance has drifted | `/reincarnate` |
| I want a maintenance sweep without doing the work | `/warding` |
| I just solved something worth remembering | `/grimoire` |

## Full lifecycle: `/quest`

`/quest` is the flagship entry point — one issue, start to finish. It calls
the phase skills below in order so you don't have to invoke them individually:

```
attunement (preflight)
  -> scope the issue, classify: trivial / governed-small-change / non-trivial
  -> branch
  -> spellcraft (spec, ADR, plan — skipped for trivial work)
       -> oathbind (scope audit, non-trivial only)
  -> forge (TDD build)
  -> trial-loop (adversarial review + fix loop)
       -> detect-evil (security pass, when the diff is security-relevant)
  -> dispel (simplify)
  -> deliver (push, open PR, drive to green CI)
  -> return-to-town (hand off, or merge if authorized)
```

`/campaign` runs this same lifecycle over a set of issues, in parallel where
safe, and serializes merges.

Have no specific issue in mind? `$seek-quest` ranks the `status:ready` queue
and recommends one before you start the lifecycle above — a separate,
read-only step, not a new stage of `/quest` itself.

## Phase skills (run standalone when you only need one step)

| Skill | Does | Called by |
|---|---|---|
| `attunement` | Discover repo conventions, base branch, guardrail commands, gh auth | `quest`, `campaign`, `deliver`, `forge`, `spellcraft` |
| `spellcraft` | Write a spec/ADR and implementation plan for a non-trivial change, with adversarial review of both | `quest` |
| `oathbind` | Audit a completed design against its frozen scope before implementation | `quest` (step 4) |
| `forge` | Implement an approved plan with TDD and the guardrail suite | `quest`, `deliver`, `return-to-town` |
| `trial-loop` | Iterative adversarial review → fix → re-review loop, with deferral records for disposed findings | `quest`, `forge`, `gauntlet`, `spellcraft` |
| `gauntlet` | One-shot hostile/adversarial review of code, diffs, specs, or plans | `trial-loop`, `forge` |
| `detect-evil` | Diff-scoped security pass: validation, auth, secrets, crypto, supply chain | `quest` (step 6, when diff is security-relevant) |
| `dispel` | Behavior-preserving simplification pass, then re-verify | `quest` (step 7) |
| `detect-curse` | Root-cause a failing test, bug, or broken build before touching code | standalone |
| `deliver` | Push branch, open/update PR, drive to green CI and mergeable state | `quest`, `attunement`-driven flows |
| `return-to-town` | Hand off a green PR, or merge it if explicitly authorized, then clean up | `quest`, `campaign`, `clear-map` |

## Planning & backlog

| Skill | Does |
|---|---|
| `saga` | Interview a rough idea into an epic: PRD plus dependency-ordered, triaged sub-issues |
| `bounty` | Verify, dedupe, and file a grounded GitHub issue; also decomposes an epic into sub-issues |
| `divination` | Estimate an issue's blast radius, risk, and whether it fits one PR |
| `sort-board` | Apply type/priority/status/risk/effort labels to a backlog, bootstrapping labels if missing |
| `seek-quest` | Rank the `status:ready` queue and recommend the next issue to run `$quest` on |

## Batch orchestration & hygiene

| Skill | Does |
|---|---|
| `campaign` | Drive a set of issues to done: triage, dependency planning, parallel execution, serial merge |
| `counterspell` | Reverse a bad merged PR: revert or fix-forward, tracking writes, expedited-but-present review |
| `reincarnate` | Rebuild stale `AGENTS.md` or `CLAUDE.md` guidance from current repository evidence |
| `resurrection` | Reconcile status labels with actual PR/branch state; reset stale orphaned work |
| `clear-map` | Delete local branches whose work has landed and remove their worktrees |
| `restock` | Evaluate open Dependabot PRs against a clean baseline, group and merge safe ones |
| `warding` | Sweep for stale issues, dependency drift, and advisories without doing the work |

## Retrospective & knowledge capture

| Skill | Does |
|---|---|
| `bards-tale` | Mine GitHub workflow telemetry (cycle time, review iterations) into a retrospective report |
| `grimoire` | Capture a non-obvious, verified solution as a durable doc for later recall |
| `summon-swarm` | Fan out high-volume, well-specified generation to parallel Codex CLI workers |

## Conventions (consulted, not run directly)

| Reference | Defines |
|---|---|
| `quest-log` | The `status:*` label state machine and `WORK:*` PR-annotation convention that keeps pipeline state on GitHub |
| `tome-of-lore` | The `docs/adr/` and `docs/debt/` record formats and the CI gate that enforces them |
