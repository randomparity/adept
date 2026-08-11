# Behaviour inventory — `requesting-code-review` (absorbed into `$review-loop` as `petition-council`)

Extracted from `skills/requesting-code-review/SKILL.md` and its
`code-reviewer.md` template at commit `eec533f` before any rewriting, per the
rewrite spec §5. Rows are observable behaviours, not wording.

This inventory uses **three** verdicts, because most of this skill is already
stated elsewhere:

- **ADD** — must be written at a destination in this unit.
- **CARRIED** — already stated at the named destination, with the evidence
  quoted. Verify, do not restate: a second copy of a rule is the drift surface
  §1 objects to.
- **DROP** — deliberately deleted, with a reason.

A CARRIED row is a claim that deleting this skill loses nothing. Each one was
checked against its destination rather than assumed.

| # | Observable behaviour | Verdict | Destination / reason |
|---|---|---|---|
| 1 | Dispatch the reviewer with precisely crafted context, never the session's history | CARRIED | `$build-tdd` party — "**Subagents inherit nothing.**" and "construct exactly what each one needs instead of letting it inherit" |
| 2 | Dispatch the reviewer in a subagent rather than reviewing inline | CARRIED | `$review-loop` The Loop step 1 — "Run `$challenge` in a **subagent**"; `$build-tdd` party dispatches every reviewer as a subagent |
| 3 | Keep the reviewer focused on the work product, preserving the requester's own context | CARRIED | `$build-tdd` party — "It also keeps your own context for coordination", and the file-handoff rule that artifacts move as files rather than pasted text |
| 4 | Base is the commit recorded before the work started, or the merge-base — never `HEAD~1` | CARRIED | `$build-tdd` party, per-task loop step 5 — "using the BASE you recorded **before** dispatching — never `HEAD~1`, which silently drops all but the last commit of a multi-commit task" |
| 5 | Review after each task in subagent-driven execution | CARRIED | `$build-tdd` party — the per-task loop, steps 5–7 |
| 6 | Fix Critical immediately, fix Important before proceeding, note Minor for later | CARRIED | `$build-tdd` party — "On Critical or Important findings, dispatch a fix subagent, then re-review. Do not move on with either still open" and "Record Minor findings in the ledger as you go" |
| 7 | Push back when the reviewer is wrong, with technical reasoning rather than compliance | CARRIED | `$review-loop` — "its recommendation is input, not instruction — you own the disposition" (`:325`), and the disposition system generally |
| 8 | Fill the template's four placeholders — description, requirements, base, head | ADD | Moves with the template to `skills/build-tdd/code-reviewer.md`; the placeholder list is in the template's own footer, so nothing is owed beyond the reference being correct |
| 9 | Review before merging to `main`, and optionally when stuck, before a refactor, or after a complex bug fix | ADD | `$review-loop`. The pre-merge case is owned by `$ship-pr`; the three optional cases are stated nowhere and are the one piece of genuinely uncovered judgement in this skill |
| 10 | Never skip review because the change looks simple | ADD | `$review-loop`. Related to row 9 and stated nowhere; it is the failure mode row 9's optional cases exist to catch |
| 11 | The review is read-only on the checkout: no mutation of working tree, index, HEAD, or branch state, and another revision gets its own worktree | CARRIED | The template itself, `## Read-Only Review`, which moves intact to `skills/build-tdd/code-reviewer.md`. Recorded here because it lives in the template rather than the wrapper and an inventory of `SKILL.md` alone would have missed it — it is a real safety rule, not formatting |
| 12 | The reviewer grades on `Critical / Important / Minor` and returns Strengths, Issues, Recommendations, Assessment | CARRIED | The template's `## Output Format`, which moves intact; `$challenge` owns the conversion to the pipeline's scale and says so |
| 13 | Announce "Review early, review often" as a core principle | DROP | A slogan, not a behaviour. Rows 5, 9 and 10 say when to review in checkable terms |
| 14 | Carry an `## Example` transcript of a fictional review round | DROP | 26 lines of invented dialogue illustrating rows 4, 6 and 8, all of which are stated directly. Same reason `subagent-driven-development`'s example workflow went in unit 2 |
| 15 | Carry an `## Integration with Workflows` section mapping this skill onto subagent-driven development, executing plans, and ad-hoc work | DROP | Two of the three named workflows are modes of `$build-tdd` after unit 2; the section describes a topology that no longer exists |
| 16 | Carry a Red Flags list restating "don't skip review", "don't ignore Critical", "don't proceed with unfixed Important", "don't argue with valid feedback" | DROP | A restatement of rows 6, 7 and 10. **Condition:** confirm each of its four clauses is carried by those rows before deleting — the same fold-then-delete condition that rescued two real clauses in unit 2 |

**Totals:** 16 rows — 3 ADD, 9 CARRIED, 4 DROP.

Nine of sixteen behaviours were already stated at a destination before this unit
began. That is the finding, and it is why this unit deletes 108 lines while
adding a handful of sentences.
