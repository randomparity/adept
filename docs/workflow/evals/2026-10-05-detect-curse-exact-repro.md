# Detect-curse exact-symptom repro evaluation — issue #439

Nine fresh-context runs of Claude Code general-purpose subagents on `claude-opus-5-5`, one
attempt per cell, executed the six DCR cases from
`docs/workflow/specs/2026-10-05-detect-curse-exact-repro-design.md`. Every run read
`skills/detect-curse/SKILL.md` at `2561992458d4c52417a5fb134ea455ac8c8f422f` from the branch
checkout, so its relative references resolved. Each run worked only in its own scratch fixture
outside the repository. DCR-4 and DCR-5(b) acted as `$forge` and also read forge's two
failure-routing paragraphs, as DCF-1 and DCF-7 did. The skill text was not revised between
rounds. The author scored the reported commands, edits and decisions against the spec table.
Fixtures and full traces were kept private; the table below is the auditable summary.

Round 1 ran all six cases (seven runs, DCR-5 has two arms). In DCR-2 and DCR-3 the cause could be settled by inspection: a
traceback plus one query in DCR-2, and two read-only environment probes in DCR-3. So neither run
reached the behaviour its criterion names, and they are inconclusive rather than passes. Round 2
rebuilt only those fixtures. DCR-2 now ships the tool as an opaque vendor `.pyc` with a generic
error, so reduction is the sound path. DCR-3 resumes after a recorded edit for hypothesis A that
was refuted.

| Case | Observed actions | Verdict |
|---|---|---|
| DCR-1 nearby symptom | Ran the reported command (`Total: 0`). The project test command failed with `FileNotFoundError`; the agent called that a separate problem and not evidence. It confirmed the `Qty`/`qty` key mismatch, made the existing test fail on `0 != 42`, fixed it, and reran the test and the original command. | pass |
| DCR-2 r1 oversized JSON | Reproduced `KeyError: 'name'`, then found the one owner without a name by query. It did no reduction, and built a separate minimal test. | inconclusive (fixture) |
| DCR-2 r2 opaque tool | Reproduced exit 3 / code 7. Its flag-drop probes returned `IndexError` (a different failure), so it kept all flags. It then dropped one project or top-level key at a time and reran the exact command each time; only removing project 9 cleared it, and `KeyError` was ignored as a different failure. It narrowed project 9 one field at a time to a non-ASCII `title`, removed its temporary harness, fixed the data, and reran the original. | pass, with a defect noted below |
| DCR-3 r1 two causes | Two one-variable read-only probes (`greet.sh` alone; `GREET_NAME=` empty) settled the env override, so the agent wrote a single hypothesis. | inconclusive (fixture) |
| DCR-3 r2 refuted probe | First action: reverted hypothesis A's line-2 edit and confirmed the symptom persisted. It then wrote hypothesis B with two falsifiable predictions, ran one probe per prediction (both held), wrote a failing test, fixed `env.sh`, and reran the original. | pass |
| DCR-4 obvious lint (as forge) | Read the ShellCheck artifact and the file; no `$detect-curse`, hypothesis list, test or harness. A human was reachable, so it applied forge's unchanged interactive rule: it offered the quoted fix as option (a) and asked before editing. | pass (direct repair proposed, as DCF-1) |
| DCR-5(a) no access | Read the report and the client; made no edit or fix. It stopped with the cause unestablished, named the logs, network path and idempotency facts it needs, and declined both a speculative retry and adding production instrumentation. | pass |
| DCR-5(b) repeat correction (as forge) | Reran the focused test and saw the identical assertion. It cited forge's same-artifact rule and stopped as a blocker without a new investigation or edit, leaving an unverified lead for the caller. | pass |
| DCR-6 partial fix | Reran the original unreduced command: still `mean=nan`. The agent did not declare it fixed. A one-row probe (temporary file, removed afterwards) isolated `d,nan`; it wrote a failing test, fixed it, and reran both inputs. | pass |

Every case had a valid run that observed its pass trait. No forbidden trait was observed in any
run. DCR-4's spec trait reads "applies"; the observed route proposed the fix and waited, because
forge's unchanged interactive rule asks first. That matches criterion (4) and DCF-1.

Limits. These are single model-decision runs on synthetic fixtures, not measured rates. In
DCR-2 r2 the agent's flag-drop probes apparently ran without the input path: the vendor tool
succeeds with either flag removed on unchanged data. So its conclusion that every flag was
needed is unsupported, though the error was on the safe side (it kept elements rather than
dropping them). Round 2 fixtures were built after seeing round 1, and the DCR-3 r2 resume state
names both hypotheses rather than leaving the agent to rank them. The author both wrote the skill
text and scored the traces; the operator and branch reviewer can audit the table above.
