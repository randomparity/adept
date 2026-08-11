# Behaviour inventory — `test-driven-development` (becomes `references/trial-by-fire.md`)

Extracted from `skills/test-driven-development/SKILL.md` (371 lines) and its
`testing-anti-patterns.md` (299 lines) at commit `332a7fb` before any rewriting,
per the rewrite spec §5. Rows are observable behaviours, not wording.

## What changes about the verdicts in this unit

Units 1–4 absorbed skills into other skills, so a behaviour either moved or died.
This unit converts a skill into a **reference**, and spec §1 defines that as "a
standard you consult while doing something else". That creates a split the
earlier units did not have:

- The **reference** owns the standard and the reasoning — why the order matters,
  what the failure modes look like, which rationalizations to distrust.
- The **skill** owns the gate — the numbered steps a builder executes.
  `$build-tdd` already carries that gate under `## TDD rules`.

So a behaviour appearing in both is not drift; it is the split working. Verdicts:

- **KEEP** — written into `references/trial-by-fire.md`.
- **GATE** — the operational form already lives in `$build-tdd`, and the
  reference does not restate it as a second gate. Named with the evidence.
- **DROP** — deleted, with a reason.

| # | Observable behaviour | Verdict | Destination / reason |
|---|---|---|---|
| 1 | Write the failing test before any production code | GATE + KEEP | `$build-tdd` "1. Write the failing test first." The reference keeps the *law* and its consequence — code written first is deleted, row 9 |
| 2 | Watch the test fail before implementing; an unwatched test proves nothing | KEEP | The reference's central claim. `$build-tdd` step 2 states the action; the reason ("if you didn't watch it fail, you don't know it tests the right thing") is the standard |
| 3 | Confirm the failure is the *expected* one — feature missing, not a typo or an error | KEEP | `$build-tdd` says "for the expected reason" without saying how to tell. The reference distinguishes fails from errors and says to re-run until it fails correctly |
| 4 | A new test that passes immediately is testing existing behaviour — fix the test, not the code | KEEP | Stated nowhere else, and it is the specific diagnostic row 2's rule produces |
| 5 | Write the minimal implementation; no extra options, no speculative parameters | GATE | `$build-tdd` "3. Write the minimal implementation", reinforced by the repo's own YAGNI rules |
| 6 | Verify green: the test passes, other tests still pass, and output is pristine | GATE | `$build-tdd` "4. Run the focused test and relevant guardrails" plus its Guardrails section, "Zero warnings" |
| 7 | When the test fails after implementing, fix the code — not the test | KEEP | The one-line rule that keeps rows 2 and 4 honest, and stated nowhere else |
| 8 | Refactor only while green, and add no behaviour while refactoring | GATE | `$build-tdd` "5. Refactor only while staying green" |
| 9 | Code written before its test is deleted — not kept as reference, not adapted while writing tests | KEEP | The enforcement half of row 1. Sunk cost is the pressure it exists to resist, and no skill states it |
| 10 | TDD applies to features, bugfixes, refactors and behaviour changes; prototypes, generated code and config are exceptions that need the human's agreement | KEEP | Scope of the standard — exactly what a reference is for |
| 11 | One behaviour per test; an "and" in the name means split it | KEEP | Test-design standard. `$build-tdd` says "Test behavior and edge/error paths" but nothing about test granularity |
| 12 | Name the test for the behaviour it demonstrates | KEEP | Same |
| 13 | Test real code; mocks only where unavoidable | KEEP | Same, and the hinge the anti-pattern rows hang from |
| 14 | A bug gets a failing test reproducing it before the fix — never fix a bug without one | KEEP | `$systematic-debugging` points here for exactly this (its line 195), so the reference must hold it |
| 15 | Cover edge cases and error paths, not only the happy path | GATE | `$build-tdd` — "empty input, null or missing values, malformed input, boundaries, timeouts, partial failure, permission failures, and degraded dependencies" |
| 16 | Never assert that a mock exists or was called in place of asserting on real behaviour | KEEP | `testing-anti-patterns.md` 1. The strongest of the five and stated nowhere else |
| 17 | Never add a method to a production class that only tests call — put it in test utilities | KEEP | `testing-anti-patterns.md` 2 |
| 18 | Know the real method's side effects before mocking it; mock at the lowest level that preserves what the test depends on | KEEP | `testing-anti-patterns.md` 3. "I'll mock this to be safe" is the failure |
| 19 | Mock the complete data structure as it exists in reality, not only the fields this test reads | KEEP | `testing-anti-patterns.md` 4. Partial mocks fail silently downstream |
| 20 | When mock setup outgrows the test logic, prefer an integration test with real components | KEEP | `testing-anti-patterns.md`, "When Mocks Become Too Complex" |
| 21 | A test that still passes when you delete the mock, or fails only because of it, is testing the mock | KEEP | `testing-anti-patterns.md` Red Flags. It is the *check* for row 16, which is worth more than the rule alone |
| 22 | Carry a `Red-Green-Refactor` Graphviz digraph | DROP | The cycle is five sequential steps with two retry edges. `$build-tdd` numbers them; the reference states them as prose. A `dot` source block renders nowhere the agent can see and cost 21 lines |
| 23 | Carry Good/Bad TypeScript pairs for the RED and GREEN steps (four blocks, ~60 lines) | DROP | Rows 11, 12, 13 and 5 state what the pairs illustrate. The examples are Jest-and-TypeScript specific in a reference consulted from Rust, Python and shell work |
| 24 | Carry a worked bug-fix example running the full cycle on an email validator | DROP | Restates rows 1–8 in one language. Same reason `subagent-driven-development`'s example workflow went in unit 2 |
| 25 | Carry a "Good Tests" table (minimal / clear / shows intent) | DROP | **Condition:** confirm each row is carried before deleting. Verified: minimal → 11; clear → 12; shows intent → 12 and 13 |
| 26 | Carry a "Common Rationalizations" table of 11 excuses and their realities | KEEP, compressed | This is the part of the document that does work a rule cannot — it answers the argument the reader is about to make. Compressed to the distinct ones: several rows restate "tests-after prove nothing" in different words |
| 27 | Carry a "Why Order Matters" section arguing against five specific objections | KEEP, folded into row 26 | Same objections as the table, at ~45 lines instead of 5. Fold, do not carry both |
| 28 | Carry a "Red Flags — STOP and Start Over" list of 13 items | DROP | **Condition:** verified against rows above. Code before test → 1; test after → 1; passes immediately → 4; can't explain the failure → 3; added later → 1; "just this once" → 26; manually tested → 26; "spirit not ritual" → 26 and 10; "keep as reference" → 9; sunk cost → 9, 26; "dogmatic" → 26; "this is different" → 26 |
| 29 | Carry a "When Stuck" table (can't test / too complicated / must mock everything / setup huge) | KEEP | Four rows that each convert a testing difficulty into a design signal. Not a restatement of anything above, and the most reusable content in the file |
| 30 | Carry a "Verification Checklist" of 8 boxes before claiming complete | DROP | Rows 1–15 are the checklist, and the completion-claim behaviour it gates is `references/true-seeing.md`'s subject. Two documents owning "before you claim complete" is the drift surface spec §1 objects to — see [`verification-before-completion`](verification-before-completion.md) |
| 31 | Carry four `Gate Function` pseudocode blocks in the anti-patterns file | DROP | **Condition:** verified. Each restates its own anti-pattern as a `BEFORE … IF … STOP` block — rows 16, 17, 18 and 19 respectively |
| 32 | Carry the anti-patterns Quick Reference table and Red Flags list | DROP | **Condition:** verified. Quick Reference restates 16–20 one-for-one. Red Flags: `*-mock` assertions → 16, 21; test-only methods → 17; setup >50% → 20; fails when mock removed → 21; can't explain the mock → 18; "just to be safe" → 18 |
| 33 | Carry "Anti-Pattern 5: Integration Tests as Afterthought" | DROP | It is the Iron Law (row 1) restated as a mock anti-pattern, in a file about mocks |
| 34 | Announce "Violating the letter of the rules is violating the spirit of the rules" | KEEP | Not a slogan in the sense units 1–4 dropped: it is the rule that closes rows 26 and 10 against re-reading the exceptions as a loophole. One line |
| 35 | Attribute rules to "your human partner" ("your human partner's correction", "your human partner's question") | DROP | Second-hand quotation of another project's operator. The rules survive as rows 16 and 20; the attribution is upstream's voice, and §2 asks for re-expression |
| 36 | Cite "From 24 failure memories" as the justification | DROP | Belongs to `verification-before-completion`, not here, and is an unverifiable appeal to a record this repo does not hold. See that inventory |

**Totals:** 36 rows — 21 KEEP (2 folded), 4 GATE, 11 DROP.

670 source lines carrying 36 behaviours, of which four already have an
operational home in `$build-tdd` and eleven are restatement, illustration, or
another project's voice. The reference should land near 200 lines.

The row that shaped the merge is **30**. The TDD skill and the verification skill
both ended with a "before you claim complete" checklist. Only one reference gets
to own that, and it is `true-seeing`.
