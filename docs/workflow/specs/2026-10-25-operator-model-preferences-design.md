# Operator model preferences

## Problem

Issue #472: since #258 workers receive an explicit `model`, so the mapping's candidate order in
`references/model-mapping.md` decides what every tier requests. Free-form instructions are the
only override channel, and nothing gives them a location, shape or precedence. Editing the plugin
mapping does not survive an update. An operator who wants to keep Deep work off one model has
no defined way to say so.

## Scope

Decision: [ADR 0089](../../adr/0089-operator-model-preferences.md). This adds an *Operator
preferences* section to `references/model-selection.md`, which stays the single owner of
resolution. It also edits that file's resolution steps 2, 3 and 5, the final-review row and
the record paragraph, adds one header sentence and one walkthrough item to
`references/model-mapping.md`, and bumps the plugin to 7.12.0. This is a clean extension: no
ownership move, caller migration or compatibility path. Consumer skills keep linking the policy
unchanged.

**Location and shape.** The section lives under the exact heading `## adept model preferences`
in any instruction file the harness loads as effective user or project instructions. Each line
in it has this form:

```text
- <harness> <tier>: prefer <model>[, <model>...][; exclude <model>[, <model>...]]
- <harness> <tier>: exclude <model>[, <model>...]
```

- `<harness>` is `claude-code` or `codex`.
- `<tier>` is `mechanical`, `standard` or `deep`.
- `<model>` is an identifier or alias exactly as that harness accepts it.

One line exists per harness and tier key. Harness and tier keys match case-insensitively;
model tokens match exactly as the harness accepts them.

**Scope.** User scope is the harness's user instruction file (`~/.claude/CLAUDE.md` for Claude
Code, `~/.codex/AGENTS.md` for Codex) and any file it imports. Every other loaded instruction
file, nested and local ones included, is project scope. Claude Code labels loaded files by path.
Codex 0.164.0 concatenates the user file ahead of project documents, and the first
`--- project-doc ---` separator marks the boundary. With no separator, only one source loaded,
and its scope is recorded as unknown. A section the harness truncated or has not loaded is
absent and undetectable, so operators keep it in the user file or near the top of the root
project file.

**Precedence,** highest first:

1. Host restrictions.
2. An explicit choice: a model the operator names for this request, task or dispatch,
   recorded as `explicit override`. A coordinator's assignment derived from this policy is not
   one, and neither is standing instruction prose.
3. The project-scope line for the key.
4. The user-scope line for the key.
5. The plugin mapping.

A project line replaces the user line for the same key entirely. Lines are not merged. A
standing model instruction outside the section applies only to keys no section line covers.

**Resolution.** The candidate list is the preferred models in their stated order, then any
mapping candidates not already listed. Every excluded model is then removed. An exclusion
covers the model, not the string: an alias or fallback (such as `opus` or `best`) whose
resolution to an excluded model is known, or cannot be ruled out, counts as excluded.
Existing steps 3–5 choose from what remains. If no listed candidate is available, the verified
runtime default is used only when it is not excluded and its capability is established.
Otherwise the capability is reported as unmet. Absent an explicit choice for this request, an
excluded model is never requested, even as a host or runtime default.

**Final review.** "Permitted" means allowed by the host and not excluded for the Deep key. The
strongest permitted available model is chosen, and preference order does not apply. When
exclusions leave no adequate Deep candidate, the capability is unmet and the run stops before
dependent work. It never falls back to a lower tier.

**Faults.** The following are skipped and recorded in the work notes, then reported to the
operator:

- a malformed line;
- an unknown harness or tier;
- a key repeated in one scope, or a line whose scope cannot be established (the key's
  preferences are skipped, and its exclusions still apply).

An unavailable listed model is dropped and recorded, and its line still applies. Nothing else
is inferred from a skipped line.

**Basis.** The record names one of `explicit override`, `preference (project|user|unknown)`,
`mapping default`, `runtime alternative`, `runtime default` or `unmet`. It also lists every
skipped line or excluded model that changed the outcome.

### Failure model

- Actors/deployments: a trusted local operator; Claude Code and Codex loading user and project
  instruction files.
- Invariants/assets: explicit choices, strongest permitted final review, never requesting an
  excluded model, truthful recorded basis.
- Accepted: a project file's preferences bind like any other project instruction, which the
  harness already trusts. A weak preference cannot lower capability (step 3 still applies), and
  an over-broad exclusion surfaces as unmet.
- Covered elsewhere: mapping identifiers (refresh procedure); per-role and effort preferences
  (#348); savings measurement (#348); host-restriction mechanics (each harness).

## Success

Under each of these eight inputs, a reader of `model-selection.md` reaches exactly one supported
choice, or one named unmet capability, and its recorded basis:

1. No section.
2. A preferred model is unavailable.
3. The mapping's first Deep candidate is excluded.
4. Every Deep candidate is excluded.
5. An explicit request choice conflicts with the configured preference.
6. Project and user lines conflict for the same key.
7. A malformed line, or a key repeated in one scope.
8. A direct ID is excluded while the mapping lists its alias, or the only remaining option is
   an excluded runtime default.

The mapping alone still governs when no section exists, and its refresh procedure touches only
the mapping.

AI-SPEC: an operator configures model choice for adept workers, consumed at dispatch-time
resolution. Inputs are effective instruction files plus host inventory. The output is a model
request with a recorded basis. Forbidden: requesting an excluded model, inventing identifiers,
weakening final review. Fallback: verified default or unmet.

## Validation

- `references/model-selection.md` and `references/model-mapping.md`:
  `task-test-not-applicable`. These are policy prose with no executable consumer, and anatomy
  rule 4 forbids asserting on wording.
- Bounded evaluation (instruction-following failure, severity 4; every case blocks): walk the
  eight Success inputs through the edited policy against each harness's mapping, by reading
  (no provider session). Each must yield one choice or one named unmet capability, with its
  basis. Record each case's input, outcome and basis in the PR body; no judge model.
- `.claude-plugin/plugin.json`: `focused-test` with `BASE_SHA=$(git rev-parse origin/main)
  just version-check`. It exits 1 before the bump and 0 after.
- ADR 0089: `focused-test` with `just records`, which exits 0.
