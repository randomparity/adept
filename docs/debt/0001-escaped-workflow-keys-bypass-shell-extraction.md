# 0001 — Escaped workflow keys bypass shell extraction

## Status

Open
review-by: 2026-10-27

## Concern

The independent workflow ShellCheck gate recognizes a bounded lexical subset of YAML keys.
Double-quoted escape sequences such as `"r\u0075n": |` and `"sh\u0065ll": pwsh` normalize to
`run` and `shell` when actionlint parses them, but do not match the gate's lexical checks. An
escaped `run` block can therefore be omitted from independent ShellCheck coverage, and an escaped
non-Bash `shell` override can be checked under the wrong Bash dialect. Actionlint 1.7.12 accepted
both reproduced forms with `-shellcheck=` and exit 0.

## Why deferred

Issue #243 was expanded twice to clear verification blockers, and the operator explicitly declined
a further scope expansion after the capped adversarial loop found this remaining YAML-equivalence
class. Replacing lexical extraction with structure-aware YAML processing changes the guardrail's
architecture and dependency or implementation surface; that work is deliberately deferred so the
chartered merge-contract correction can proceed.

## Non-regression boundary

The deferring change keeps actionlint's structural checks enabled, independently ShellChecks every
currently supported literal `run: |` block as Bash, rejects ordinary quoted `run` and `shell` keys,
and rejects unsupported runner, matrix, indentation, scalar, and shell forms. The repository's
current workflows contain no escaped mapping keys. Future changes must not broaden the accepted
lexical subset or remove those rejection fixtures without resolving this record.

## What would resolve it

Replace the lexical workflow-shell discovery with a structure-aware design that observes YAML's
decoded mapping keys, or reject every quoted mapping-key declaration before extraction. Resolution
requires focused tests proving escaped spellings of `run` and `shell` cannot bypass coverage, the
real workflow scan, and the full repository guardrail at exit 0.

## Provenance

target: scripts/check-actionlint.sh
Found by the fifth and terminal adversarial pass of the issue #243 trial loop on 2026-08-27.
tracker: #243
