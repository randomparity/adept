# Light Spec: Bob Install Requirements Document (issue #478)

## Problem

adept has no written record of what a Bob user must supply to make its skills work.
The skills depend on a `<plugin root>` layout that the Claude Code and Codex harnesses provide
automatically; Bob has no equivalent plugin system, so the layout must be hand-supplied and is
currently undocumented. An installer cannot be specified or reviewed until these requirements
are written down and verified.

## Scope

One new file: `docs/bob-install-requirements.md`. No changes to existing files.
Not in scope: writing an installer, resolving the ADR 0001 / "Bob is retired" contradiction,
or live Bob environment verification (items requiring runtime observation are marked unverified).
One existing-file change is required: the mandatory `plugin.json` version bump (ADR 0022,
`just version-check`) that every PR touching the repository must include.

## Success

`docs/bob-install-requirements.md` exists and covers all seven items from issue #478 §Expected:
1. Minimum file tree for global (`~/.bob`) and project (`.bob`) scope, including `references/`
   and `scripts/check-public-safety.sh`.
2. `<plugin root>` resolution for copy vs symlink install, per script, with supported path stated.
3. Whether Bob IDE and Bob Shell follow symlinked skill folders; reload behavior.
4. How a skill's directory is named to the model under Bob.
5. Collision and idempotency rules for pre-existing content and re-runs.
6. adept features with no Bob equivalent (slash-command syntax, `agents/openai.yaml`).
7. Open decisions blocking an installer (ADR 0001 conflict, "Bob is retired" plan note).

Each claim carries a `verified` or `unverified` marker and the environment it was checked in.

## Validation

- `docs/bob-install-requirements.md` exists and is tracked by git.
- All seven items from the issue appear in the document.
- Every factual claim carries a verification marker.
- `just verify` passes (lint, test, records, shape).

## Failure model

N/A — this is a documentation-only change. No executable failure model applies.
