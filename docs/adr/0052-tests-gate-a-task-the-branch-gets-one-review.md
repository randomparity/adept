# 0052 — Tests gate a task; the branch gets one review

## Status

Accepted (2026-09-01)

Refines [0011](0011-canonical-workflow-review-vocabulary.md), which described "forge's task and
branch reviewers" as a pair and routed forge's severities through both. There is now one forge
reviewer, so every clause 0011 states about the task reviewer describes a dispatch that no longer
happens; the vocabulary, the artifact contract it carried forward from
[0007](0007-whole-branch-review-package-and-report.md), and the routing rules are otherwise
unchanged and now bind the whole-branch reviewer alone.

## Context

`$forge`'s party mode dispatched a task reviewer after every task and a whole-branch reviewer
once at the end — n+1 reviewer dispatches for an n-task plan, each a fresh full-context worker,
which is the pipeline's dominant cost.

The task reviewer's job was a spec-compliance check plus a quality verdict over one task's diff
package. But every task already ends at a runnable pass/fail gate: `$forge` implements with TDD,
so a task closes on a failing test made to pass plus the repo's guardrail suite. The adversarial
pass on top of that reviews surface the previous task's fixes just wrote — the self-collision
`$trial-loop` spends an entire stop condition detecting, here without the stop condition, once
per task.

It was also the narrowest reviewer in the pipeline. Confined to its package by its own template,
it could not settle a requirement living in unchanged code or spanning tasks; it reported those
as "⚠️ Cannot verify from diff" and handed them back to the orchestrator, which is where the
whole-branch review already looks.

## Decision

**1. A task's gate is its tests and guardrails.** The per-task loop closes a task on three
things the orchestrator can check without a dispatch: the implementer's reported commits are
ancestors of the assigned branch, the range from the task's base is non-empty, and the report
names the test and guardrail commands it ran and what they returned. A report naming no
executable evidence is `NEEDS_CONTEXT`, not a finished task.

**2. One whole-branch review, unchanged in contract.** The single review before handoff keeps
its package, its review-file path, its bounded return, its ledger lifecycle, and its `required` /
`required-failed` result modes. `$quest` consumes exactly what it consumed before, so nothing
downstream of `$forge` changes.

**3. The orchestrator runs the guardrail suite over the assembled branch before that review.**
The task reviewer was the party that treated the implementer's test claims as claims. Its
removal is replaced by an executable check rather than by trust: one guardrail run over every
task's work together, before the review dispatch, red fixed first. That run is also the first
thing in the party to see the tasks assembled.

**4. `skills/forge/task-reviewer-prompt.md` is deleted, not left dormant.** A shipped template
is selectable, and the low-findings ledger it fed — `[LOW_LEDGER]` and the whole-branch
reviewer's `#### Low triage` section — has no source once no task review produces low findings.
Both are removed with it; the review's own low findings go to the ledger with their disposition,
as they already did.

## Consequences

An n-task party run makes 1 reviewer dispatch instead of n+1, plus the fix workers a finding
actually earns. The saving scales with the task count, so it is largest on exactly the plans that
were most expensive.

A defect now lives on the branch from the task that introduced it until the whole-branch review,
where before a task-scoped reviewer could have caught it one dispatch later. That is the trade.
What bounds it is that the defect classes a task-scoped pass could catch are the ones its own
tests and the branch guardrail run cover, and the whole-branch reviewer reads the same diff with
more context than its task-scoped predecessor had.

The whole-branch review carries more surface per pass. Its input was already the whole branch
package — the change is that it is now the first adversarial reader of that surface rather than
the second, so a finding it raises is more likely to be genuinely new.

`$forge` no longer has a per-task fix-and-re-review cycle, so the "do not move on with any
finding still open" rule has one place to apply instead of two, and `$trial-loop`'s statement of
forge's timing collapses to one clause.

## Considered & rejected

- **Keep the task review but only for high-risk tasks.** judgment: the routing input would be
  per-task risk, which nothing produces — `$divination` scores the issue, not the plan's tasks —
  so the predicate would be the orchestrator's own impression of a task it has not read, decided
  once per task. A gate whose condition is guessed is the shape ADR 0025 warns about.
- **Keep the task review and drop the whole-branch review instead.** verified:
  `skills/forge/task-reviewer-prompt.md` bound its reviewer to the task's package ("Stay out of
  the rest of the codebase", "Open that package once; it is the whole of what you are judging")
  and defined a "⚠️ Cannot verify from diff" bucket for anything spanning tasks. Dropping the
  only reviewer that can see across tasks keeps the n dispatches and removes the one that catches
  what they cannot.
- **Replace the task review with a cheaper model on the same template.** verified: the model
  rubric in `skills/forge/SKILL.md` already put a mid-tier floor under reviewers and warns that a
  weak model on a multi-step job costs more turns than the stronger one. The cost being removed
  is a dispatch per task, not a price per token.
- **Have the orchestrator read each task's diff itself instead of dispatching.** verified: the
  same skill's *What goes in a dispatch* requires artifacts to be handed over as files precisely
  because anything the orchestrator reads stays resident in its context and is re-read every
  later turn — and ADR 0007 bounded the whole-branch return for that reason. Reading n task diffs
  inline reintroduces the accumulation both decisions removed.
- **Do nothing.** verified: #289 records the shape — n+1 reviewer dispatches where n of them
  re-review surface the previous pass wrote, against tasks that already ended green.
