# Operator-approved non-goals before design — issue #299

Issue #299 requires the design boundary to include what the change will not do. Epic #316
adopts the issue, and the operator separately approved its exclusions for this run. The operator
also approved reuse of a per-issue approval across campaign workers and resumes while its
exclusion set is unchanged.

## Problem

`$quest` and `$spellcraft` already require an `exclusions` field, but an agent may fill it with
an inferred or empty value without showing the proposed non-goals to the operator. `$campaign`
does not collect or carry a per-row approval, so a dispatched quest cannot distinguish an
operator-approved boundary from one the workflow invented. Issue work may also miss the direction
of later work in its parent epic and accidentally make that work harder.

## Scope and behavior

- Before design, propose concrete non-goals, including an explicitly empty set, and obtain the
  operator's approval. Issue and epic prose are evidence for the proposal, never approval by
  themselves.
- The approval covers the exact normalized exclusions and their owners. Normalization compares an
  order-independent set of exclusion/owner pairs after collapsing whitespace. Approval may cross
  a campaign dispatch or resume while that set is unchanged. Unrelated edits to issue or epic
  prose do not invalidate it; a changed set returns to the approval checkpoint.
- A campaign stores each fix row's proposed exclusions, relevant epic direction, and approval
  provenance in its private manifest. One explicit confirmation may approve all displayed rows.
  Workers receive that packet and do not ask again.
- An unattended run without a complete approval packet parks before design. An unattended campaign
  holds only affected rows and continues draining the rest.
- When an issue has a native parent epic, read its goals, non-goals, decomposition, and relevant
  upcoming open siblings. Use that direction to avoid foreclosing later work, not to enlarge the
  current issue. Report an evidence gap through the existing scope checkpoint when it leaves a
  design-changing ambiguity.
- The gate also applies to no-spec paths: it freezes scope but does not create a design artifact.

No new charter field is introduced. Approval provenance remains in the existing `provenance`
field, and the exact non-goals remain in `exclusions`.

## Change surface

| File | Change |
|---|---|
| `skills/quest/SKILL.md` | Inspect parent-epic direction and require approved exclusions before freezing `WORK:SCOPE` |
| `skills/spellcraft/SKILL.md` | Reject a charter whose exclusions lack operator-approval provenance |
| `skills/campaign/SKILL.md` | Collect, persist, validate, display, reuse, and dispatch per-row scope approvals |
| `.claude-plugin/plugin.json` | Bump the capability version to 4.5.0 |

## Acceptance scenarios

1. A direct interactive run proposes non-goals and waits for explicit approval before design.
2. Non-goals copied from an issue or epic still require operator approval.
3. A campaign confirmation is stored and reaches each quest worker with provenance.
4. A resumed campaign reuses an unchanged approval; a changed exclusion set waits for approval.
5. An unattended run missing approval parks before design, without blocking unrelated rows.
6. A child issue reads relevant upcoming epic work but neither adopts nor implements it.
7. A no-spec path records approved exclusions without producing a spec or plan.

## Verification

The changed artifacts are instructions, so repository anatomy rule 4 forbids unit tests that pin
their prose. Read the completed diff against the scenarios above, then run the existing structural
checks and repository guardrails. No helper, fixture, or executable is added.

## Non-goals

- No new executable, prose-matching gate, or charter field.
- No implementation of #317–#324 and no expansion of #299 from their requirements.
- No change to review depth, review finding routing, artifact lanes, proportionality, worker
  command execution, or the commit-bound merge gate.
- No requirement to rewrite older issues or design records with a `Non-goals` heading.
