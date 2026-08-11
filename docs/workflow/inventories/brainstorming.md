# Behaviour inventory — `brainstorming` (absorbed into `$design` as `council`)

Extracted from `skills/brainstorming/SKILL.md` at commit `7e7f969` before any
rewriting, per the rewrite spec §5. Rows are observable behaviours, not wording.
KEEP rows are the regression contract for the `council` phase. DROP rows are
deliberate deletions — the YAGNI filter of §5 — and must not reappear.

| # | Observable behaviour | Verdict | Reason |
|---|---|---|---|
| 1 | Read project state — files, docs, recent commits — before asking anything | KEEP | The cheapest correction of a wrong premise |
| 2 | Assess scope before detail: flag a request spanning independent subsystems instead of refining one of them | KEEP | Prevents spending the whole dialogue on a project that needed decomposing |
| 3 | Decompose an oversized project into sub-projects, each getting its own spec → plan → implementation cycle | KEEP | The only stated remedy for behaviour 2 |
| 4 | Ask exactly one question per message | KEEP | Named in spec §5 as a lesson that lives in an unremarkable sentence |
| 5 | Prefer multiple-choice questions over open-ended where the choice is closed | KEEP | Cheap to answer, and forces the asker to have thought |
| 6 | Propose 2–3 approaches with trade-offs before settling, recommendation first | KEEP | Named in §5's key principles as surviving |
| 7 | Present the design in sections scaled to complexity, confirming after each | KEEP | Incremental validation; a whole design rejected at the end is wasted |
| 8 | Refuse to skip the design for a "simple" project; allow the design to be short | KEEP | Explicitly an anti-pattern section in the source; the failure it prevents is unexamined assumptions |
| 9 | Design for isolation: one purpose per unit, defined interfaces, independently understandable | KEEP | Directly serves the repo's own file-size and clarity standards |
| 10 | In an existing codebase, follow established patterns and include targeted improvements to code being touched, but not unrelated refactoring | KEEP | Scope discipline; the "don't propose unrelated refactoring" half is the load-bearing one |
| 11 | Write the spec to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` and commit it | KEEP | The durable artifact; `$design`'s context checkpoint depends on it existing |
| 12 | Self-review the written spec for placeholders, internal contradiction, scope, and two-way ambiguity | KEEP | Catches the defect class cheapest at the spec |
| 13 | Apply YAGNI to the design itself, removing unnecessary features | KEEP | Driver 2 of the rewrite |
| 14 | Announce the skill and its resolved mode at start | DROP | A phase inside a document does not announce itself; the mode it announced does not survive |
| 15 | Carry a "dispatched workflow mode" section mapping each gate to a dispatched replacement | DROP | §1: the section exists only because `$design` calls this skill. The call is gone |
| 16 | Return design-changing ambiguity through a `SCOPE CHECKPOINT` block reproduced in full | DROP | `$design`'s own "External scope authority" section already owns the charter and the checkpoint. Two copies is the drift surface §1 objects to |
| 17 | Render the process as a `dot` digraph duplicating the numbered checklist | DROP | Two representations of one sequence; the numbered phases are the one a reader follows |
| 18 | Create a task per checklist item and complete them in order | DROP | Restates the phase order as bookkeeping; the phases are already ordered |
| 19 | Stop at a HARD-GATE until the user approves the design | KEEP | The gate itself survives; its dispatched-mode escape hatch (row 15) does not |
| 20 | Terminate by invoking `writing-plans`, and no other skill | DROP | Both are phases of one document now; there is no invocation and no terminal state to police |
| 21 | Ask the user to review the written spec and wait for a response | DROP | `$design` step 3 already adversarially reviews the spec; the source itself says so |
| 22 | Offer a browser visual companion for questions better shown than described | DROP | Already deleted in `aca0ba2` under §4 rule 3; recorded here so the rewrite does not reintroduce it |

**Totals:** 22 rows — 14 KEEP, 8 DROP.
