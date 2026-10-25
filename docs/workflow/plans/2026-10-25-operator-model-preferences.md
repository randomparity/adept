# Implementation plan — operator model preferences

Goal: implement `docs/workflow/specs/2026-10-25-operator-model-preferences-design.md` for
issue #472.

Architecture: one new section and five amended passages in `references/model-selection.md`,
one header sentence and one walkthrough clause in `references/model-mapping.md`, and a version
bump. No executable code.

Tech stack: Markdown, JSON, repository guardrail recipes.

Expected implementation size: 50–70 changed lines (M) — a new section of about 38 lines,
five amended passages of 2–4 lines each in model-selection, two amended mapping sentences and
one JSON value. Design artifacts are excluded.

## Global constraints

- Public repository: no absolute paths, hosts or user names in committed text.
- `.claude-plugin/plugin.json` version goes from `7.11.5` to exactly `7.12.0` (MINOR: a
  reference gains a capability).
- Anatomy rule 4: no gate asserts Markdown wording. Do not edit any `skills/*/SKILL.md`
  (exclusion 4), mapping candidates (exclusion 1), or add scripts (exclusion 2).
- Run gates bare: `just verify`, `just version-check`, `just records`.

## Files

| Path | Change |
|---|---|
| `references/model-selection.md` | Resolution steps 2, 3 and 5, the final-review row, the record paragraph, plus a new *Operator preferences* section |
| `references/model-mapping.md` | Header names the preference as an input; refresh step 3 walks through it |
| `.claude-plugin/plugin.json` | `"version": "7.11.5"` → `"7.12.0"` |

## Task 1 — operator preferences in the shared policy

### Interfaces

Consumes ADR 0089. The anchor `model-selection.md#operator-preferences` comes from the heading
`## Operator preferences`. The mapping links to it, and consumer skills reach it through the
existing policy link.

### Verification

- Policy prose (both references): `task-test-not-applicable`. It has no executable consumer,
  and anatomy rule 4 forbids a wording assertion. Walk the eight spec Success inputs against
  each harness's mapping by reading (step 10), recorded in the PR body.
- Plugin version: `focused-test` with `BASE_SHA=$(git rev-parse origin/main) just
  version-check`. It exits 1 before the bump and 0 after.
- Reference links: `focused-test` with `just shape-check`, which exits 0 (rule 5 resolves
  relative links).

### Steps

1. In `references/model-selection.md`, make the final-review refinement read: "Final
   whole-branch review always uses the strongest available permitted model (allowed by the host
   and not operator-excluded), even for a mechanical implementation."
2. Replace resolution step 2's first two sentences ("Apply effective user/project
   instructions ... with the mapping.") with:

   ```markdown
   2. Apply host restrictions, then a supported explicit choice (a model the operator names for
      this request, task or dispatch), then the [operator preferences](#operator-preferences)
      below, before these defaults. Do not overwrite a supported explicit choice with a
      preference or the mapping.
   ```

   Keep the step's remaining sentences ("If that choice conflicts ...") unchanged.
3. Make step 3's first two sentences read: "Match the required capability to an available
   candidate from the preference-ordered list below (or the mapping when none is configured),
   or a runtime-documented alternative that is not excluded. For final review compare the
   permitted available candidates, not only the first listed entry."
4. In step 5, after "use its runtime-supported default", insert "(never an excluded model)".
5. Replace "and override or fallback basis." in the record paragraph with "and basis
   (`explicit override`, `preference (project|user)`, `mapping default`, `runtime default` or
   `unmet`), naming any skipped preference line or exclusion that changed the outcome."
6. Insert this section before `## Escalation after difficulty or failure`:

   ````markdown
   ## Operator preferences

   An operator may reorder or exclude a tier's candidates without editing plugin files
   ([ADR 0089](../docs/adr/0089-operator-model-preferences.md)). Put the exact heading
   `## adept model preferences` in any instruction file the harness loads as effective user
   or project instructions, with one line per harness and tier:

   ```text
   - <harness> <tier>: prefer <model>[, <model>...][; exclude <model>[, <model>...]]
   - <harness> <tier>: exclude <model>[, <model>...]
   ```

   `<harness>` is `claude-code` or `codex`; `<tier>` is `mechanical`, `standard` or `deep`;
   `<model>` is an identifier or alias exactly as that harness accepts it. Harness and tier
   keys match case-insensitively; model tokens match exactly. User scope is the harness's user
   instruction file (`~/.claude/CLAUDE.md` for Claude Code, `~/.codex/AGENTS.md` for Codex);
   every other loaded instruction file is project scope.

   - **Precedence:** host restrictions, then an explicit choice, then the project line, then
     the user line, then the [mapping](model-mapping.md). An explicit choice is a model the
     operator names for this request, task or dispatch; a coordinator's assignment derived from
     this policy is not one, nor is standing instruction prose. A project line replaces the
     user line for the same key entirely; lines are not merged. A standing model instruction
     outside the section applies only to keys no section line covers.
   - **Candidates:** the preferred models in order, then any mapped candidates not already
     listed, minus every excluded model. An exclusion covers the model, not the string: an
     alias or fallback (such as `opus` or `best`) whose resolution to an excluded model is
     known, or cannot be ruled out, counts as excluded. Steps 3–5 choose from that list.
     If none is available, a verified runtime default applies only when it is not excluded and
     its capability is established; otherwise name the unmet capability. Absent an
     explicit choice, never request an excluded model.
   - **Final review:** permitted means allowed by the host and not excluded on the Deep key.
     Compare those candidates on strength; preference order does not apply. If exclusions
     leave no adequate deep candidate, the capability is unmet before dependent work — never a
     lower tier.
   - **Faults:** skip and record a malformed line, an unknown harness or tier, a key repeated
     in one scope or a line whose scope cannot be established (skip that key), or an
     unavailable model, and report it to the operator. Infer
     nothing from a skipped line.

   With no section configured, the mapping alone supplies candidates.
   ````

7. In `references/model-mapping.md`, after "Runtime support and effective instructions take
   precedence.", insert "[Operator preferences](model-selection.md#operator-preferences)
   reorder or exclude these candidates without editing this file."
8. In the mapping's refresh step 3, change "Walk through both harnesses, an explicit override,"
   to "Walk through both harnesses, an explicit override, a configured preference and
   exclusion,".
9. Run `BASE_SHA=$(git rev-parse origin/main) just version-check` and expect exit 1. Change the
   version to `7.12.0`, rerun, and expect exit 0.
10. Walk the eight spec Success inputs against the Claude Code and Codex mappings by reading
    the edited text (no provider session). Write each case's input, chosen model or unmet
    capability, and basis into a local note for the PR body; any case without exactly one
    outcome blocks the commit.
11. Run `just shape-check` and expect exit 0, then commit:
    `docs: add operator model preferences per selection tier`.

Acceptance: each of the eight spec Success inputs resolves through the edited text to one
recorded choice or one named unmet capability with its basis. No skill file changes.
