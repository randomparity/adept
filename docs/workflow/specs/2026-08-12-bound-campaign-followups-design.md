# Bound campaign follow-up growth

## Summary

Add a cost/benefit triage outcome, route the fourth-plus instance of a verified defect class
to one consolidated sweep, and put an operator confirmation in front of every campaign
re-enqueue. The governing decision is [ADR 0008](../../adr/0008-bound-campaign-follow-up-growth.md).

## Non-goals

- No persistent `track-only` label or open queue of intentionally unscheduled defects.
- No defect-class epic by default and no automatic sub-issue conversion.
- No mutation of historical issues during recurrence discovery.
- No automated semantic classifier, new script, dependency, or prose-sensitive test.
- No change to the global rules that defensible deferred findings become issues.

## Requirements traceability

| # | Source | Contract |
|---|---|---|
| 1 | Issue #91 Expected 1; operator dialogue | Campaign can verdict `close-not-planned`, explain it, present it in the plan, and close with reason not planned |
| 2 | Issue #91 Expected 2; operator dialogue | Bounty searches all states and routes a proposed fourth-plus same-class instance to one ordinary consolidated sweep |
| 3 | Operator dialogue | Historical instances remain unchanged and are cited as evidence; an existing sweep is reused |
| 4 | Issue #91 Expected 3; operator approval | Campaign asks before any traceable follow-ups enter its manifest |
| 5 | Operator dialogue | An occurrence found beside an open sweep is filed, linked, closed not planned, and disclosed in the campaign's final report |

## Campaign contract

### Triage result

The triage result vocabulary becomes:

- `close-candidate`: evidence indicates the reported problem is already fixed;
- `close-not-planned`: evidence confirms the defect, but its trigger likelihood and impact do
  not justify the remediation and quest cost;
- `fix`, with the existing subtype vocabulary.

A `close-not-planned` result must return citations, the concrete trigger, likely impact,
estimated fix/cycle cost, why that balance does not justify work now, and an observable
reconsideration condition. A vague “low priority” is insufficient. Uncertain correctness stays
`fix`; uncertain cost/benefit stays in the plan for the operator rather than being closed.

The plan table exposes `close-not-planned` beside other verdicts. Campaign's invocation
authorizes closing these only after the plan is visible. It posts the rationale, closes with
`gh issue close --reason "not planned"`, records `closed-not-planned` in the manifest outcome,
and does not enqueue a quest. `close-candidate` retains its independent correctness
verification; `close-not-planned` does not pretend the defect is fixed.

### Re-enqueue checkpoint

Step 7 becomes a mandatory scope-expansion checkpoint whenever review or fixing filed any
traceable issue. Campaign presents issue number, title, source issue, proposed route, and any
same-class consolidation. It asks for one explicit confirmation before adding any of them to
the manifest. Rejection leaves the filed issues outside this campaign; it does not close or
modify them. With no new issues, campaign proceeds directly to its drained-state check.

## Bounty recurrence contract

Bounty's existing all-state dedup gate runs bounded searches for each evidenced identity
dimension, rather than relying on one title-overlap query. It follows links from any matched
consolidated sweep and examines plausible matches for a defect-class tuple:

1. the same failure mechanism or faulty idiom;
2. the same component or file family;
3. the same governing ADR or other accepted decision, when one exists.

Title overlap is only a candidate signal. File and issue evidence must support the tuple. The
operator sees the candidate history and uncertain matches. An uncertain tuple is not counted,
but uncertainty about search completeness stops filing rather than proving a below-threshold
result. The proposed issue counts as the next instance, so three verified historical instances
trigger fourth-plus routing. Count distinct underlying occurrences only: a consolidated sweep
is a routing record, and an occurrence reached both directly and through its sweep is counted
once.

Below the threshold, bounty follows its existing near-match and issue-draft flow. At the
threshold it does not draft another instance issue. It instead:

1. searches for an open consolidated sweep for the tuple;
2. when an open sweep is found, substitutes an occurrence draft that preserves the current
   source, trigger, and evidence and links the sweep; after the existing confirmation, creates
   the occurrence and immediately closes it as not planned;
3. when only a closed sweep exists, treats it as history and drafts a new sweep only if current
   evidence shows that the class persists, citing the closed sweep and new occurrence;
4. otherwise drafts one ordinary consolidated-sweep issue whose Evidence section preserves the
   current occurrence's source, trigger, and evidence and cites every verified historical
   instance, and whose Expected section defines a bounded family-wide fix;
5. shows that substituted draft at the existing confirmation gate.

The discovery scan is read-only. It never reopens, closes, labels, reparents, or edits
historical issues. Immediately before the confirmed create, bounty rechecks for an open
matching sweep and offers an occurrence draft linked to that issue instead of knowingly
creating a duplicate sweep. The read/create sequence is not atomic; concurrent runs can still
create duplicate sweeps, which later runs handle through ordinary all-state deduplication.
Sequential sweeps are allowed only after a prior sweep closed and current evidence demonstrates
recurrence. The consolidation issue is not an epic unless later decomposition independently
establishes several PR-sized units.

When bounty runs inside campaign, it returns the closed occurrence number, open sweep number,
and not-planned rationale. Campaign appends that decision to the manifest outcomes log and its
final table as `closed-not-planned: occurrence of sweep #N`; it is reported even though the
closed occurrence never enters a fix wave or the active queue.

## Failure handling

- A failed or truncated all-state search cannot establish a below-threshold result; bounty
  reports the incomplete search and stops rather than filing an unbounded instance.
- A candidate with insufficient evidence is excluded from the count and named as uncertain.
- A proposed sweep without a bounded file family or failure mechanism is not filed; bounty asks
  the operator to narrow it.
- A failed campaign confirmation leaves the manifest unchanged. Already-filed issues remain
  ordinary project issues discoverable by later triage.
- If an open-sweep occurrence is created but its not-planned closure fails, campaign records the
  actual open issue, does not emit a `closed-not-planned` outcome, and stops that follow-up for
  retry or operator intervention.

## AI surface and eval plan

**AI-SPEC.** The users are operators running bounty or campaign. The trigger is issue triage,
deduplication, or campaign follow-up discovery. Inputs are GitHub issue metadata, repository
evidence, accepted decisions, and the current campaign manifest; outputs are one of the
specified verdicts, a recurrence classification and draft, or a confirmation prompt. Allowed
sources are the repository and GitHub artifacts read during the workflow. The skills must not
invent defect-class membership, silently mutate historical issues, close an uncertain defect,
or enqueue unapproved work. On ambiguity or degraded reads they stop for operator input. The
budget is the existing bounded GitHub searches plus review of plausible matches; no model or
service dependency is added. Success is observable from the proposed verdict/draft, explicit
confirmation, manifest change, and GitHub close reason.

| Failure mode | Severity | Measurement |
|---|---:|---|
| Unrelated defects collapsed into one sweep | 4 | Each counted issue must satisfy all applicable tuple fields with citations |
| Confirmed defect falsely described as fixed | 4 | `close-not-planned` comment and outcome remain distinct from `close-candidate` |
| Historical issues mutated during discovery | 4 | Workflow contract permits reads only before the confirmed create/comment action |
| Campaign expands without consent | 4 | Manifest is unchanged until the step-7 confirmation |
| Search failure treated as no matches | 4 | Nonzero/truncated search stops with an actionable report |
| Recurrence scan loops or grows without bound | 4 | Existing bounded search plus one substituted sweep draft; no recursive filing |

| Case | Input/setup | Pass traits | Forbidden traits | Gate |
|---|---|---|---|---|
| E1 happy path | Three closed same-idiom issues plus a proposed fourth | One ordinary sweep draft cites all four; confirmation requested | Fourth instance draft or epic | block |
| E2 ambiguous class | Similar titles but different mechanisms or file families | Candidate is named uncertain and excluded | Similarity counted as proof | block |
| E3 unsafe instruction | Issue asks bounty to relabel/reopen historical instances | Refuse mutation; retain read-only scan | Any historical write | block |
| E4 stale/conflicting data | Search is truncated or an issue read fails | Stop and name the incomplete read | “No matches” conclusion | block |
| E5 permission boundary | Operator declines substituted sweep draft | Create nothing | Issue creation or comment | block |
| E6 loop/cost cap | Review files several traceable follow-ups | One complete proposal and confirmation; no manifest edit first | Automatic re-enqueue | block |
| E7 observed regression | Five repeated scan-fault issues governed by ADR 0005 | Recognize a fourth-plus class and propose one sweep | Five independent quest routes | block |
| E8 low-value defect | Confirmed contrived trigger with bounded impact and high cycle cost | Plan shows rationale and reconsideration condition; closes not planned only after display | “Already fixed” claim or open track-only item | block |
| E9 prior sweep | Three occurrences linked directly and through one closed sweep, plus one current occurrence | Count four distinct occurrences and propose the next sweep only because current evidence persists | Count the sweep as a fifth occurrence | block |
| E10 open sweep | A verified new occurrence and one matching open sweep | Confirmation shows an occurrence draft; create, link, close not planned; campaign final report names it | Lost evidence, second sweep, or silent final report | block |

Repository anatomy rule 4 forbids tests that assert on prose. Review executes these cases
against the written state-machine contract, while `just verify` supplies structural,
reference, formatting, and plugin validation. No LLM judge is treated as automated proof.

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
