# Budget stops resume on operator approval — design (issue #151)

Spec for the resume path a `$trial-loop` run takes when it stops blocked at the iteration
budget and the operator approves continuing. Decision record:
[ADR 0029](../../adr/0029-budget-stops-resume-on-explicit-operator-approval.md). Charter:
`WORK:SCOPE` token `q151-bc69251f` on issue #151, interaction unattended.

## Problem

`$quest` step 6 runs `$trial-loop`, whose cap bullet permits continuing past a budget stop
only on explicit user approval — but `$quest` documents no resume: the park protocol ends
at `status:needs-human` with no label swap-back, no `WORK:TRAJECTORY` continuation record,
and no re-entry step. ADR 0021 therefore holds `exit: blocked-at-budget` unwritable, and a
continued run (PR #160, issue #141) publishes no summary at all.

## Decisions (each traced to its charter criterion)

1. **Approval** = an explicit human decision from the operator who received the park,
   naming the parked run and directing continuation past the budget stop; delivered as an
   interactive reply, a durable record on the issue/PR, or an explicit dispatch term.
   *(criteria 1)*
2. **Transitions**: post a complete `WORK:TRAJECTORY` recording the approval first; then
   single-active swap `status:needs-human` → `status:in-review`. *(criterion 2)*
3. **Re-entry at step 7** (Simplify), after settling un-run step-6 obligations on step 6's
   own terms — notably the security pass, which a budget-stopped branch never reached; no
   loop re-entry; carry the stopped run's disclosure forward as resume facts into the
   existing payload destinations: the three carry-contract lists plus the stop's
   remaining-findings summary, which the new step-6 subsection adds to the carry list and
   whose admission requires widening step 8's payload-composition trigger (today an
   exhaustive three-list if-clause) to the lists step 6 specifies. *(criterion 3)*
4. **Exit mapping**: the run writes `exit: blocked-at-budget`; `verdict:` / `findings:` /
   `iterations:` describe that same stopped run. The approval is aftermath, not a second
   ending. A granted rescope is a different continuation governed by `$trial-loop`'s own
   rescoping rules and 0021's replacement rule. *(criterion 4)*
5. **Publication**: withheld until step 8; written once there through the unchanged
   ADR 0028 sequence. Step 8's hold clause is removed. *(criterion 5)*

## Normative guarantees

- G1: Only a run whose park was recorded (`WORK:TRAJECTORY`) and then explicitly approved
  may write `blocked-at-budget`. (necessary consequence of decisions 1–2 + criterion 4)
- G2: The approval alone never re-enters the loop. (`$trial-loop` caller contract, already
  normative) A settled obligation producing a behavior-changing accepted fix is a separate,
  already-governing authority: step 6's round-trip rule runs the loop once more, and
  ADR 0021's replacement rule rewrites the run-derived fields from that ending.
- G3: Exactly one summary exists per run, published at step 8 via the sole-writer helper.
  (ADR 0028 sequence unchanged)
- G4: The park protocol's ordering rule (record before label) applies to the resume edge
  symmetrically.
- G5: A resumed run settles every step-6 obligation the stop cut short — the security
  pass above all — before step 7, and the stop's remaining-findings summary reaches the
  payload destinations with the other carry lists. (necessary consequence of decision 3)

## Change surface

| File | Change |
|---|---|
| `skills/quest/SKILL.md` | step 6: approved-continuation subsection after the budget paragraph; step 8: rewrite `blocked-at-budget` bullet without the hold clause, and widen the payload-composition trigger's three-list enumeration to the lists step 6 specifies |
| `skills/quest/SKILL.md` | *On a Blocker*: one-line pointer to the step 6 resume under `status:needs-human` |
| `skills/trial-loop/SKILL.md` | caller-contract budget-stop bullet: one pointer sentence to `$quest`'s documented path |
| `docs/adr/0029-….md` | new record (this decision) |
| `docs/adr/0021-….md` | append an amendment note to `## Status` only — the records gate makes merged decision sections append-only |
| `.claude-plugin/plugin.json` | version bump (MINOR: skill gains a capability) |

Exclusions honored: no helper or fixture changes (ADR 0028 owns them); no bards-tale edit
(#149); no merge authorization.

## Verification

Docs-only change: no runtime tests exist or are added. Guardrails carry correctness:
`just verify` (records gate over the new ADR, shape-check, public-safety scan,
plugin-check `--strict`, version-check) and `just commit-check` per commit. Adversarial
coverage comes from the spellcraft reviews of ADR and spec, the oathbind scope audit, and
the branch `$trial-loop`. Behavioral proof is textual consistency, scoped to what this
change creates or modifies: every cross-reference the new text makes — quest step 6
subsection to step 8 and *On a Blocker*, trial-loop caller bullet to quest's step 6,
0021's appended Status amendment note, 0029 throughout — must resolve against the post-edit content,
checked by reading each cited location after the edits land. Pre-existing line-number
citations inside ADR 0021 are outside this claim: that record pins its citations to commit
`ea43def` by its own Context paragraph and expects later HEADs to drift.

## Failure modes considered

- A session resumes without approval → G1's record precondition fails; the run parks again.
- Two sessions race the resume → single-active label swap plus the existing claim protocol
  gate mutations of the issue.
- Stale line citations rot → the new text cites sections and names, not bare line numbers,
  wherever the surrounding prose allows.
