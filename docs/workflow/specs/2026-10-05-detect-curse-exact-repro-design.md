# Exact-symptom repro and uncertain-cause comparison in detect-curse

Issue: #439

## Goal

Make `$detect-curse`'s feedback loop concrete: a check that has actually been run and fails on the
reported symptom, reduced only as far as the remaining question needs, uncertain causes compared
through falsifiable predictions, and the original scenario re-verified after repair. Failures whose
cause is already established keep their current cost.

## Scope and authority

The frozen scope is issue #439 annotation token `q439-9915ebf0`, posted by campaign
`10c3119f7cfe-2541d11b-dbeb-4e5d-931c-b17451a3a1bb`. The six acceptance criteria are the issue's
bounded behavior cases. There are no unresolved ambiguities.

Permitted surface: `skills/detect-curse/SKILL.md`, this spec, its plan, one record under
`docs/workflow/evals/`, and `.claude-plugin/plugin.json` = 7.4.0. Excluded, with owners:
production instrumentation permission (operator / future issue); extra fix attempts or a changed
three-failure budget, and a per-hypothesis user checkpoint (existing skill contract); a fixed
hypothesis count or wholesale external import; a new harness or mandatory exhaustive minimization;
a prose-grepping gate (anatomy rule 4); forge/deliver/quest routing text (#104); any supporting file
or script (anatomy rule 1). No ADR: the change has no layer, ownership, or contract alternative —
the debugging procedure stays owned by `$detect-curse` and its callers are untouched.

## Design

Three edits to the skill, each inside the step that already owns the concern.

1. **Step 1, Reproduce.** Replace the "exact steps" paragraph with a runnable-check requirement.
   The investigator establishes one command and runs it: an existing focused test, a replay, a CLI
   invocation against a fixture, or a small temporary harness only when nothing existing reaches
   the symptom. It records the command, its prerequisites, and the observed failure, redacted. The
   failure must be the reported one — same error, assertion, or wrong output; a crash of another
   kind or a neighbouring failure is a different bug and not evidence. Intermittent failures keep
   the existing "not ready to be fixed — gather more data" rule. When access or evidence rules out a
   runnable repro, the investigator names what is missing and ends with the cause unestablished,
   which is the stop the #41 routing contract already handles; a missing repro grants no
   permission to instrument systems it could not already change.
2. **Step 1, Reduce.** A new paragraph: remove irrelevant inputs, setup, or steps one at a time,
   rerunning the same check after each; keep a removal only if the exact failure survives; stop
   when the repro distinguishes the remaining causes. An existing test that already isolates the
   failure needs no reduction and no new harness.
3. **Step 3, Hypotheses.** Heading becomes "Hypothesise and test one variable at a time". A cause
   the evidence already demonstrates is the whole list — no manufactured rivals. When the cause is
   uncertain and several explanations fit, list them most-likely first, each with a prediction the
   repro can falsify; choose the probe that separates the leaders; change one variable; rerun the
   reduced check; re-rank. No quota. The existing revert-before-the-next-probe rule stays and now
   names the refuted probe explicitly.
4. **Step 4, Fix and verify.** The failing regression test is built from the reduced repro where
   the project's tests can express it. Verification reruns the original, unreduced command from
   step 1. A reduced case that passes while the original still fails is not fixed: it is a fix that
   did not work, so the existing three-failure count applies, and the investigation returns to step
   3 with that difference as evidence.

Unchanged: the "No fix before the investigation has run" rule, the three-failure stop, flaky-test
polling guidance, the no-root-cause section, and every caller's direct-repair boundary.

## Failure model

1. Actors and deployments
   - A model agent running `$detect-curse` in Claude Code or Codex, invoked directly or by forge,
     deliver, quest, or attunement, with a local checkout and the operator's existing permissions.
2. Invariants and assets at stake
   - The direct-repair route for a failure whose current artifact names the cause (#41/#104).
   - The three-failure stop and the cause-unestablished stop: diagnosis never loops indefinitely.
   - A fix is reported only after the original reported scenario passes.
   - Recorded repro evidence stays redacted before it reaches any public write.
3. Accepted failure classes
   - An agent that ignores the prose: a reading problem, measured by the bounded evaluation, not
     prevented by a gate (anatomy rule 4).
   - Reduction that stops earlier than a human would: tolerated because the stop rule is "enough to
     distinguish the remaining causes", and step 4's original-scenario rerun catches a reduction
     that dropped a cause.
4. Covered elsewhere
   - Routing into `$detect-curse` and the same-artifact-recurs stop — #41/#104 routing contract in
     forge, deliver, and quest.
   - Public-write redaction — the global privacy rule and `scripts/check-public-safety.sh`.

## AI-SPEC and evaluation plan

The user is an agent or operator debugging a failure. The trigger is a `$detect-curse` invocation.
Inputs are the failure report, its artifacts, and the repository. Output is an investigation: a
recorded repro, a reduced repro where needed, a tested cause, and a verified fix or a stated stop.
Allowed sources are the failure artifact, the repository, and commands the agent may already run.
Disallowed: treating a nearby failure as the bug, stacking refuted changes, a hypothesis ritual for
a demonstrated cause, an indefinite loop, declaring fixed while the original fails, or new
production instrumentation. Fallback is the existing cause-unestablished stop. No new model call,
latency, or token budget is introduced.

Tool-using-agent dimensions: tool-use correctness, task completion, loop avoidance, instruction
following. Each case below is severity 4 (a wrong outcome on a core workflow) and gets one bounded
fresh-context run. A fresh tool-using agent receives the revised skill and a synthetic case — a
small runnable fixture in a scratch directory outside the repository where the case needs one,
otherwise a frozen failure artifact — and acts on it. Its ordered commands, edits, and final
decision are the observed trace. The author scores each trace against the observable traits below
and records the result; traces stay private. A failed case revises the skill and reruns that case
once; a second failure blocks shipping. Scoring is on actions taken, never on matching wording.

| Case | Input | Pass trait | Forbidden trait |
|---|---|---|---|
| DCR-1 nearby symptom | Report names one error; the obvious command fails with a different one | Rejects that failure as evidence; finds or reports the exact symptom | Diagnoses or fixes from the nearby failure |
| DCR-2 oversized fixture | Fixture reproduces the exact symptom with several irrelevant inputs | Removes elements one at a time, rerunning after each, keeps the exact failure | Removes several at once; changes the symptom unnoticed |
| DCR-3 two causes | Two plausible causes fit; one probe refutes the first | States distinguishing predictions; one-variable probes; reverts the refuted change first | Stacks the refuted change under the next probe |
| DCR-4 obvious lint | ShellCheck output names `SC2086` on one line | Applies the prescribed fix directly using the lint command as the check | Builds a hypothesis list or a new harness |
| DCR-5 no repro / repeat | No access to the failing environment; or the same correction already failed with no new evidence | Names what is missing; stops with cause unestablished or at the existing stop | Proposes a speculative fix or loops diagnosis |
| DCR-6 partial fix | Reduced case passes after a fix; original scenario still fails | Reruns the original; does not declare fixed; returns to hypotheses | Reports the bug fixed |

`just verify` (including `just shape-check`) remains the structural guardrail; no new gate.
