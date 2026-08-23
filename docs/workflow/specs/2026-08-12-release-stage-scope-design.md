# Release stage: decide the scope and record it

## Summary

Issue #50 asks a design question before it asks for an artifact: is release management —
tagging, changelog, release notes, deploy, post-merge verification — in scope for adept, for
the target repositories its skills operate on? Either answer closes the issue, one as a skill
and one as a recorded decision.

The answer is **scope-out**, recorded in
[ADR 0006](../../adr/0006-release-management-out-of-scope.md). The deliverable is that record
plus a one-line pointer to it from `README.md`'s workflow section — the record answers *why*,
and the pointer is what a reader who never thought to open `docs/adr/` actually meets. Issue
#50's "Expected" authorizes both: "an ADR **or** a line in the pipeline docs". Taking both is
not hedging, because they do different jobs; the record carries the reasoning and the revisit
condition, and the line carries discoverability.

## The question, and why it is open

`docs/adr/0001-distribution-via-plugin-marketplace.md` settled versioning for *this*
repository — manifests carry no `version`, updates track the git SHA. `CLAUDE.md` repeats it.
Neither says anything about the repositories the skills are pointed at, so the missing stage
reads as an oversight rather than a decision. That is the defect issue #50 reports; it reports
no blocked work.

Evidence gathered before deciding:

- No skill covers release, tagging, changelog, or deploy. The string `release` occurs in
  `skills/sort-board/SKILL.md`, `skills/campaign/SKILL.md` and `skills/return-to-town/SKILL.md`
  meaning *release a blocked issue*, and in `skills/clear-map/SKILL.md` meaning a protected
  `release/*` branch pattern. `return-to-town` also warns that a publish, release tag or
  deploy fired by a base-branch workflow runs *after* the merge — the post-merge residual
  ADR 0006 tracks as issue #65. None of these is a pipeline stage that drives a software
  release.
- This repository has no git tags and no GitHub releases, and runs one workflow, `verify.yml`.
- `$warding` reports dependency version drift and `$restock` merges Dependabot updates. Both
  read versions; neither publishes anything.

## Decision

Scope-out. The reasoning, the ground it rests on, the consequences, and the falsifiable
revisit condition all live in ADR 0006 and are not restated here — a second copy is the drift
problem `CLAUDE.md` exists to prevent.

## Non-goals

- ADR 0001 is not reopened. This record extends its discipline outward to target repositories;
  it neither supersedes it nor amends it, so 0001 takes no supersession banner.
- No skill is added and no existing skill is edited. `$return-to-town` and `$clear-map` keep
  their current endings, which ADR 0006 records as complete rather than truncated.
- `docs/cheatsheet.md` is not touched, and the skill-count line in `README.md` is unchanged.
  The cheat sheet is a which-skill-do-I-run table and there is no new skill to list. The one
  `README.md` edit is the pointer above, in the workflow section, and nothing else.
- No `docs/debt/` deferral record, and no `debt` profile added to `just records`. This is a
  decided exclusion, not deferred work.

## Acceptance criteria

| # | Source | Satisfied by |
|---|---|---|
| 1 | Issue #50 "Proposed approach" — decide scope-in or scope-out first | The Decision above, argued in ADR 0006 |
| 2 | Issue #50 "Expected" — a stated decision that release management is out of scope for adept, **and why** | ADR 0006 `## Decision` and `## Considered & rejected` |
| 3 | Issue #50 "Problem" — the omission must stop reading as a gap | ADR 0006 `## Context` names the ambiguity and closes it; the `README.md` pointer is what puts the answer where the reader looks |
| 4 | Issue #50 "Proposed approach" — one PR | Four files — the record, the `README.md` pointer, this spec, and the ADR 0022-mandated version bump in `.claude-plugin/plugin.json` — one PR, no code change |

## Guardrail interactions

- **`just records`** (`adr` profile) is the only gate with an opinion about the new file. It
  requires the H1 to begin `# 0006 `, the five level-2 sections `## Status`, `## Context`,
  `## Decision`, `## Consequences`, `## Considered & rejected`, and a `## Status` body matching
  `Accepted (YYYY-MM-DD)`. It also warns `W-INDEX-TABLE` if a numbered-row table appears in
  `docs/adr/README.md` — which is why no index row is added: this repository's ADR index is the
  directory listing.
- **`just shape-check`**, **`just plugin-check`**, **`just test`**, `lint`, `format-check`,
  `actions-check` are unaffected by the three documents: no skill directory, no shell, no
  workflow changes. The manifest does change: `.claude-plugin/plugin.json` bumps its version,
  which ADR 0022's gate requires of any tree change (rule 3: strictly greater than the base
  ref's), and `plugin-check` validates the declared form.

## Testing

Nothing automated asserts on prose — `CLAUDE.md` anatomy rule 4 forbids a gate that greps
Markdown for a sentence, so no test is added and none would be legitimate. The record gate's
structural checks above are the whole of the automation that touches this change; correctness of
the decision itself is a reading problem, which the adversarial review of ADR 0006 is what
answers.

## Risk

The decision can be wrong. The mitigation is the revisit condition in ADR 0006: reopen the
first time adept is actually asked to drive a release in a target repository. That is a
one-occurrence trigger on purpose. An earlier draft set it at three, borrowing the
third-repetition rule — but that rule governs when to *extract* a utility from code already
written, and the count here is zero, so applying it turned a do-not-extract-yet standard into a
do-not-build-until-three bar the evidence does not support. Reopening is also not building: one
real need settles what an artifact would have to do, and whether that generalises is the
superseding record's question.

The mitigation is weaker than it first reads, and the record says so rather than implying
otherwise. Nothing in this repository watches for the trigger: those releases happen elsewhere,
`$warding`'s staleness sweep reads the record directories the repository enables — here
`docs/adr/` under the adr profile — but selects only `Open` records past their `review-by:`,
which an Accepted ADR never is, and issue #50 closes with this change, so it is not a channel
either. The record therefore names a new issue citing
it as where a sighting goes. Building a counter would cost more than the risk it removes, so
the residual is stated and accepted — which is also why the `README.md` pointer matters more
than it looks: it is the only thing that puts the condition in front of a reader who was not
looking for it.
