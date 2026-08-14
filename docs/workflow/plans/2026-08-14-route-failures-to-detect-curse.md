# Route unexplained pipeline failures to detect-curse

## Goal

Connect the three existing pipeline failure entry points to `$detect-curse` when their cause is not
already understood. Each skill keeps its existing recovery and stop semantics; only the diagnostic
route is added.

Tech stack: Markdown skill contracts, existing structural shell guardrails.

## Global Constraints

- Add no script, dependency, configuration, compatibility path, or change to `$detect-curse`.
- Keep direct correction only when the current failure artifact or an already-recorded
  investigation identifies a specific cause and the correction follows from that evidence.
- An unexplained failure invokes `$detect-curse` before a fix is proposed or applied.
- Diagnosis never authorizes advancement through a red baseline, test, guardrail, or CI check.
- Do not add an automated assertion on prose; repository anatomy rule 4 reserves automation for
  structure.
- Full guardrail is `just verify`; CI runs the same chain through `just ci`.
- Architecture: host `arm64`; targets `none declared`; relationship `no-target-declared`.

## File map

- Modify `skills/forge/SKILL.md`: route unexplained baseline and resistant task failures.
- Modify `skills/deliver/SKILL.md`: route unexplained required-check failures.
- Modify `skills/quest/SKILL.md`: state the pipeline-wide red-guardrail routing invariant.
- Create ignored scratch `.agent/evals/issue-41-detect-curse-routing.md`: retain DCF trace inputs,
  ordered outputs, scores, and a concise pass/fail summary through branch review and PR creation;
  never commit it.

## Task 1: Add the diagnostic routes

### Interfaces

Consumes the existing `$detect-curse` skill invocation. Forge, deliver, and quest continue to
produce their existing stop, recovery, verification, and handoff outcomes. No new command or data
interface is created.

### Steps

1. Run the structural baseline:

   ```sh
   just shape-check
   ```

   Expected: exit 0. This records the pre-change structural state; the repository intentionally has
   no behavior test that pins skill prose.

2. In `skills/forge/SKILL.md`, extend the baseline section so an interactive or governed
   dispatched path invokes `$detect-curse` when the failure cause is not understood before asking
   whether to proceed. State the shared evidence threshold and preserve the existing no-authority
   blocker for dispatched runs.

3. In `skills/forge/SKILL.md`, extend the genuine-blocker section so a test or verification that
   remains red after the planned correction invokes `$detect-curse`; if diagnosis cannot establish
   a repair, preserve the existing stop behavior. If the same failure recurs after the same
   evidence-backed correction without new evidence, stop instead of repeating diagnosis.

4. In `skills/deliver/SKILL.md`, split required-check handling by evidence: directly correct an
   already-understood cause, otherwise invoke `$detect-curse`, then apply only the evidence-backed
   repair before local guardrails and push. Preserve the ban on rerunning for green.

5. In `skills/quest/SKILL.md`, extend the opening invariant: an unexplained red guardrail invokes
   `$detect-curse`; an understood failure is corrected directly; neither path advances until green.

6. Run focused structural and public-safety checks:

   ```sh
   just shape-check
   just public-safety
   ```

   Expected: both exit 0, with all `$detect-curse` invocations resolving and no private data.

7. Review the three edited contexts together, then give fresh tool-using agents the relevant skill
   context, failure artifact, and prior evidence for `DCF-1` through `DCF-8` from the design spec.
   Keep the agents read-only. Record and score their ordered action traces. Confirm direct repair
   requires current causal evidence, unexplained failures diagnose before repair, an unresolved or
   unchanged failure stops, and no site weakens its original stop condition. Write the inputs,
   traces, scores, and concise case summary to the ignored run artifact
   `.agent/evals/issue-41-detect-curse-routing.md`.

8. Run the full guardrail:

   ```sh
   just verify
   ```

   Expected: exit 0 with only the repository-documented plugin manifest version warning.

9. Commit the exact skill files and design records:

   ```sh
   git add skills/forge/SKILL.md skills/deliver/SKILL.md skills/quest/SKILL.md \
     docs/workflow/specs/2026-08-14-route-failures-to-detect-curse-design.md \
     docs/workflow/plans/2026-08-14-route-failures-to-detect-curse.md
   git commit -m "feat: route unexplained failures to detect-curse"
   ```

10. Pass the readable eval artifact and its concise DCF-1 through DCF-8 summary into branch review.
    Carry the concise summary into the pull-request verification section. After the PR body is
    created and read back with that summary, move the scratch artifact to the platform trash. If
    review or publication fails, retain it for diagnosis.

### Acceptance criteria

- All three issue-named pipeline entry points route unexplained causes to `$detect-curse`.
- Already-understood failures retain their direct correction path.
- No path advances while its existing guardrail remains red.
- Structural and full repository guardrails pass.

## Final verification

1. Run `just verify` bare.
2. Review `git diff main...HEAD` for consistent trigger language and accidental scope growth.
3. Confirm tracked status is clean before branch review; the ignored eval artifact remains until
   its PR summary is published and verified.

## Rollback

Revert the implementation commit. Before PR publication, move any retained ignored eval artifact
to the platform trash. The change creates no migration, dependency, or external cleanup obligation.
