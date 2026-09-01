---
name: spellcraft
description: "Design a non-trivial code change before implementation by writing a spec or ADR, producing an implementation plan, and adversarially reviewing the whole design set in one loop. Use for issues or changes involving public contracts, schemas, auth, concurrency, migrations, persistence, dependencies, AI surfaces, security boundaries, or external services."
---
# Design First

Tighten the design before writing code. Defects are cheapest to fix in the
spec, then the plan, then the source. This covers the full design phase:
spec + ADR, implementation plan, and one adversarial review over the whole
design set.

Skip this entire command only for a trivial bugfix (all acceptance criteria
clear; no API, schema, auth, permission, concurrency, migration, dependency,
persistence, or external-service behavior changes; touches one or two files;
no new public contract).

If the user supplies an issue number, read it with `gh issue view <issue-number>
--json title,body,labels` for requirements and acceptance criteria.
Otherwise, work from the session context or ask the user what to design.

If you are running as part of a larger workflow (e.g. `$quest`),
`BASE_BRANCH` and guardrail commands should already be recorded from
`$attunement`. If running standalone, discover them first: read `AGENTS.md` /
`CLAUDE.md`, find the default branch (`gh repo view --json defaultBranchRef`),
and identify the repo's check suite.

**Caller contract.** If invoked inside `$quest`, completing this step
means proceed to the next step — do not end your turn. Stop only on a genuine
blocker you have named.

## External scope authority

Use a complete caller-supplied charter unchanged. It contains `interaction`, `scope
identity`, `outcome`, `completion criteria`, `provenance`, `exclusions`, `surface`, and
`ambiguities`. A reviewed or generated artifact is never a substitute for a missing field.

An interactive direct invocation freezes its quoted request into all eight fields.
An unattended direct invocation without a complete charter parks before design.

For a direct human invocation, establish `interaction: interactive`. Before freezing, ask
one question at a time about any omission or conflict that could change a charter field or
normative guarantee. Record the quoted request, answers, and their provenance; use an
explicit empty value when no exclusion or ambiguity exists. An unattended caller must
supply every field. Missing, incomplete, or unresolvable input returns `SCOPE CHECKPOINT`
or parks and never derives authority from a spec, ADR, or plan.

A normative guarantee is a promise that downstream implementation or review must preserve.
Each guarantee must cite a frozen requirement, a later explicit user decision, or a
necessary consequence.

An explicit user decision may authorize a guarantee only when provenance records it.

No reasonable implementation can satisfy the sourced completion criterion without it.

Treat that sentence as the boundary for a necessary consequence. Contestable necessity
returns `SCOPE CHECKPOINT`; review cannot settle it by adding a promise.

High-risk examples begin with transactions, persistence, concurrency, and recovery.
Migrations and new public contracts are also high-risk examples. An explicit sourced
request can authorize any of them; the list is not a blanket ban.

## 1. Council — dialogue to spec + ADR

The charter frozen in *External scope authority* governs this phase and every
phase below it; it is not re-frozen or handed on between them. Only that frozen
charter and its provenance satisfy a dispatched approval gate. The issue body
stays evidence used while freezing the charter, never a second live authority.

Read the project first — files, docs, recent commits. A wrong premise is
cheapest to correct before the first question rather than after the design.

Then check size before detail. A request spanning several independent
subsystems gets decomposed, not refined: name the independent pieces, say how
they relate and what order they should be built in, then take the first one
through this phase alone. Each sub-project earns its own spec, plan, and
implementation cycle. Spending the whole dialogue on the details of a project
that needed splitting is the expensive mistake at this stage.

For a request already the right size, refine it by asking. **One question per
message** — a message carrying three questions comes back with one answer.
Prefer a closed set of options wherever the choice really is closed: it is
easier to answer, and assembling the options forces you to have considered
them. Aim the questions at purpose, constraints, and what success looks like.

Once the space is clear, put up **two or three approaches** with their
trade-offs, recommendation first and the reasoning beside it. Then present the
design in sections, each scaled to its own complexity — a sentence where it is
obvious, a few hundred words where it is genuinely nuanced — confirming each
before moving to the next. A design rejected whole at the end wastes the
sections that were right.

Cover architecture, components, data flow, error handling, and testing. Design
for isolation: every unit has one purpose, a stated interface, and can be
understood and tested by itself. If you cannot say what a unit does without
reading its internals, or cannot change those internals without breaking its
callers, the boundary is in the wrong place. In an existing codebase, follow
the patterns already there and fold in targeted improvements to the code this
change actually touches — and propose no unrelated refactoring.

Cut ruthlessly while the design is still cheap to cut. A feature nobody asked
for costs the same to maintain as one somebody did.

**No design, no implementation.** Do not write code, scaffold a project, or
take any other implementation action until a design has been presented and
approved. This holds for every change regardless of how simple it looks;
"simple" is where unexamined assumptions survive longest. What scales down to a
small change is the design's *length* — a few sentences is a complete design
when the change is genuinely small. Skipping it is not.

Write or update the design doc under `docs/workflow/specs/`, named
`YYYY-MM-DD-<topic>-design.md`. For decisions with viable alternatives — layer
boundaries, interface or ownership splits, concurrency invariants, failure
contracts, migration sequencing, rollback strategy — write or update an ADR
under `docs/adr/` with:

- Status
- Context
- Decision
- Consequences
- Considered & rejected

That list selects on the **kind** of decision, never its size, and it stays that
way: a decision with viable alternatives earns a record even when it is small,
because a decision with no record is worse than a record that is too long. Never
skip the ADR to keep it short — what scales to the decision is the record's length.

Size the record to what the decision governs, not to how much could be said about
it. The five sections above are the whole of it: enough context that a reader knows
why the question arose, the decision, the consequences that reader would otherwise
discover the hard way, and each rejected alternative with the sentence or two that
sank it. A 57-line record can settle the shape of an entire command; that is the
norm, not a terse outlier. A record running longer than the artifact it
governs has stopped recording the decision and started defending it; a 514-line ADR
over a 19-line state machine is the failure this bounds. State the decision and stop.

Every `Considered & rejected` bullet names its alternative, then opens the ground that
sank it with one of two tags saying how that ground was established:

- **`verified:`** — a factual ground. It carries the command run and what that command
  produced, plus the environment wherever the result could depend on it — a commit, a
  released version, a platform — named so a later reader can return to it, since "this
  branch" is gone after the merge and the record is not. Where the ground is factual but
  no command settles it, `verified:` carries the source that does.
- **`judgment:`** — complexity, fit, taste, or cost. It carries no evidence; the token is
  the obligation, and naming which of the four applies is optional.

Both are legitimate grounds. A judgment presented as a fact is not. The tag classes the
ground, so it does not exempt a factual premise sitting inside that ground: a `judgment:`
resting on an unrun behaviour claim is the same defect wearing the other label. Where an
alternative is sunk by both a measured fact and a judgment, lead with `verified:` — the
factual half is the half that owes evidence.

What the tag replaces is the paragraph of justification behind the ground, never the
sentence or two that states the ground. A tagged bullet reads

- **Configure the hooks path globally.** verified: `prek install` refuses and exits 2
  under a global `core.hooksPath` (prek 0.4.13, macOS).
- **Keep a second index of the records.** judgment: a merge-conflict surface for a lookup
  nothing performs.

in place of the reasoning it summarises. A rejected alternative is a road nobody drives,
so nobody re-tests the reason it was rejected; the tag is what tells a later reader which
grounds were checked.

Use the orchestrator-assigned ADR number if you were given one (from
`$attunement` step 7); otherwise take the next free number. Link the ADR from
the spec. Run the relevant doc guardrails and commit the spec/ADR.

### Spec self-review

Before the design review in step 3, read the spec back with fresh eyes and fix
what you find inline:

- **Placeholders** — "TBD", "TODO", an unfinished section, a requirement too
  vague to fail against.
- **Internal contradiction** — sections that disagree, or an architecture that
  does not match the features described against it.
- **Scope** — is this one implementation plan's worth of work, or does it still
  need decomposing?
- **Two-way ambiguity** — any requirement a competent reader could take two
  ways. Settle it and say which reading the spec means.

This pass is cheap and catches the defects an adversarial review would otherwise
spend an iteration discovering. It does not replace step 3 — and with the plan now derived
from a spec no adversarial pass has seen, it is the cheapest place a spec defect stops.

An ADR-producing change should touch **only its own ADR file**. A hand-maintained
index table serializes parallel ADR PRs on one merge conflict — N such PRs cost
O(N²) resolutions, because git conflicts on adjacent insertions even when the
assigned numbers are disjoint. If a repo keeps such an index anyway, add your row
only on a **solo** run; on a **dispatched** run (an orchestrator handed you an ADR
number, `$attunement` step 7) write only the ADR file and report `index row pending`
in your completion report, leaving the row to the orchestrator.

**CI gating the index outranks that split**: the row is a merge
precondition there, and run type is only a convention. `$attunement` step 5 reports the
coupling verdict — and separates checks CI hard-gates **individually** from ones
reachable only through an umbrella recipe, since only the former can block a PR. Under
`$campaign` the verdict reaches you in your dispatch prompt rather than being yours to
rediscover. Where such a check enforces one index row per ADR file, the
withheld row keeps the PR red and the orchestrator's post-wave append never runs,
because the gate blocks the merge that would trigger it. Add your own single row
there, dispatched or solo, and say so in your completion report instead of reporting
`index row pending`. Match neighbouring rows in length and tone and touch no other
row — and give the row's `Status` cell the same value as the record's own `## Status`
section, since a guard that couples the two usually compares them. That agreement is
also why a supersession has to update the row in the same PR wherever changing a
record's status changes that keyword.

If the ADR supersedes an existing one, add a one-line banner to the superseded
record's `## Status` section — `> **Superseded by [NNNN](NNNN-slug.md)**
(YYYY-MM-DD)` — and leave the rest of that file untouched. That banner is the only
edit a merged ADR permits, and it is where a reviewer learns the decision no longer
governs; `$gauntlet` reads it as a decisive supersession signal.

### AI surfaces require an eval plan

If the change adds or modifies an AI surface — an LLM call, prompt or system
message, retrieval path, classifier, agent loop, tool-use chain, or model
config — the spec is incomplete without an eval plan. No eval plan, no
proceeding to implementation. (Adapted from `suede-ai-eval`,
JasonColapietro/suede-creator-skills, MIT.)

Add to the spec:

1. **AI-SPEC paragraph** — one paragraph stating: user, trigger, input,
   output, allowed sources, disallowed behavior, fallback behavior,
   latency/cost budget, and success signal. Cases written without this test
   nothing.
2. **Failure-mode map** — seed from the surface's system type, then add
   product-specific modes:

   | System type | Canonical failure dimensions |
   |---|---|
   | RAG / retrieval | context faithfulness, hallucination, answer relevance, retrieval precision, source citation |
   | Multi-agent | task decomposition, handoff correctness, goal completion, loop detection |
   | Conversational | tone, safety, instruction following, escalation accuracy |
   | Extraction / structured output | schema compliance, field accuracy, format validity |
   | Tool-using agent | safety guardrails, tool-use correctness, cost/token adherence, task completion |
   | Content generation | factual accuracy, voice, originality |
   | Code generation | correctness, safety, test pass rate, instruction following |

   Score each mode's severity: 5 = legal/financial/privacy/security or
   irreversible user harm; 4 = user-visible wrong outcome on a core workflow.
3. **Eval cases** — every severity-4/5 failure mode gets a concrete case:
   stable id, input, setup/fixtures, observable pass traits, forbidden
   traits, and a gate (block / warn / monitor). An uncovered severity-5 mode
   blocks the design. Minimum case mix: a happy path proving the intended
   value; an ambiguous input that should clarify or fall back safely; a
   forbidden claim or unsafe instruction that must be refused; stale or
   conflicting source data; a permissions/privacy boundary; an expensive or
   looping behavior with a hard cap; and a regression fixture for any real
   observed failure.
4. **Measurement per dimension** — prefer code-based checks (schema, required
   fields, thresholds) that run in CI. An LLM judge counts as evidence only
   after spot-checked agreement with a human-reviewed sample; a model grading
   its own output is not evidence.

The eval cases are acceptance criteria: `$forge` implements them as
tests alongside the feature, not after it ships.

### Security-relevant changes require a threat model

If the change is security-relevant — it moves what an untrusted actor can reach
or cause, touches authn/authz or tenancy, handles a secret, parses input it did
not produce, builds a command/query/path/URL from a non-literal, widens a
permission grant, or changes dependencies or security-relevant defaults (the
same trigger `$quest` step 6 applies to the diff, judged here on intent
because no diff exists yet) — the spec is incomplete without a threat model.

Add to the spec:

1. **Boundary inventory** — every point where data or control crosses a trust
   level in the design: what enters, from whom, under whose control. Name the
   boundaries the design *adds* and the existing ones it *widens*, separately.
2. **Actor model** — who the untrusted parties actually are for this deployment
   (anonymous internet, authenticated tenant, another service, a local operator,
   a CI job). A control is only meaningful against a named actor; "an attacker"
   is not one. State plainly where the design places its trust, because an
   unstated trust assumption is the one nobody revisits.
3. **Control per boundary** — for each boundary, the check that governs it:
   validation, authorization, bound, encoding, and what it leaks on failure. A
   boundary whose control is "the caller already checked" names that caller and
   the guarantee it makes.
4. **Explicitly out of scope** — the threats this design does not address and
   why (accepted risk, covered elsewhere, not reachable in this deployment).
   Silence reads as coverage; an omission stated is a decision, and an omission
   unstated is a gap someone finds later.

Prefer an existing control to a new one, and say which existing guardrail covers
a boundary when one does — a design that re-implements a check the platform
already enforces adds surface without adding safety.

The controls are acceptance criteria: `$forge` implements them alongside the
feature, and `$detect-evil` checks the branch against this inventory at step 5.
A boundary listed here with no control in the diff is a finding, which is the
point of writing it down first.

## Design-review scope input

`$trial-loop` is a separate skill, so the charter does cross a boundary here.
Pass all eight fields frozen in *External scope authority* — `interaction`,
`scope identity`, `outcome`, `completion criteria`, `provenance`, `exclusions`,
`surface`, `ambiguities` — unchanged, to the design review's single `$trial-loop`
call and to the scope audit that follows it. `scope identity` stays the external
one and never becomes the reviewed target.

The target remains evidence for review, never a source of authority. If a design-changing
ambiguity appears, end the current review cycle and use `SCOPE CHECKPOINT`; do not let the
reviewer resolve it by extending the target.

## Design-review depth

The single design review in step 3 runs at the depth routed under
[risk-routed review depth](../../references/review-depth.md), from the caller's assessment
where `$quest` passed one and from your own reading of the same four fields on a direct
invocation. Judge the reference's fourth condition on the change's **intent**, using the
security triggers in *Security-relevant changes require a threat model* above: no diff exists
at design time, and a design that will touch a trust boundary is security-relevant before a
line of it is written.

`iterating` runs `$trial-loop` exactly as step 3 states. `single-pass` dispatches one
reviewer pass instead, with that step's `challenge_args` and focus unchanged, and gives each
finding its single disposition; a blocking finding escalates to `$trial-loop` at its ordinary
budget under the reference's escalation rule. The design set is **one** target, so this is one
routing decision, not one per artifact — name the routed depth in the audit line step 3 asks
for.

This is where the cost the routing exists to bound actually lands, and it is where a wrong
route is cheapest to correct, because the escalation happens before any code exists.

**Count the rounds.** Start from the caller's cumulative figure — `0/0` where there is
none — pass it into the review as `prior_rounds`, and count a `single-pass` dispatch as one
round the same way, since it cost a reviewer pass whether or not a loop wrapped it. When the
phase ends, report the design-phase total in the form `$trial-loop` reports it, and hand it
to the caller: `$quest` continues the count into the branch review, and a direct invocation
is reporting to the operator who is paying for it. The figure used to be a sum across three
separate loops that no single report stated — 11 rounds under two charters before any
implementation existed, with every individual report accurate. One loop is now the whole
design phase, and the carry is what keeps the branch review's count continuous with it.

## 2. Inscribe — the implementation plan

Write the plan under `docs/workflow/plans/`, named
`YYYY-MM-DD-<feature-name>.md`, derived from the spec. Do not choose an
execution mode here: `$forge` picks that from what the plan looks like.

The spec has not been adversarially reviewed yet — step 3 reviews it together with this
plan, once, as one design. So the spec self-review above is the only pass standing between a
spec defect and a plan that inherits it, and the plan self-review at the end of this step is
where that inheritance is cheapest to catch. Neither is a shortcut past step 3.

Write for an engineer who has zero context for this codebase and whose taste you
cannot vouch for — a skilled developer who knows almost nothing about the
toolset or the problem domain, and who is not strong on test design. Everything
they need is on the page or it does not reach them. The next phase may hand each
task to a context-free implementer that cannot ask you what a step meant.

If the spec still spans several independent subsystems, say so and split it —
one plan per subsystem, each producing working, testable software on its own.

**Map the files before defining any task.** Which files get created, which get
changed, and what each is answerable for. Decomposition gets settled here
whether or not you do it deliberately, so do it deliberately instead of letting
it emerge one task at a time. Keep files focused — one clear responsibility each, split by
responsibility rather than by technical layer, with things that change together
living together. In an existing codebase, follow the patterns already there
rather than restructuring unilaterally, though a split is reasonable to plan for
a file you are modifying that has grown unwieldy.

**Right-size the tasks.** Draw the boundary where a review verdict could
plausibly differ on either side of it: if no reviewer could accept the work
before the line while rejecting the work after it, there is one task there, not
two. Setup, configuration, scaffolding and documentation are not tasks — they
belong to whichever deliverable needs them. Each task ends at something testable
on its own.

**Size the steps to one action each**, two to five minutes' work, in the order
that makes the test do the proving: write the failing test, run it and confirm
it fails, write the minimal implementation, run it and confirm it passes,
commit. The confirm-it-fails step is the one that gets skipped and the one that
establishes the test can fail at all.

Start the plan with a header carrying the goal in a sentence, the architecture
in two or three, the tech stack, and a **Global Constraints** section holding
whatever binds the project as a whole: the lowest supported versions, what may
be depended on, the rules governing names and wording, the platforms that must
work — **transcribed from the spec exactly, values and all**. A paraphrased
version floor is a wrong version floor. A version the plan introduces or
raises — a dependency, a CI action, a tool — is resolved against its registry
at authoring time, never asserted from memory; transcription then governs
carrying the resolved value forward unchanged. Pins are also checked
together: two dependencies whose versions do not resolve against each other
are a plan defect, and a lookup scoped to one package never catches it.
Every task's requirements implicitly include that section, so it is written
once instead of re-derived per task.

The header also carries one line, exactly:

    Expected implementation size: <low>–<high> changed lines (<S|M|L>) — <one clause naming what the range was derived from>

The range is a by-product of the file map and the task list you have just written, not new
analysis: count what each task creates and changes and add it up. Exclude the design
artifacts themselves — this measures the implementation the plan produces. The band is the
`$divination` complexity verdict where the caller supplied one, and your own reading of the
same three fields where it did not; a band that disagrees with your own range means one of
them is wrong, and saying which is part of writing the line. This is the denominator step 3
measures the design against, so an inflated range is a defeated control rather than a
generous one.

Give each task:

- exact file paths for what it creates, modifies, and tests
- an **Interfaces** block naming what it consumes from earlier tasks and what
  later tasks rely on from it, with exact signatures — an implementer who sees
  only their own task learns neighbouring names nowhere else
- where the task fits in the wider change
- complete code in every step that changes code
- the exact command for every verification step **and the output to expect** —
  "run the tests" cannot be checked; a named command with a stated expected
  result can
- acceptance criteria a reviewer can check
- the repo conventions and guardrail commands that bind it
- rollback or cleanup expectations where they apply

Repeat code across tasks rather than cross-referencing another task. This is the
one place DRY is deliberately not applied, and the reason is that tasks get read
out of order: "similar to Task 3" is unreadable to someone who has not read
Task 3.

Each of the following is a defect in the plan, not a matter of house style. A
plan containing one is not finished:

- a deferral marker of any kind standing in for content — `TBD`, `TODO`,
  "fill this in", "decide later"
- an instruction whose object is unnamed: handle the errors, validate the
  input, cover the edge cases. *Which* errors, and what should happen?
- an instruction to write tests, with no test written
- a cross-reference used to avoid repeating something — "as in Task 4"
- a step naming an outcome without the means to reach it
- a type, function, or signature used but defined by no task
- a type, function, or signature borrowed from the existing codebase or a
  dependency, used by tasks without being confirmed to exist there with the
  signature the plan assumes

**Then self-review the finished plan against the spec, with fresh eyes.** Walk
each spec requirement and point to the task implementing it; a requirement with
no task means adding the task. Sweep for the placeholder patterns above. Check
that the names, signatures, and properties used in later tasks match what
earlier tasks defined — a function called `clearLayers()` in Task 3 and
`clearFullLayers()` in Task 7 is a defect the implementer inherits. Ground every
name the plan borrows instead of defines: for each type, function, or signature
taken from the existing codebase or from a dependency, check the target
repository — or the dependency's registry and docs — that it exists with the
signature the plan assumes, and correct the plan inline where a name does not
resolve. Fix what you find inline.

Run relevant guardrails and commit the plan.

## 3. Adversarial-review the design

One review, over the whole design set, run once the set is complete. The ADRs, the spec, and
the plan are one change: they get one charter, one iteration budget, and one report — not
three targets reviewed in sequence, each drawing a full budget nobody was totalling. That
shape is what produced 13 review rounds and a 1,469-line design before a line of
implementation existed.

### Assemble the set

Detect the artifacts this design produced with git predicates — not your recollection of
what steps 1 and 2 wrote, which a post-compaction resume loses. The design set is the union
of:

- target-repository path: `git diff --name-only <BASE_BRANCH>...HEAD -- docs/adr/ docs/workflow/specs/ docs/workflow/plans/ ':(exclude)docs/adr/README.md'`
  — artifacts already committed on the branch, and
- target-repository path: `git status --short --untracked-files=all -- docs/adr/ docs/workflow/specs/ docs/workflow/plans/ ':(exclude)docs/adr/README.md'`
  — artifacts written but not yet committed (`--untracked-files=all` so a brand-new,
  never-staged file is seen regardless of the user's `status.showUntrackedFiles` config).

The target-repository `':(exclude)docs/adr/README.md'` pathspec drops the index — an
index-row edit is not a decision to challenge. Most designs record no ADR, so an ADR-free
set is the common case and reviews exactly the same way; there is no ADR-specific skip left
to get wrong. A set missing **the spec or the plan** is a resume that lost its own artifacts:
stop as blocked rather than reviewing whatever remains. Never invoke `$trial-loop` with a
path that does not resolve — it appends a `CHARTER` block on every invocation, and under a
charter an unresolvable target is a hard error naming the token, with `--out` suppressing
both the artifact and the compact object, so the loop returns no verdict and stops as
blocked.

### Measure the proportionality inputs

Measure them here, in the orchestrator, so the reviewer judges numbers instead of producing
them — a reviewer asked to both measure and judge will do neither reproducibly:

- `wc -l` over every path in the set, summed — the **design size**.
- the plan header's `Expected implementation size` range — the **implementation estimate**.
- the design size over the range's high end, to one decimal place — the **ratio**.

**Echo an audit line before proceeding**, so a mis-evaluated predicate or an unmeasured
ratio leaves an inspectable trace rather than silently reopening the shield (the repo's only
verification is reading the transcript):

    design review: set = <paths>; design <n> lines vs implementation estimate <low>–<high>; ratio <n.n>x; depth = iterating | single-pass

A plan carrying no `Expected implementation size` line is a step 2 defect: derive the range
from the plan's own file map and task list, write it into the plan, and say in the audit
line that you did.

### Run the review

Run `$trial-loop` in file-list mode:

- challenge_args: `<every path in the design set, space-separated>`
- focus: `This is one design reviewed as one artifact set — ADR(s), specification, and
  implementation plan. Read them together and challenge them together: a defect that
  crosses files is one finding, not one per file, and a spec defect the plan inherited is
  reported once against both.

  Decisions (each ADR in the set): the soundness of the decision under its stated context;
  the completeness and honesty of the "Considered & rejected" list — alternatives dismissed
  too quickly, or not considered at all, including the null "do nothing" option; unstated or
  understated consequences and residuals; and whether a simpler decision would meet the same
  context. Evidence class is in scope: a rejection whose ground is stated as fact but
  carries no command, result, or source is a finding, as is a claim about a rejected
  alternative's behaviour that you cannot reproduce from what the bullet states — whichever
  tag precedes it, since a judgment resting on an unrun behaviour claim is the same defect
  relabelled. The command and result a factual ground carries are the ground, not argument,
  so the size clause below does not ask for them to be cut. A record carrying no tags at all
  either predates this contract or ignores it wholesale: report that once rather than filing
  a finding per bullet. The ADRs in this set are review targets, not settled ground —
  challenge their decisions on the merits. An ADR the spec merely links to, and that is not
  in this set, stays settled unless the spec or plan contradicts it or introduces a new
  risk.

  Specification: hidden assumptions, vague or unfalsifiable success criteria, missing edge
  cases, and under-specified failure modes. If the spec covers an AI surface, also challenge
  the eval plan: failure modes without cases, unmeasurable pass traits, and uncalibrated
  LLM-judge evidence.

  Plan: phase ordering, missing prerequisites, steps that cannot run in the claimed order,
  rollback and cleanup paths, verification gaps, ungrounded references — a type, function,
  or signature borrowed from the codebase or a dependency without confirmation it exists
  with the assumed signature — and tasks that are not self-contained enough for an
  implementer. This plan was derived from a spec no adversarial pass had seen, so check it
  back against the spec in this same set: a spec requirement with no task, and a task
  serving no requirement, are both findings.

  Proportionality, over the whole set: the orchestrator measured <design size> lines of
  design against an expected implementation of <low>–<high> changed lines, a ratio of
  <n.n>x. Above 3x is a blocking finding; 2x to 3x is a note. The remedy is cutting the
  design — never adding text to defend its length, and never widening the estimate to move
  the ratio. Judge the estimate too: a range the plan's own file map and task list do not
  support is a finding in its own right, and the honest range is the one the file map
  yields. Size is in scope per artifact as well as in aggregate — a record arguing for its
  decision at greater length than the decision governs is a finding, and its remedy is also
  cutting.`

### Exits

If the loop reports blocked — including cap exhaustion at its iteration budget — stop as
blocked per `$trial-loop`'s stop contract. The design does not go on to the scope audit.

*sound with record notes*, *converged with deferrals*, and *converged on own surface* are
**not** that case. All three are terminal non-blocking exits, and the phase continues on
any of them. `$trial-loop` reports the exit by name and owns the condition each one fires
on; this step does not re-derive them. Route on that name rather than on the last verdict,
which on a named exit is ordinarily `needs-attention` and never by itself means the design
is unhardened.

Editing an ADR in the set to address a finding is legitimate — it is pre-merge on the design
branch, and the immutability rule applies only once the ADR is merged.

Carry every deferral — each entry with its owning record path or tracker issue — into the
**plan**, whichever way the run ended, `approve` included. The loop discloses its deferrals
on every exit, and the plan is what `$forge` reads, so that is where a later implementer
meets them. Not the ADR: it merges append-only, and an entry there cannot be struck when its
tracker closes.

## 4. Scope audit

The design phase ends with exactly one `$oathbind` pass over the reviewed set. This skill
does not invoke it: `$quest` step 4 owns the report path, the `.agent/` ignore check, and
the dispatch, and it runs immediately after this review. A direct invocation of this skill
runs no audit; an operator who wants one invokes `$oathbind` themselves, with the same
frozen charter and the paths this review just hardened.

One pass is the whole of it, and that is a property of what the audit can produce rather
than a budget imposed on it. `$oathbind` is read-only and audits authority, so every remedy
it can legitimately yield is a cut, a split, or a `SCOPE CHECKPOINT` back to the operator —
and a cut cannot invalidate an audit that already approved the larger surface. An edit that
would *widen* the surface is not a responsive remedy in the first place; it is a checkpoint.
Re-auditing after an edit the audit itself asked for is the second pass this removes.

## Context checkpoint

The spec, ADR, and plan you just wrote are the **durable artifacts** of this
phase — they, not the brainstorm transcript or the review payloads, are what a
downstream build (or a post-compaction resume) reads. Before handing off, ensure
the checkable facts a resume needs — the branch name, `BASE_BRANCH`, and the
guardrail commands — are recorded somewhere durable, and, as a reminder, that the
spec/ADR/plan hold every design decision. Do **not** run `context compaction` proactively;
just keep the artifacts complete.
