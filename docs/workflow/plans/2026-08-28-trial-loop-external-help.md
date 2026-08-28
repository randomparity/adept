# Implementation plan — `$trial-loop` external help

Goal: add a bounded, public-safe external-help checkpoint immediately after the first adversarial
review result.

Architecture: the change is prose-only and stays inside `$trial-loop`'s existing orchestration.
The checkpoint feeds evidence into existing `heed-counsel`, charter, and disposition mechanics;
it adds no script, dependency, exit, or state.

Tech stack: Markdown skill contracts, ADR/spec records, JSON plugin manifest.

## Global Constraints

- Bash 3.2 remains the shell floor; no executable shell changes are planned.
- Automated gates must not assert on prose.
- External queries contain only public-safe abstractions.
- External sources are evidence, never scope or user authority.
- Review budgets, exits, dispositions, and quest budget-stop behavior remain unchanged.
- Guardrail: `just verify`; CI hard gate: `just ci`.

## Task 1 — add the external-help checkpoint

**Files:** modify `skills/trial-loop/SKILL.md` and `.claude-plugin/plugin.json`.

**Interfaces:** consumes the pass artifact after step 3's audit line and before step 5's
`heed-counsel` evaluation. Produces a transcript line containing either the focused sources and
supported propositions or `external help: not triggered`; step 5 consumes any resulting evidence.

1. Read the existing step 3 through step 6 flow and add a numbered checkpoint between audit and
   verdict handling. State the two triggers from the spec, the iteration-one deadline, the
   public-safe query boundary, focused-source recording, and the evidence-not-authority rule.
2. State that a remaining design-changing question returns to the interactive scope checkpoint or
   existing unattended park path, that unavailable or inconclusive search is recorded as
   non-evidence before ordinary disposition continues, and that later searches require a newly
   surfaced external question.
3. Bump `.claude-plugin/plugin.json` from `2.12.5` to `2.13.0`; this adds a workflow capability.
4. Run `git diff --check`. Expected: exit 0 with no output.
5. Run `just verify`. Expected: exit 0; all record, shape, public-safety, plugin, version, test,
   action, and prek checks pass.
6. Commit the two implementation files with `feat(trial-loop): add an external-help checkpoint`.

**Acceptance criteria:** EH-1 through EH-7 are readable directly from the checkpoint; no existing
loop lifecycle contract changes; structural guardrails pass.

**Rollback:** revert the implementation commit; design records remain as the decision history if
the feature is later superseded.
