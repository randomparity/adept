# 0088 Optional producer on claim verification

## Status

Accepted (2026-10-11)

Operator approved issue459’s bounded design on 2026-10-11.

## Context

Issue459 asks verification to tolerate producer while retaining token-only ownership.
The existing owner parser requires producer; verification currently accepts token alone.

## Decision

Extend verification's current parser with an optional producer case; validate a supplied
value using the existing producer validator, then discard it. Preserve exact token equality.

## Consequences

Consistent acquire/verify flag sets work. Token-only callers remain supported.
No acquisition, recovery, release, storage, or network semantics change.

## Considered & rejected

- Reuse the owner parser unchanged. verified: `github_claim_parse_owner` in
  `skills/quest-log/assets/profiles/github.sh` at base `fdd00ff64e21c15ce8d3a8db780518d60ad87433`
  validates producer unconditionally; existing `claim-test.sh` token-only success would fail.
- Parameterize the owner parser. judgment: widens the shared acquisition parser for a
  six-line verification extension without a required ownership transition.
- Consume producer without validation. judgment: weakens meaningful malformed-value handling.
- Do nothing. verified: the original CLI reproduction exits usage1 with unknown
  claim-verify argument for producer at that same base, before a GitHub read.
