# Implementation plan — detect-curse exact-symptom repro

Goal: implement `docs/workflow/specs/2026-10-05-detect-curse-exact-repro-design.md` for issue #439.

Architecture: three prose edits inside `skills/detect-curse/SKILL.md` steps 1, 3, and 4, a version
bump, and one evaluation record of six bounded fresh-context runs. No executable code.

Tech stack: Markdown, JSON, repository guardrail recipes.

Expected implementation size: 90–130 changed lines (M) — about 30 skill lines changed, one JSON
value, and a 50–90 line evaluation record, excluding design artifacts.

## Global constraints

- Repository is public: committed text uses `$WORK`, never absolute paths, hosts, or user names.
- `.claude-plugin/plugin.json` version is exactly 7.4.0 (assigned; never derive or increment).
- Anatomy rule 4: no test or gate asserts Markdown wording. Rule 1: no supporting file or script.
- Do not edit forge, deliver, quest, attunement, or any reference file.
- Run gates bare: `just verify`, `just plugin-check`, `just version-check`.

## Files

| Path | Responsibility |
|---|---|
| `skills/detect-curse/SKILL.md` | Owns the debugging procedure; gains the repro, reduction, ranking, and original-rerun rules |
| `.claude-plugin/plugin.json` | Version 7.2.0 → 7.4.0 |
| `docs/workflow/evals/2026-10-05-detect-curse-exact-repro.md` | New: DCR-1..6 evaluation record |

No caller migration and no obsolete path: callers invoke `$detect-curse` unchanged.

## Task 1 — revise the skill

### Interfaces

Consumes the current step structure of `skills/detect-curse/SKILL.md` (headings `## 1. Investigate`,
`## 3. Form one hypothesis and test it`, `## 4. Fix`). Produces the revised skill Task 2 evaluates.
No heading anchor is referenced anywhere in the repository (`rg -n 'detect-curse/SKILL.md#'` is
empty), so renaming the step 3 heading breaks no link.

### Verification

- Skill behavior — `Mode: task-test-not-applicable`: the changed surface is instruction prose
  consumed only by a model; no executable consumer can fail on it, and rule 4 forbids asserting its
  wording. Task 2's bounded evaluation is the behavioral observation.
- Skill shape and version — structural, covered by `just shape-check` and `just version-check`
  inside `just verify`; both exit 0.

### Steps

1. In step 1, replace the paragraph beginning `**Reproduce it.**` with:

   ```markdown
   **Reproduce it with a check you have run.** Establish one command that fails on
   the *reported* symptom, and run it: an existing focused test, a replay, a CLI
   invocation against a fixture, or — only when nothing existing reaches the
   symptom — a small temporary harness. Record the command, what it needs to run,
   and the failure it produced, with hosts, credentials, and private paths
   redacted. The failure must be the one reported: the same error, assertion, or
   wrong output. A command that crashes some other way, or fails on a neighbouring
   symptom, is a different bug — it is not evidence for this one.

   An intermittent failure you cannot trigger on demand is not ready to be fixed —
   gather more data instead. A fix you cannot watch fail first is unfalsifiable.
   When access or evidence rules out a runnable repro, say what is missing and
   stop with the cause unestablished — the no-root-cause section below applies
   only after an investigation that ran. A missing repro is not permission to
   instrument a system you could not already change.

   **Reduce it only as far as the question needs.** When the repro carries inputs,
   setup, or steps that may not matter, remove them one at a time and rerun the
   same check after each. Keep a removal only if the exact failure survives it; an
   element whose removal changes or clears the failure is evidence — restore it
   and note it. Stop once the repro can tell the remaining candidate causes apart.
   An existing test that already isolates the failure needs no reduction and no
   new harness.
   ```

2. Rename `## 3. Form one hypothesis and test it` to `## 3. Hypothesise and test one variable at a time`.
3. Replace the paragraph beginning `Then state one hypothesis` and the following
   `If it was wrong` paragraph with:

   ```markdown
   Then write the hypothesis down, specifically: *this* is the cause, because
   *that*. When the evidence already demonstrates the cause, that one line is the
   whole list — do not invent rivals to it. When the cause is still uncertain and
   more than one explanation fits, list the plausible ones, most likely first, each
   with a prediction the repro can falsify: if this is the cause, then *this*
   change or measurement gives *that* result. Pick the probe whose result
   separates the leading candidates, change one variable, rerun the reduced
   check, and re-rank from what it showed. There is no quota; two candidates is a
   normal list.

   When a probe refutes its hypothesis, revert its change before the next probe.
   Do not leave the failed change in place and add another on top — two
   speculative changes interact, and now you cannot attribute either result.
   ```

4. In step 4, append to the `**Write a failing test**` paragraph: `Build it from the reduced repro
   where the project's tests can express it. When an existing check already fails on the exact
   defect — a linter, a type checker, a focused test — that check is the failing test; write no
   new one.`
5. Replace the `**Verify**` paragraph with:

   ```markdown
   **Verify** — the new test passes, nothing else broke, and the originally
   reported problem is actually gone: rerun the original, unreduced command from
   step 1. A reduced case that passes while the original still fails is not
   fixed — the reduction dropped a cause, and this was a fix that did not work.
   Return to step 3 with that difference as evidence. Read
   [true-seeing](../../references/true-seeing.md) before saying so.
   ```

6. Set `"version": "7.4.0"` in `.claude-plugin/plugin.json`.
7. Run `just verify`; expect exit 0. Commit `feat(detect-curse): require an exact-symptom repro`.

## Task 2 — bounded evaluation

### Interfaces

Consumes the Task 1 skill text and the spec's DCR-1..6 table. Produces the evaluation record.

### Verification

- Behavior cases — `Mode: task-test-not-applicable`: the observation is a fresh-context agent
  trace scored by a reader against the spec table; a test asserting on that record would assert on
  prose. Pass means every case's pass trait observed and no forbidden trait.

### Steps

1. For each case, build its input in a scratch directory outside the repository: DCR-1, DCR-2,
   DCR-3, and DCR-6 as small runnable shell or Python fixtures with a seeded defect; DCR-4 a shell
   script with one unquoted expansion and its ShellCheck output; DCR-5 two frozen artifacts (no
   environment access; a prior identical failed correction).
2. Dispatch one fresh agent per case. It reads `skills/detect-curse/SKILL.md` from the branch
   checkout (relative references resolve there) and works only in the case's scratch directory,
   then reports its ordered commands, edits, and final decision. For DCR-4 and DCR-5(b) the agent
   acts as `$forge` and also reads the two `skills/forge/SKILL.md` paragraphs that route a failure:
   the one beginning "First establish whether the cause is understood" (failing baseline) and the
   one beginning "Stop on a genuine blocker" (resistant task), as DCF-1 and DCF-7 supplied caller
   context.
3. Score each trace against the spec table. On any failed case, revise the Task 1 text, commit,
   and rerun all six cases against the new commit; a case failing twice blocks shipping.
4. Write `docs/workflow/evals/2026-10-05-detect-curse-exact-repro.md`: setup (model, the skill
   commit each case ran against, one attempt per case per round), a per-case table of observed
   actions and verdict for the operator and branch reviewer to audit, and limits. No absolute
   paths. Run `just verify`; expect exit 0. Commit `docs(evals): record detect-curse
   repro evaluation`.
