# Behaviour inventory — `subagent-driven-development` (absorbed into `$build-tdd` as `party`)

Extracted from `skills/subagent-driven-development/SKILL.md` at commit `760c91a`
before any rewriting, per the rewrite spec §5. Rows are observable behaviours,
not wording. KEEP rows are the regression contract for the `party` mode. DROP
rows are deliberate deletions — the YAGNI filter of §5 — and must not reappear.

At 445 lines this is the largest single source in the rewrite. Its supporting
files — `implementer-prompt.md`, `task-reviewer-prompt.md`, and the three
scripts — move to `skills/build-tdd/` rather than being absorbed into prose; see
the plan's File Structure for the argument.

| # | Observable behaviour | Verdict | Reason |
|---|---|---|---|
| 1 | Dispatch a fresh implementer subagent per task, never one carrying the previous task's context | KEEP | The whole mechanism: isolated context is what keeps a subagent focused, and it preserves the controller's own context for coordination |
| 2 | Construct exactly what each subagent needs rather than letting it inherit session history | KEEP | The corollary of row 1; inheritance is the default and has to be actively prevented |
| 3 | Follow every implementer with a task review carrying two verdicts — spec compliance and code quality — and treat a report missing either as incomplete | KEEP | Two distinct failure modes: building the wrong thing, and building it badly. One verdict cannot cover both |
| 4 | Run one broad whole-branch review after all tasks, on the most capable model | KEEP | Per-task reviews are task-scoped by design and cannot see cross-task defects |
| 5 | Narrate at most one short line between tool calls | KEEP | The ledger and tool results are the record; narration is duplicated cost per turn |
| 6 | Execute all tasks without pausing to check in; stop only on unresolvable BLOCKED, genuine ambiguity, or completion | KEEP | "Should I continue?" between tasks wastes the human's time on a decision they already made |
| 7 | Scan the plan once before Task 1 for tasks that contradict each other or the Global Constraints, and for anything the plan mandates that the review rubric treats as a defect | KEEP | Without it, a plan-mandated defect burns one fix cycle per task instead of one question up front |
| 8 | Batch every pre-flight finding into one question rather than interrupting per discovery | KEEP | The half of row 7 that keeps it cheap |
| 9 | Where nobody can be asked, let the Global Constraints and repo conventions govern and record the deviation; escalate only when either choice could be wrong | KEEP | Keeps row 7 usable without a human in the turn — this is the one part of the dispatched-mode section that is a real behaviour rather than boundary apparatus |
| 10 | Pick the model per dispatch by task complexity: cheap for mechanical single-file work with a complete spec, standard for multi-file integration, most capable for design judgment and every final review | KEEP | The default inherits the session's model, which is usually the most expensive |
| 11 | Always name the model explicitly when dispatching | KEEP | An omitted model silently defeats row 10 |
| 12 | Weigh turn count over token price: use a mid-tier floor for reviewers and for implementers working from prose, and the cheapest tier only where the plan text contains the code to write | KEEP | The cheapest models take 2–3× the turns on multi-step work and cost more overall. This is the correction to a naive reading of row 10 |
| 13 | Handle the four implementer statuses distinctly — DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, BLOCKED | KEEP | Collapsing them loses the concerns and re-dispatches blind |
| 14 | Never ignore an escalation, and never retry an unchanged prompt after BLOCKED — add context, split the task, or escalate the model | KEEP | Retrying identically is the reflex, and it burns a full dispatch to learn nothing |
| 15 | Resolve every reviewer "cannot verify from diff" item yourself before marking the task complete, treating a confirmed gap as a failed spec review | KEEP | The controller holds the plan and cross-task context the reviewer lacks; unresolved, these read as passed |
| 16 | Never pre-judge a finding for a reviewer — no "do not flag", no "at most Minor", no "the plan chose" | KEEP | Named in the source as a stop condition on the prompt you are writing. This is the longest and most compressible rule here, and compressing it removes the gate |
| 17 | Do not add open-ended reviewer directives without a concrete task-specific reason, and do not ask a reviewer to re-run tests the implementer already ran | KEEP | Both inflate review cost for no verdict change |
| 18 | Copy the plan's binding requirements verbatim into the reviewer's global-constraints block, with exact values, formats, and stated relationships | KEEP | That block is the reviewer's attention lens; a paraphrase changes what it looks at |
| 19 | Dispatch fix subagents for Critical and Important findings; record Minor findings in the ledger and point the final review at that list | KEEP | Otherwise the Minor roll-up is a silent discard |
| 20 | Treat a finding that conflicts with what the plan mandates as the human's decision — present both, ask which governs | KEEP | Neither dismissing the finding nor silently contradicting the plan is correct |
| 21 | Send one fix subagent for the whole final-review findings list, not one per finding | KEEP | Per-finding fixers each rebuild context and re-run suites; a real session's final-review wave cost more than all its tasks combined |
| 22 | Require every fix dispatch to re-run the tests covering its change and report command and output, naming the covering files rather than the whole suite | KEEP | A fix reported without evidence is a claim |
| 23 | Hand artifacts over as files, not pasted text: the task brief, the report file, the review package | KEEP | Anything pasted into a dispatch stays resident in the controller's context and is re-read every later turn |
| 24 | Generate the task brief with `scripts/task-brief PLAN_FILE N` and keep exact values only in the brief | KEEP | A deterministic extraction a model would otherwise do inconsistently — the §4 rule 2 argument |
| 25 | Generate the review package with `scripts/review-package BASE HEAD`, using the recorded BASE and never `HEAD~1` | KEEP | `HEAD~1` silently drops all but the last commit of a multi-commit task |
| 26 | Keep dispatch prompts to one task — never paste accumulated prior-task summaries | KEEP | A real session's dispatch hit 42k chars of which 99% was pasted history |
| 27 | Track progress in a ledger file at `<workspace>/progress.md`, resuming at the first task not marked complete | KEEP | Conversation memory does not survive compaction; controllers that lost their place re-dispatched entire completed sequences — the most expensive failure observed |
| 28 | Create the workspace with `scripts/sdd-workspace`, which writes the self-ignoring `.gitignore` that keeps the ledger out of git, and confirm with `git check-ignore` | KEEP | Writing `progress.md` at a hardcoded path skips the script, and the next `git add -A` sweeps the ledger into someone's commit |
| 29 | Trust the ledger and `git log` over recollection after a compaction or resume | KEEP | The recovery contract that makes row 27 pay off |
| 30 | Never dispatch mutating subagents in parallel in one working tree | KEEP | They conflict; this is the constraint that makes sequential dispatch the default |
| 31 | Never let implementer self-review replace task review, accept "close enough" on spec compliance, or move on with open Critical/Important findings | KEEP | The three ways the review gate gets quietly skipped |
| 32 | Never make a subagent read the whole plan file; hand it its brief | KEEP | Cost, and it invites the subagent to work outside its task |
| 33 | Never re-dispatch a task the ledger marks complete | KEEP | The concrete form of row 29 |
| 34 | Announce the skill and its resolved mode at start | DROP | A mode inside a document does not announce itself |
| 35 | Carry a "Dispatched mode — no human in the turn" section | DROP | §1: exists only because `$build-tdd` calls this skill. Its two real behaviours are kept as rows 9 and 13's context; the rest is boundary apparatus |
| 36 | Render a `## When to Use` digraph choosing between this skill and `executing-plans`, plus a "vs. Executing Plans" comparison | DROP | That choice is now `$build-tdd`'s mode selection, made before either body is read. A mode cannot usefully argue for itself against its sibling |
| 37 | Render `## The Process` as a digraph of the per-task loop | DROP | Duplicates the prose sequence. **Condition:** the loop's steps — read the plan and note global constraints, create todos, dispatch, answer questions, review package, task review, fix subagent, re-review, mark complete, then the final whole-branch review — must be in prose before the digraph goes. Parts of that sequence appear *only* in the digraph today |
| 38 | Carry an `## Advantages` section arguing this approach against manual execution and `executing-plans` | DROP | It argues for a choice `$build-tdd` now makes on the reader's behalf, and it is read after that choice is already made |
| 39 | Carry an `## Example Workflow` transcript of a fictional session | DROP | 60 lines of invented dialogue. The rules it illustrates are all stated directly above it; a worked example of a process is not the process |
| 40 | Carry an Integration list naming sibling skills and an "Alternative workflow" pointer to `executing-plans` | DROP | Three of the four named skills are modes of this same document after this unit |
| 41 | Fill the provided `implementer-prompt.md` and `task-reviewer-prompt.md` templates for their dispatches, and use `requesting-code-review`'s `code-reviewer.md` for the final whole-branch review | KEEP | Found by the completeness check against `## Prompt Templates`, which rows 1–40 did not cover. The templates are the dispatch payloads; a mode that never names them leaves them orphaned in the directory |
| 42 | Give every implementer dispatch its scene-setting — where this task sits in the wider change | KEEP | Found by the completeness check against `## Red Flags` ("skip scene-setting context"). Row 23 implies it in the brief's contents; a subagent that does not know where its task fits builds it to the wrong boundary, so it is stated rather than implied |
| 43 | Answer a subagent's questions fully before letting it proceed, rather than rushing it into implementation | KEEP | Found by the completeness check against `## Red Flags` and the "If subagent asks questions" block. A question asked before work is the cheapest one to answer, and hurrying it converts it into a defect |
| 44 | Never start implementation on `main`/`master` without explicit consent | KEEP | Found by the completeness check against `## Red Flags`. Shared with `executing-plans` row 10 — after absorption one statement in `$build-tdd` serves both modes, which is a reason to state it once at document level rather than to drop it from either |

**Totals:** 44 rows — 37 KEEP, 7 DROP.

Row 37 carries a condition rather than a plain deletion. Rows 38 and 39 are the
largest single deletion in this unit at roughly 100 lines together, and both are
argument or illustration rather than instruction.
