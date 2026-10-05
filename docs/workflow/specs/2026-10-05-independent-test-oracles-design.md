# Independent test oracles — design (#440)

## Problem

`references/trial-by-fire.md` requires the right red failure but never says where an expected
value may come from. A test whose expectation reuses the implementation's calculation goes red,
then green, and still proves nothing. Forge's whole-branch reviewer (`skills/forge/code-reviewer.md`,
Testing) has no check for that circular oracle.

## Scope

- `references/trial-by-fire.md`: one short section after "Why the order is the whole point".
  An expected value needs a basis that can disagree with the code: a requirement or contract,
  a worked example, an independently established known-good result, or a genuinely independent
  reference. Circular forms: calling the subject (or its helper) to build the expectation,
  sharing the defective calculation, copying the production algorithm into the assertion,
  approving a regenerated snapshot unread. Contrast: 10% off 10,000 cents is 9,000 by worked
  arithmetic, not by the discount helper. Independently specified properties and metamorphic
  relations are sound oracles; a computed expectation is circular only if it cannot disagree
  for the relevant defect.
- `code-reviewer.md` Testing: one bullet — trace where consequential expected values came from,
  flag a concrete circular dependency, and treat recorded red/green as not settling oracle
  correctness.
- Unchanged: forge's refactor-while-green and snapshot-regeneration rules, verify-red (ADR
  0055). No new stage, field, or suite rerun. No ADR: no decision with viable alternatives.

### Failure model

- Actors and deployments: agents running `$forge`/`$detect-curse`, and forge's reviewer subagent.
- Invariants and assets at stake: valid property tests and green refactors stay accepted.
- Accepted failure classes: the reviewer misses a subtle oracle — bounded; it is one reading check.
- Covered elsewhere: red-failure mechanics (ADR 0055); suite weight (#291).

## Success

1. Expectation built through the subject or its faulty helper: circularity named despite
   recorded red/green.
2. Worked contract result: accepted; it catches a discount applied in the wrong direction.
3. Sort property (ordered, same multiset): accepted without a fixed literal.
4. Regenerated snapshot contradicting the contract: mismatch named.
5. Behavior-preserving refactor kept green: accepted under refactor-while-green.

## Validation

- Contract: oracle rule and reviewer bullet (both files).
  Mode: task-test-not-applicable — prose read by agents; no executable consumer, and rule 4
  forbids asserting on wording. Evidence is the bounded evaluation below.
- AI surface (reviewer prompt, reference). Input: a short test plus contract. Output: accept,
  or a named circular oracle. Disallowed: rejecting properties, refactors, or computed
  expectations that can disagree. Severity-4 modes: missed circularity (cases 1, 4); false
  rejection (cases 2, 3, 5).
- Evaluation: five cases, one per Success item, each a small Python snippet given to a fresh
  evaluator holding only the changed files. Pass: the named route; forbidden: the opposite
  verdict. Gate: block. One pass; one confirming pass after a correction; a second failure parks.
- `.claude-plugin/plugin.json`: version 7.3.0 (campaign-assigned); `just version-check`.
