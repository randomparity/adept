# Detect-curse exact-symptom repro evaluation — issue #439

The six DCR cases in `docs/workflow/specs/2026-10-05-detect-curse-exact-repro-design.md` were run
as fresh-context Claude Code general-purpose subagents on `claude-opus-5-5`, one attempt per case
per round. Each run read `skills/detect-curse/SKILL.md` from the branch checkout, so its relative
references resolved, and worked only in its own scratch fixture outside the repository. DCR-4 and
DCR-5(b) acted as `$forge` and also read forge's two failure-routing paragraphs, as DCF-1 and DCF-7
did. The author scored the reported commands, edits and decisions against the spec table.
Fixtures and full traces stayed private; this record is the auditable summary.

## Rounds

- **Rounds 1–2, skill `2561992`.** In round 1, DCR-2 and DCR-3 could be settled by inspection, so
  neither run reached the behaviour its criterion names (inconclusive). Round 2 rebuilt those two
  fixtures. DCR-2 became an opaque vendor `.pyc` with a generic error; DCR-3 became a resume after
  a refuted hypothesis-A edit. In round 2, DCR-2 showed a forbidden trait: its flag-drop probes
  dropped the input path as well, two elements at once. That counts as a failed case.
- **Branch review then revised step 1 and step 4.** The intermittent-failure route now has its own
  stop, and a reduced case that passes while the original fails sends the agent back to reduce
  from the original command.
- **Round 3, skill `0e2b523dd7d474fa9e22e41164bc7f18692dbb37`.** As the spec requires after a
  revision, all six cases reran against this commit, using the round-2 fixtures for DCR-2 and
  DCR-3. Round 3 is the result below.

## Round 3 results

| Case | Observed actions | Verdict |
|---|---|---|
| DCR-1 nearby symptom | Ran the reported command (`Total: 0`). The test command failed with `FileNotFoundError`, and the agent rejected it as a separate problem. It confirmed the `Qty`/`qty` mismatch, made the existing test fail on `0 != 42`, fixed it, then reran the test and the original command. | pass |
| DCR-2 opaque tool | Reproduced exit 3 / code 7, then removed `--verbose`, `--color=never` and `--strict` one at a time with a rerun after each. Only dropping `--strict` cleared it. It then dropped project 9 alone, then changed only its title, ruling out byte encoding, JSON escaping and locale one probe at a time. Temporary inputs were removed. It stopped short of a fix because the remaining choice was a data or validation trade-off. | pass |
| DCR-3 refuted probe | First edit: reverted hypothesis A's line-2 change, then reran the repro. It then probed B one variable at a time (`env -u GREET_NAME`, `GREET_NAME=Bob`), wrote a failing test, fixed `env.sh`, and reran the original from two working directories. It stated no prediction: its measurements demonstrated B directly. | partial: prediction trait not observed |
| DCR-4 obvious lint (as forge) | Reread the ShellCheck artifact, the file, and the current baseline. No `$detect-curse`, hypothesis list, test or harness. A human was reachable, so under forge's unchanged interactive rule it offered the quoted fix as option (a) and asked first. | pass (direct repair proposed, as DCF-1) |
| DCR-5(a) no access | Read the report and the client, and changed nothing. It stopped with the cause unestablished, listed the evidence it needs, and declined a speculative retry. | pass |
| DCR-5(b) repeat correction (as forge) | Read the history and the files, cited forge's same-artifact rule, and stopped as a blocker with no new investigation or edit. | pass |
| DCR-6 partial fix | Reran the original unreduced command: still `mean=nan`, so it did not declare a fix. A one-row probe isolated `d,nan`. It wrote a failing test, fixed it, and reran both inputs. | pass |

In round 3, six of the seven runs observed every pass trait, and no run showed a forbidden trait.
DCR-3 observed the revert-first and one-variable-probe traits but not the prediction trait. Under
the plan that is not a pass. The author did not revise the skill for it, because the observed route
follows step 3's rule that a demonstrated cause needs no rivals. Criterion (3)'s prediction
behaviour therefore rests on round 2, which stated two falsifiable predictions for hypothesis B.
Step 3's text is unchanged between `2561992` and `0e2b523`: their diff touches only steps 1 and 4.
The operator owns whether that evidence is sufficient. DCR-4's spec trait says "applies", but the
observed route proposed the fix and waited, because forge's unchanged interactive rule asks first.
That route matches criterion (4) and DCF-1.

## Limits

- Each verdict is a single model decision on a synthetic fixture, not a measured rate.
- The DCR-2 and DCR-3 fixtures were redesigned after round 1.
- DCR-3's resume state names both hypotheses, so the agent did not rank them itself.
- Two round-3 DCR-3 dispatches (one Opus, one Sonnet) ended in a provider safeguard error before reporting. The third,
  given an otherwise identical brief that asked for notes in a file, completed on a fresh copy of
  the fixture.
- The author both wrote the skill text and scored the traces.
