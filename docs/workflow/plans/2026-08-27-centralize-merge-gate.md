# Centralized merge gate — implementation plan (issue #242)

**Goal:** make one reference the normative source for the commit-bound merge gate while
preserving the three skills' existing behavior.

**Architecture:** one Markdown reference consumed by three Markdown skills through the
repository's structurally checked relative-link convention. No executable code or new
dependency is introduced.

**Tech stack:** Markdown; repository `just` guardrails.

## Global Constraints

- `BASE_BRANCH`: `main`; branch: `feat/centralize-merge-gate-242`.
- Supported targets: x86_64 and arm64. Shell examples stay Bash 3.2 compatible.
- Preserve ADR 0035 semantics, including the issue-backed scope and restock PR-only
  exception.
- Anatomy rule 4 forbids any automated assertion on prose.
- Guardrails: `just shape-check` for focused checks and `just verify` before shipping.
- This public repository must contain no host-specific paths or private state.

## Task 1 — Record the current duplicated shape

**Files:** `skills/campaign/SKILL.md`, `skills/quest/SKILL.md`,
`skills/return-to-town/SKILL.md`, `references/merge-gate.md`.

**Interfaces:** consumes the existing merge-gate sections; records the pre-change state
without turning their prose into a machine-checked contract.

1. Run `test ! -e references/merge-gate.md` and expect exit 0, proving the central
   reference is absent.
2. Read the three named skills and record that each carries the operational gate inline.
   This is a human baseline observation; do not search for or assert on literal prose.

**Acceptance:** both baseline observations match the expected pre-change state.

## Task 2 — Extract one reference and link every consumer

**Files:** create `references/merge-gate.md`; modify `skills/campaign/SKILL.md`,
`skills/quest/SKILL.md`, and `skills/return-to-town/SKILL.md`.

**Interfaces:** `references/merge-gate.md` owns the complete gate; each skill consumes it
through `../../references/merge-gate.md` at the former inline block.

1. Copy the complete common gate into the standalone reference, preserving every command,
   gate part, fault rule, scope statement, merge binding, and retry rule. The shared block
   begins at `### The merge gate` and ends after the paragraph whose final sentence is
   `never retry the merge on the stale reads.`
2. Replace exactly that delimited block in each skill with a direct link and an instruction
   to apply the reference before the merge or handoff governed at that point. Preserve the
   consumer-specific suffixes after it: campaign's merge-method and serial-wave rules;
   quest's terminal-state and cleanup ownership rules; return-to-town's merge-method,
   post-merge closure, dependency reconciliation, and completion rules.
3. Review the complete diff and confirm that the reference holds the only operational copy,
   each consumer uses a relative Markdown link at the former boundary, and each named
   consumer-specific suffix remains unchanged. These are human reading observations; do
   not search for or assert on literal prose.
4. Run `test -f references/merge-gate.md` and expect exit 0.
5. Run `just shape-check` and expect exit 0; its existing rule checks that relative links
   into `references/` resolve without reading their wording.

**Acceptance:** exactly one complete operational gate remains across the reference and its
three skill consumers, all three links resolve, and the focused structural guardrail passes.
Historical ADRs and design records are not operational workflow copies.

## Task 3 — Version and verify the complete change

**Files:** modify `.claude-plugin/plugin.json`.

**Interfaces:** the manifest version makes the changed plugin installable; no later task
depends on another interface.

1. Increase the current `2.11.2` version to `2.12.0`, a minor bump for the added reference
   and centralized capability.
2. Run `just verify` and expect exit 0 with every suite passing and no warnings.
3. Run `git diff --check`, then review `git diff HEAD` and `git diff --cached` before
   committing so both unstaged and staged implementation changes are included. After the
   commit, review `git diff main...HEAD` as the complete branch diff.

**Acceptance:** the version is `2.12.0`, the full guardrail is green, and the diff contains
only the frozen surface.

## Rollback

Revert the implementation commit to restore the three inline copies and prior version. No
data, external service, or generated artifact requires cleanup.
