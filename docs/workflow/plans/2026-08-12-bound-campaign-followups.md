# Implementation plan: bound campaign follow-up growth

**Goal.** Teach campaign to close confirmed low-value defects and require consent before
follow-up expansion, while bounty consolidates fourth-plus recurring defects and preserves
occurrences beside open sweeps.

**Architecture.** This is an instruction-only contract change in the existing campaign and
bounty skills. Bounty owns all-state recurrence discovery and confirmed issue creation;
campaign owns triage routing, manifest state, follow-up admission, and final reporting. No
script, dependency, label taxonomy, or prose-sensitive automated test is added.

**Tech stack.** Markdown skill contracts, GitHub CLI examples, `just verify`.

**Design:** `docs/workflow/specs/2026-08-12-bound-campaign-followups-design.md`.
**Decision:** `docs/adr/0008-bound-campaign-follow-up-growth.md`.

## Global constraints

- Skills remain instruction-only Markdown; no supporting executable is added.
- The only implementation files are `skills/campaign/SKILL.md` and
  `skills/bounty/SKILL.md`.
- GitHub reads use explicit JSON fields and bounded lists as required by repository policy.
- Historical issues are read-only during recurrence discovery.
- `just verify` is the guardrail suite; CI invokes the same chain as `just ci`.
- `BASE_BRANCH` is `main`; branch is `feat/bound-campaign-followups-91`.
- Host architecture is `arm64`; no target architecture is declared, so the relationship is
  `no-target-declared`.

## File map

| File | Responsibility |
|---|---|
| `skills/bounty/SKILL.md` | Defect-class discovery, threshold routing, sweep lifecycle, confirmation freshness, occurrence creation/closure handoff |
| `skills/campaign/SKILL.md` | Cost/benefit triage, not-planned closure, follow-up confirmation, manifest/final-report disclosure |

## Pre-implementation scope check

Before Task 1, run `git branch --show-current` and `git status --short --untracked-files=all`.
Require branch `feat/bound-campaign-followups-91`; stop before edits if branch setup differs or
the tree contains changes not owned by this quest. Then read issue #91's latest complete `WORK:SCOPE` block with the bounded `gh issue
view --json comments --jq` command in Task 3 Step 3.1. Verify token
`68863689-6849-47C1-B56D-41C43F790D66-v7`. A missing or different token stops before any
implementation edit. Task 3 repeats this as a final drift check.

## Task 1 — Bounty recurrence and occurrence lifecycle

**Files:** modify `skills/bounty/SKILL.md`.

**Interfaces:** consumes an evidenced proposed defect and existing repository/GitHub context.
Returns the existing verified issue URL for ordinary creation, a verified consolidated-sweep
URL for fourth-plus routing, or—when an open sweep exists—a tuple of occurrence issue number,
sweep number, not-planned rationale, and actual close state for campaign. Campaign Task 2
consumes that tuple.

### Step 1.1 — Establish the failing behavioral review

Against the unchanged bounty skill, run a fresh no-tools simulation using the exact prompt and
fixed packets E1–E5, E7, E9–E14 from the design specification. Capture JSON in the ignored
`.agent/evals/issue-91-before.md` scratch artifact.

Expected: at least E1, E4, E9, E10, E12, E13, and E14 fail because the current skill has only
title/token near-match deduplication and no recurrence or stale-confirmation contract. This is
the red proof; do not edit the skill before recording it.

### Step 1.2 — Replace the dedup step with the complete bounded recurrence contract

Edit Step 3, **Dedup gate**, keeping its existing all-state near-match behavior as the
below-threshold path. Add:

- separate all-state `gh search issues --repo <owner/name> <dimension> --json
  number,title,state,body,url --limit 100` searches for evidenced mechanism/idiom, component/file
  family, and governing accepted decision when present;
- exact saturation semantics: 100 results cannot prove below-threshold but may proceed after
  three historical occurrences are already verified; any query or linked-issue read failure
  stops filing regardless of how many occurrences were otherwise verified;
- direct linked-issue traversal from matched sweeps, deduplicated and capped at 100, with the
  same saturation semantics;
- tuple verification requiring all applicable dimensions, candidate/uncertain presentation,
  and distinct-occurrence counting that excludes sweep wrappers;
- three verified historical occurrences plus the proposal trigger fourth-plus routing.

Below threshold, retain the existing near-match offer. At threshold, search for an open sweep;
reuse it rather than draft another. With only a closed sweep, require post-closure observation
or evidence outside the prior fix before drafting a sequential sweep.

### Step 1.3 — Define drafts, confirmation freshness, and partial failure

Extend Steps 4 and 6 so a new sweep draft preserves the current source, trigger, and evidence
and cites verified history. When an open sweep exists, substitute a complete occurrence draft
linking it. The existing confirmation applies to the exact shown draft only.

Immediately before any write, repeat the matching-open-sweep read. A changed draft kind or
target invalidates confirmation: show the complete replacement and require fresh confirmation.
If the target closes with no replacement, write nothing and restart closed-sweep recurrence
evaluation. After confirmed occurrence creation, close it with
`gh issue close <N> --reason "not planned"`; verify state with
`gh issue view <N> --json state,stateReason,url`. If closure fails or readback is not closed/not
planned, return the actual open state and stop; never claim success.
If the readback command fails, return `state: unknown/unverified`, stop, and forbid a successful
closure outcome until a later read verifies closed/not planned.

Update Hard constraints: discovery never mutates historical issues; only the confirmed new
issue may be created and closed; every changed draft needs renewed confirmation.

### Step 1.4 — Re-run focused behavioral review and structural checks

Run the same bounty packets from Step 1.1 and capture
`.agent/evals/issue-91-bounty-after.md`.

Expected: all bounty cases pass with exact supplied evidence preserved; E4/E14 stop without
writes; E12/E13 request renewed confirmation and make no write after decline. Repeat E4 with
three verified historical occurrences plus one linked-issue read failure; expected is still a
stop with no draft or write, distinguishing degraded reads from saturated successful results.

Run `just shape-check`, `just public-safety`, and `git diff --check`.

Expected: all exit 0; shape check reports every skill rule passing.

Commit explicit path `skills/bounty/SKILL.md` with:
`feat: consolidate recurring defect reports`.

## Task 2 — Campaign cost/benefit and expansion control

**Files:** modify `skills/campaign/SKILL.md`.

**Interfaces:** consumes bounty's closed-occurrence tuple. Emits manifest outcomes and final
rows using `closed-not-planned: occurrence of sweep #N`. Existing quest dispatch remains
unchanged for `fix`.

### Step 2.1 — Establish the failing campaign behavior

Run the spec's no-tools simulation for E6, E8, E10, and E11 against current campaign plus the
Task 1 bounty contract. Capture `.agent/evals/issue-91-campaign-before.md`.

Expected: E6 and E8 fail because campaign lacks follow-up consent and `close-not-planned`; E10
and E11 fail because campaign cannot record the occurrence handoff or distinguish failed close.

### Step 2.2 — Extend triage and planning

In Step 3, add `close-not-planned` beside `close-candidate` and `fix`. Require citations,
concrete trigger, likely impact, remediation/quest cost, cost/benefit rationale, and observable
reconsideration condition. Uncertain correctness remains `fix`; uncertain cost/benefit stays
visible for operator decision.

In Step 4, show the verdict in the plan. After display, post its rationale and require that
comment write to succeed before attempting closure. A failed comment leaves the issue open and
is a live issue-local blocker. Only after a successful comment, close with
`gh issue close <N> --reason "not planned"`, verify `state,stateReason`, and record
`closed-not-planned`. A failed close is likewise a live issue-local blocker, not a closed
outcome; the already-posted rationale remains accurate evidence of the attempted disposition.
If close returns success but the `state,stateReason` read fails, record unknown/unverified state
and block; a successful close command alone never proves `closed-not-planned`.

Extend manifest recognized terminal outcomes and the final outcome vocabulary without adding a
new queue status or label.

### Step 2.3 — Gate re-enqueue and surface occurrence closures

Replace Step 7's unconditional loop with a proposal table containing issue number, title,
source issue, proposed route, and consolidation. Ask once for explicit confirmation before any
manifest insertion. Decline leaves the issues filed but outside this campaign and proceeds to
drained-state evaluation.

When bounty returns a closed occurrence beside an open sweep, append its number, sweep number,
and rationale to Outcomes log. The final Step 8 table always shows
`closed-not-planned: occurrence of sweep #N`. If the occurrence is still open, report its real
state and keep the follow-up blocked; never emit the closed row or finish the campaign.

### Step 2.4 — Run focused behavioral review and guardrails

Dispatch all fixed simulations E1–E24 to a fresh reviewer context with tools disabled, distinct
from the implementing context, and capture the complete prompts, packets, JSON, model identifier
or `unavailable`, human pass/fail comparison, and instruction line citations at
`.agent/evals/issue-91-final.md` exactly as the specification requires.

Expected: every blocking case passes. Specifically E6 declines with no manifest mutation, E8
closes not planned without claiming fixed, E10 produces the final report row, and E11 stops on
the actual open occurrence. Add a focused E8 fault injection in the same scratch transcript:
the rationale comment returns `permission denied`; expected is no close attempt, actual open
state, and a blocked outcome rather than `closed-not-planned`. Add two more E8 variants: (1)
the rationale succeeds but `gh issue close` returns `permission denied`; (2) comment and close
return success but readback reports an open issue or a closed reason other than not planned.
Both must report the actual state, produce a blocked outcome, and forbid
`closed-not-planned`. Add a third variant where close succeeds but
`gh issue view --json state,stateReason,url` fails; expected is unknown/unverified state, a
blocked outcome, no terminal row, and no campaign completion. Mirror this readback-failure
variant for bounty's open-sweep occurrence closure.

Run `just verify` bare.

Expected: exit 0 with records, lint, formatting, public-safety, shape, ripgrep configuration,
plugin validation, all shell suites, Actions checks, and prek dry-run green; only the documented
plugin version warning is permitted.

Commit explicit path `skills/campaign/SKILL.md` with:
`feat: bound campaign follow-up expansion`.

## Task 3 — Whole-change verification

**Files:** no planned edits; accepted implementation-review fixes may change only
`skills/campaign/SKILL.md` and `skills/bounty/SKILL.md`. A finding against the approved spec or
accepted ADR stops implementation for a new design-review or supersession decision; it does not
authorize editing the frozen baseline inline.

**Interfaces:** consumes both completed task contracts and produces branch-review evidence.

### Step 3.1 — Trace every requirement

Read the latest complete `WORK:SCOPE` block on issue #91 with:
`gh issue view 91 --json comments --jq '[.comments[].body | select(test("(?m)^<!-- WORK:SCOPE -->$") and test("(?m)^<!-- SCOPE:COMPLETE -->$"))] | last'`.
Verify it contains scope token `68863689-6849-47C1-B56D-41C43F790D66-v7`, then read ADR 0008
and the specification traceability table. Map each criterion to exact lines in campaign/bounty
and each E1–E24 row in the final eval artifact. A missing or different latest token stops the
task for scope reconciliation.

Expected: no unmapped criterion, no implementation file outside the frozen surface, and no
unexplained divergence from the ADR.

### Step 3.2 — Run the full guardrail suite

First run an independent adversarial whole-diff review against `main`, focused on contract
contradictions, missing failure edges, consent boundaries, evidence loss, recurrence counting,
and divergence from ADR 0008 and the approved surface. Disposition every finding. For each
accepted fix, edit only the two skill files, commit that fix separately, rerun the affected
E1–E24 simulations with a fresh reviewer, and repeat whole-diff review until approved or the
review cap stops the task.

After every accepted review fix, replace—not append beside—the affected case entries in
`.agent/evals/issue-91-final.md` with complete prompts, packets, current JSON, comparison, and
line citations from the fixed HEAD. After whole-diff approval, repeat Step 3.1's complete
requirement-to-current-line mapping and verify every E1–E24 entry describes HEAD before running
the final gates.

After review approval, run `just verify` bare, then `git diff --check` and
`git status --short`.

Expected: all gates exit 0; status contains no untracked or modified file except intentional
review fixes not yet committed. Commit any accepted review fix separately before continuing.

### Step 3.3 — Rollback and cleanup expectations

This change is instruction-only and reverts with its commits. Do not commit `.agent/evals/` or
review JSON. If a live manual verification creates a GitHub fixture contrary to the no-tools
protocol, stop and report it; do not delete an issue to conceal the write.
