# Implementation plan — the review exit payloads get a writable slot

Goal: make both destinations ADR 0021 names for `$trial-loop`'s exit payloads writable —
a bounded payload slot in `publish-forge-review`'s `compose_body`, and one named,
verified PR-body write moment in `$quest` step 8 (issue #159).

Architecture: one optional seventh helper argument (`PAYLOAD`), validated on the summary's
code path and composed after the forge review under `## Review exit payloads`; prose-only
routing changes in `skills/quest/SKILL.md`. The decision is
`docs/adr/0028-review-exit-payloads-get-a-writable-slot.md`, which supersedes anatomy
rule 2's freeze on the script and its test fixture.

Tech stack: Bash (helper + fixture), Markdown. No new dependencies.

## Global constraints

- **Repository is public.** No absolute user paths, hostnames, or session state;
  `scripts/check-public-safety.sh` enforces this.
- **Anatomy rule 2** — the payload slot is more of the byte-exact compose/verify/dispose
  work the helper exists for; no content parsing is added.
- **Anatomy rule 4** — nothing automated asserts on prose; the SKILL.md edits add no gate.
- **Guardrail command** — `just verify`, run bare.
- **Branch** — `feat/review-exit-payload-slot-159`; `BASE_BRANCH` is `main`.
- **SKILL.md scope** — edits touch only the step 6 carry paragraph, the step 8
  publication sequence, and the payload-routing sentence near it; issue #151 will edit
  this file later, so nothing else moves.

## Files

| file | responsibility |
|---|---|
| `skills/quest/scripts/publish-forge-review` | seventh argument, shared source validation, payload section, disposal |
| `tests/fixtures/quest/publish-forge-review-test.sh` | behaviour tests for the slot |
| `skills/quest/SKILL.md` | payload-file composition, PR-body write moment, helper invocation, routing text |
| `skills/quest-log/SKILL.md` | one sentence: the annotation may carry the payload section |
| `.claude-plugin/plugin.json` | version bump per ADR 0022 |

## Task 1 — failing tests first

Extend the fixture: payload composed verbatim between forge review and sentinel (required
and not-required modes); absent and empty arguments keep the old shape; non-private,
oversize, marker-bearing, CRLF, and NUL payloads rejected before any post with evidence
retained; missing final newline keeps the sentinel outer; disposal owns the payload in
both modes; arity below 6 or above 7 fails at usage. Watch the new cases fail, then
implement:

- `validate_arguments`: accept exactly 6 or 7 arguments; `payload=${7-}`.
- Extract the summary's private/size/UTF-8/NUL/CR/marker checks into one path shared with
  the payload; the required review keeps its own checks (its markers are indented data).
- `compose_body`: when the payload is non-empty, append blank line, heading, verbatim
  payload, final-newline guard, before the sentinel.
- Disposal includes the payload in both modes and names it in the ledger record.

## Task 2 — route the run through the slot

`skills/quest/SKILL.md`: replace the step 6 workaround paragraph (keep-with-resume-facts)
with the mechanism; in step 8 add the payload-file composition rules and the single
`gh pr edit --body-file` append with byte-verified readback before the
`publication-in-progress` handoff rewrite; pass `"$REVIEW_PAYLOAD"` as the seventh
argument; extend the disposal-ownership requirement to include the payload when one was
carried; update the "stays in WORK:REVIEW and the PR body" sentence to name the slot and
the write moment. One sentence in `skills/quest-log/SKILL.md`'s payload-shape paragraph.

## Task 3 — guardrails and ship

Bump `.claude-plugin/plugin.json` to 1.0.14. Run `just verify` bare. Commit per task.
