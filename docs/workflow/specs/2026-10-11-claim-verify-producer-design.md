# Claim verification producer compatibility (#459)

## Problem

GitHub `claim-verify` rejects `--producer` before reading a claim. The shared owner
parser requires producer, while existing verification callers pass token alone.

## Scope and design

Extend the existing verification parser with one optional `--producer` case.
Require its value and use `github_claim_validate_producer` on that value, then discard
it. Token parsing, claim reads, and exact token comparison remain in the current owner.
No caller migration or ownership transition is required. See [ADR0088](../../adr/0088-claim-verify-optional-producer.md).

Source: [Issue459](https://github.com/randomparity/adept/issues/459) expected behavior;
Campaign acceptance requires token-only compatibility, meaningful argument errors,
and absent/foreign claim exit classes. Scope token: `q459-d7661a52`. Operator approved this design on 2026-10-11.

## Success

- A valid producer before or after token yields held success for the exact held token.
- A different valid producer cannot change held success or foreign-token exit6.
- Token-only verification continues to succeed; absent claims still exit2.
- Missing producer values, empty/invalid producer values, missing/invalid token values,
  and unknown flags produce structured usage exit1 before a claim read.

## Global Constraints

Bash3.2 floor, tab indentation, `set -euo pipefail`; no new dependency.
Version `.claude-plugin/plugin.json=7.11.0`. Ubuntu and macOS CI arms.
Tests assert behavior and structured JSON, never prose.

## Failure model

- Actors and deployments: local operators and workflow callers invoking the GitHub tracker
  on macOS or Linux; fixture tests replace GitHub at the CLI boundary.
- Invariants and assets: ownership depends only on exact token equality; token-only
  compatibility; usage1, absent2, foreign6 distinctions; verification performs no writes.
- Accepted failure classes: none introduced; existing transport failures remain existing errors.
- Covered elsewhere: acquisition/recovery, claim storage, TTL, network execution and
  claim-release flag consistency — tracker profile maintainer (approved exclusions).

## Threat model

- Boundary inventory: widen local CLI parsing to accept producer; existing claim-read
  response boundary unchanged. No new network operation or executable interpolation.
- Actor model: operator-supplied strings are untrusted data; GitHub response remains
  governed by existing claim parsing. No producer value grants ownership.
- Control per boundary: existing producer validator rejects malformed values before
  reads; existing token validator and equality comparison govern ownership.
- Explicitly out of scope: claim acquisition/recovery/storage/TTL/network execution
  and release consistency belong to the approved tracker-maintainer exclusions.

## Validation

One Cast task adds CLI fixture cases for valid producer in both orders, different
producer with owned/foreign tokens, absent claims, malformed/missing arguments,
and no claim writes. Run `just test claim` red then green, `just commit-check`, then
one assembled focused run. Managed pre-push hook owns final full local suite; CI
independently runs both OS arms. Documentation has no prose assertion tests.
