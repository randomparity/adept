# 0029 — A budget stop resumes on explicit operator approval

## Status

Accepted (2026-08-21)

Amends [0021](0021-review-summary-names-the-trial-loop-exit.md)'s hold on
`blocked-at-budget`: the amendment is stated here and in one corrected sentence of that
record, which keeps its accepted status — the field-set decision stands in full, exactly as
[0028](0028-review-exit-payloads-get-a-writable-slot.md) amended 0021's
payload-destination ruling without retiring it.

## Context

`$trial-loop`'s cap bullet (`skills/trial-loop/SKILL.md:654-657`) stops as blocked when the
final budgeted iteration still returns `needs-attention`, and forbids continuing to the next
workflow step **without explicit user approval** — so an approved continuation is a
permitted outcome of the loop. `$quest` step 6 invokes the loop and inherits that contract,
but documents no resume: its park protocol takes an unresolvable review state to
`status:needs-human` and stops there. Nothing says what an operator's approval does —
whether the label is swapped back, what the `WORK:TRAJECTORY` note records, or which step
the run re-enters at.

ADR 0021 reserved `exit: blocked-at-budget` for exactly this run but held it unwritable
until `$quest` documented the path. PR #160 (issue #141) hit the gap end to end: the run
stopped at the budget, parked, continued on explicit human approval, finished green and
mergeable — and published no six-field summary, because no `exit:` value was writable and
no reviewer had returned `approve`. Issue #151's second comment adds two requirements: the
continued run's summary must say how the run ended given its two endings (the budget stop
and whatever followed), and it must say whether the withheld summary stays withheld, is
written once at the end, or is written per run.

The pieces this record composes with are all in place: ADR 0021 fixes the five `exit:`
values and the rule that the fields describe the **last** `$trial-loop` run on the branch;
the same record's Consequences fix that a step 6/7 re-entry that *is* a full loop run
replaces all four run-derived fields together; ADR 0028 makes the publication sequence
writable for any run that reaches step 8; and `$trial-loop`'s caller contract already rules
that a budget-stopped run does not re-enter the loop.

## Decision

**`$quest` documents an approved-continuation resume path, and `blocked-at-budget`
becomes writable for the runs that take it.** Five rulings:

**1. Approval is an explicit human decision, attributable and directed.** It must come from
a person with authority over the run — the operator who received the park — name the parked
run unambiguously (issue, branch, or PR), and direct continuing past the budget stop. It
reaches the run as an interactive reply in the resuming turn, a durable record on the issue
or PR, or an explicit term of the dispatch that resumes the work. Silence, absence, a
generic "keep going" from another agent, or a workflow promoting itself is not approval.
This is the same authority `$trial-loop`'s cap bullet already demands; the record defines
its form, not a new permission.

**2. The resume produces a recorded transition, in that order:** post a fresh complete
`WORK:TRAJECTORY` noting the approval — who approved, where the approval is recorded, and
what it authorized — then swap `status:needs-human` → `status:in-review` in a single-active
edit. Recording before the label swap is the same exit-edges discipline the park itself
follows: an issue never sits in a flight state without a record of how it got there.

**3. The run re-enters at step 7 (Simplify), after discharging what the stop cut
short.** The cap bullet authorizes continuing *to the next workflow step*; the loop ended
at its stop, and `$trial-loop`'s caller contract already forbids a budget-stopped run from
re-entering the loop. A budget stop can leave step-6 obligations unrun — the security pass
above all, since `$detect-evil` runs after the loop's fixes and a stopped run has had no
fixes-pass boundary to trigger it — so the resumed run settles those obligations on step
6's own terms, recording `security: not triggered` where the trigger genuinely does not
fire, before simplification begins. The stopped run's final disclosure then travels as
resume facts into the payload destinations step 6 and ADR 0028 already define: the three
lists the carry contract names (deferrals with their owning records, outstanding notes,
confirmed claims) **plus the remaining-findings summary the cap bullet makes the stop
produce**. Admitting the fourth list is part of this change on both ends: the new step-6
subsection adds it to the carry instruction, and step 8's payload-composition trigger —
which today enumerates the three lists exhaustively and would compose no payload for a
run carrying only the stop's findings summary — is widened to the lists step 6 specifies.
An operator who instead wants more review passes
grants new authority to the loop itself (a new cycle under `$trial-loop`'s own rescoping
rules); that is a different continuation with a different ending, covered by ADR 0021's
replacement rule, not by this path.

**4. One ending owns the field.** `exit:` describes how the last loop run ended, and the
last loop run ended blocked at the budget: the run writes `blocked-at-budget`, with
`verdict:`, `findings:`, and `iterations:` taken from that same run. The approval is the
run's aftermath, not a second ending, so it needs no second value and none is minted —
ADR 0021 fixed the five values precisely so this change would not invent one.

**5. The summary publishes once, at step 8, through the unchanged ADR 0028 sequence.**
Withheld until then — nothing publishes at resume time, and a resumed run creates exactly
one summary. Step 8's `blocked-at-budget` bullet loses its hold clause and becomes an
ordinary writable value.

`$quest` carries the path in two places: the full sequence in step 6, beside the routing it
extends, and a one-line pointer in *On a Blocker*, because `status:needs-human` parks for
many reasons but only the `$trial-loop` budget stop has a defined resume. `$trial-loop`'s
caller-contract bullet gains one sentence pointing at `$quest`'s path, so both sides of the
caller boundary name the same contract without either restating the other's semantics.

### Amendment to 0021

0021's paragraph holding the fifth row unwritable ("`$quest` documents no such resume
today — issue #151 — so **`blocked-at-budget` may not be written until it does**, and until
then a run stopped at the budget parks and publishes no summary at all") is corrected: the
path now exists, documented by this record, and the value is writable for exactly the runs
that take it. The table's fifth row needed no edit — this record implements the row as
written, including its `verdict:` conversion (`needs-attention`) and its `blocked` routing
fact.

## Consequences

A budget-stopped, operator-approved run now ships with a machine-readable review header
naming its honest ending, closing the gap PR #160 demonstrated. The hold's removal is
self-enforcing on the writing side: the only writer that may produce `blocked-at-budget`
is a run whose park was recorded and then approved, because the path requires the
`WORK:TRAJECTORY` park record to exist first.

ADR 0028 needs no amendment to carry the fourth list: its payload slot is
content-agnostic machinery validated for byte safety, and it defers what flows through to
step 6's own specification — "write only the lists step 6 specifies" — which this change
widens at both ends.

Nothing validates the approval beyond the run's own record of it. A session that
misreads a comment as approval writes a summary claiming an approval nobody gave — the
same exposure every free-text field in the summary carries, bounded by the fact that the
parked `WORK:TRAJECTORY` and the approval record sit on the issue where a human audits
them together.

`$bards-tale`'s `blocked-at-budget` narration branch (issue #149's reading of `exit:`)
becomes reachable by real data for the first time; no change there is needed or made.

The label choice binds one ambiguity worth naming: a resumed run sits in
`status:in-review` while it simplifies and ships, because steps 6–9 are one review-to-ship
arc and `status:awaiting-merge` arrives only at step 8's green gate. No third label is
minted for "resumed, shipping".

## Considered & rejected

**Resume by re-entering the loop with a fresh budget.** verified against
`$trial-loop`'s caller contract: "a run stopped as blocked at the iteration budget does not
re-enter the loop". Approval of the *workflow* step-over is what the cap bullet gates;
silently converting it into more reviewer passes would spend the pipeline's dominant cost
without the operator asking for it, and would erase the honest ending the summary exists
to record.

**Mint a sixth value, e.g. `blocked-at-budget-continued`.** verified against 0021: it
fixed five values "so the change that adds the path has one to use rather than minting its
own", and the continued run has one run-ending to describe. A compound value would also
break 0011's canonical-vocabulary conversion table, which maps one row per member.

**Publish the summary at resume time, before simplify.** verified against step 8's
sequence: the summary names `delivered-head-sha:`, which does not exist until `$deliver`
reports the PR, and the helper is the sole `WORK:REVIEW` writer with a single-invocation
contract. An early publication would be a second writer with a fabricated SHA.

**Put the whole path only in *On a Blocker*.** The blocker section is generic over every
park reason; burying one specific resume there forces every reader of step 6 — the step
whose stop contract creates the park — to look elsewhere for its counterpart. The split
(full path at the step that stops, pointer at the section that parks) keeps each fact
where its reader already is.

**Swap back to `status:in-progress` instead of `status:in-review`.** The park interrupted
step 6 of a review-to-ship arc; implementation (step 5) closed before the loop started,
and `status:awaiting-merge` is wrong until the green gate. Resuming into `in-review` is
the only value that matches where the run actually is, and it matches the issue's own
"swapped back" framing.
