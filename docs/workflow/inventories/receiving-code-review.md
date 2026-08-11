# Behaviour inventory — `receiving-code-review` (becomes `references/heed-counsel.md`)

Extracted from `skills/receiving-code-review/SKILL.md` (213 lines) at commit
`332a7fb` before any rewriting, per the rewrite spec §5. Rows are observable
behaviours, not wording.

Verdicts are the ones defined in
[`test-driven-development`](test-driven-development.md): **KEEP** into the
reference, **GATE** where a skill already owns the operational form, **DROP**
with a reason.

## Where this one is consumed

Unlike the other two references, this one has a named caller. `$review-loop`
step 5 reads:

> If `verdict` is `needs-attention`, apply `receiving-code-review` to every
> finding, verifying each instead of agreeing reflexively — a finding you cannot
> defend on re-reading is `rejected-with-evidence`, not a fix.

`$work-issue:225` invokes it the same way over concerns and remedies. So the
reference is consulted at a specific, gated moment, and `$review-loop`'s
four-way disposition system (`accepted-fixed`, `deferred-tracked`,
`rejected-with-evidence`, `blocked`) already owns *what to do with* a finding.
What this document owns is what happens **before** that: whether the finding is
right, and how to say so.

That boundary decides most of the verdicts below. Anything about recording a
disposition is `$review-loop`'s and is GATE. Anything about evaluating and
answering is the reference's.

| # | Observable behaviour | Verdict | Destination / reason |
|---|---|---|---|
| 1 | Read the complete feedback before reacting to any part of it | KEEP | Step 1 of the response pattern, and the precondition for row 4 |
| 2 | Restate the requirement in your own words — or ask — before evaluating it | KEEP | The check that you understood the finding rather than pattern-matched it |
| 3 | Verify the finding against the codebase before implementing it | KEEP | The reference's core claim. `$review-loop` says "verifying each instead of agreeing reflexively" and points here for how |
| 4 | Evaluate whether the suggestion is technically sound for **this** codebase, not in general | KEEP | The distinction an external reviewer cannot make and the requester can |
| 5 | Never open with performative agreement — "You're absolutely right!", "Great point!", "Excellent feedback!" | KEEP | The behaviour the document exists to prevent, and the one most likely to recur without it |
| 6 | Never say "Let me implement that now" before verification | KEEP | Row 5's other form: agreeing by action instead of by phrase |
| 7 | Express agreement by stating the fix or by making it — not by thanking the reviewer | KEEP | The replacement behaviour. A rule that only forbids leaves nothing to write instead |
| 8 | When any item is unclear, stop and clarify **all** unclear items before implementing any of them | KEEP | The strongest rule here: items may be related, so partial understanding produces wrong implementation of the parts you did understand |
| 9 | Push back with technical reasoning where the suggestion breaks existing behaviour, misses context, violates YAGNI, is wrong for the stack, or has a legacy reason | KEEP | The substance of the pushback rule — *when*, not just *that* |
| 10 | A finding you cannot defend on re-reading is rejected with evidence, not implemented | GATE | `$review-loop` step 5 states this verbatim, and step 6 names the disposition. The reference does not restate a disposition it does not own |
| 11 | When you cannot verify a finding, say so and name what you would need — rather than proceeding either way | KEEP | The honest third answer between accept and reject, and it is stated nowhere else |
| 12 | Where a reviewer asks for a feature "done properly", check whether anything calls it before building it | KEEP | YAGNI applied to review feedback specifically, which is where it is hardest to apply |
| 13 | Implement multi-item feedback in order — blocking issues, then simple fixes, then complex ones — testing each individually | KEEP | Ordering and one-at-a-time testing. `$review-loop` records dispositions but says nothing about the order of the work |
| 14 | Where feedback conflicts with a prior architectural decision, stop and raise it rather than deciding alone | GATE | `$review-loop` step 6's `blocked` disposition — "required for correctness, but needs authority, a design decision, or a material charter expansion" |
| 15 | When you pushed back and were wrong, state the correction factually and move on — no long apology, no defending the pushback | KEEP | The counterpart to row 9. Without it, row 9 reads as licence to dig in |
| 16 | Name the discomfort and raise the issue anyway, when you are reluctant to push back | KEEP | The one row that addresses why the rule gets skipped rather than what the rule is |
| 17 | Reply to inline GitHub review comments in their thread (`gh api …/comments/{id}/replies`), not as a top-level PR comment | KEEP | Concrete, correct, mechanical, and true of the tool this repo actually uses |
| 18 | Treat external feedback as suggestions to evaluate, not orders to follow | KEEP | The thesis. Rows 3, 4, 9 and 11 are how it is carried out |
| 19 | Distinguish feedback from your human partner (trusted, implement after understanding) from an external reviewer (verify first) | KEEP, reworded | The distinction is real and worth keeping. The wording is not: it addresses the reader about *their* partner and quotes that person's house rules, which §2 asks to be re-expressed |
| 20 | Quote "your human partner's rule" twice as the authority for skepticism and for YAGNI | DROP | Another project's operator speaking. Rows 12 and 19 carry the rules; the attribution is upstream's voice |
| 21 | Forbid "ANY gratitude expression" and instruct deleting the word "Thanks" if caught writing it | KEEP, narrowed | The substance — do not substitute thanks for the fix — is row 7. The blanket ban on a word is the letter-over-spirit failure the other two references warn against, so the reference states the behaviour, not the wordlist |
| 22 | Carry a "Common Mistakes" table of 7 mistake/fix pairs | DROP | **Condition:** confirm each pair is carried before deleting. Verified: performative agreement → 5, 7; blind implementation → 3; batch without testing → 13; assuming the reviewer is right → 3, 4; avoiding pushback → 9, 16; partial implementation → 8; can't verify but proceed → 11 |
| 23 | Carry a "Real Examples" section of four transcript vignettes | DROP | Illustrates rows 5, 3, 12 and 8 as invented dialogue. Same reason `requesting-code-review`'s example round went in unit 3 |
| 24 | Carry the "Handling Unclear Feedback" worked example (understand 1,2,3,6 — unclear on 4,5) | DROP | Row 8 states the rule; the vignette then states it twice more, once here and once again under Real Examples |
| 25 | Carry the six-step response pattern as a numbered pseudocode block | KEEP | Rows 1–4 plus verify-then-implement in one readable sequence. It is the reference's spine, and the only place the order of the steps is visible at once |
| 26 | Carry the five-question checklist for external reviewers (correct here? breaks things? reason for current implementation? all platforms? does the reviewer have full context?) | KEEP | Row 4 made checkable. The fourth and fifth questions are not derivable from the others |
| 27 | Carry a closing "No performative agreement. Technical rigor always." | DROP | Restates rows 5 and 18, which are already stated at full strength |

**Totals:** 27 rows — 20 KEEP (3 reworded or narrowed), 2 GATE, 5 DROP.

213 lines carrying 27 behaviours, of which only five are restatement — the
leanest ratio of the three. What comes out is mostly voice: another project's
operator quoted as authority, and a word-level ban that the same document's own
letter-versus-spirit principle argues against.

**The boundary finding.** Rows 10 and 14 are the only ones `$review-loop`
already owns, and both are about *recording* a disposition rather than reaching
one. That is a clean split: the loop decides what a finding becomes, the
reference decides whether it is right. Nothing here needed to be duplicated to
make the loop work, which is why `$review-loop` can keep pointing at this
document with a one-line reference instead of absorbing it.
