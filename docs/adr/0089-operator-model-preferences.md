# 0089 Operator model preferences in instruction files

## Status

Accepted (2026-10-25)

Operator approved issue472's location and precedence in the interactive design session on
2026-10-25.

## Context

Shared model selection resolves a tier to the first available mapped candidate. Workers now
receive that choice explicitly (#258), so an operator who wants a tier to prefer or avoid a
model needs a location, a shape and a precedence. The location must survive plugin updates and
be readable by Claude Code and Codex without a resolver program (#350).

## Decision

An operator states preferences under the heading `## adept model preferences` in any effective
user or project instruction file. Each line has the form
`- <harness> <tier>: prefer <models>; exclude <models>`.

Precedence, highest first:

1. Host restrictions.
2. An explicit per-request choice.
3. The project line.
4. The user line.
5. The plugin mapping.

A project line replaces the user line for its key entirely. Candidates are the preferred models,
then the mapping candidates, minus every exclusion. Final review takes the strongest
non-excluded available model. When nothing adequate remains, the capability is unmet.

## Consequences

Preferences live in files the operator already owns and the harness already loads. Plugin
updates leave them alone, and routine refreshes still touch only the mapping. Malformed lines
are skipped and reported, never guessed at. An exclusion can make Deep work unmet, which is
intended: it never silently downgrades. A project file can steer choices only as far as any
project instruction already can.

## Considered & rejected

- **adept-owned preference files at fixed user and project paths.** judgment: every consumer
  gains a new read path and a new precedence rule, which duplicates what instruction loading
  already provides.
- **Plugin `userConfig` options.** verified: `cat .codex-plugin/plugin.json` at base `b9d9288`
  shows only `name`, `description` and `skills`. adept declares no Codex-side configuration
  surface, so an option declared for Claude Code would leave Codex runs unconfigured.
- **Merge user and project exclusions as a union.** judgment: two combination rules (replace for
  preference, union for exclusion) cost more to explain than the repetition they save. The
  operator chose replacement.
- **Do nothing (free-form instructions only).** verified: `references/model-selection.md`
  step 2 at base `b9d9288` names instructions without a location, shape or precedence relative
  to the mapping, which is the gap issue472 reports.
