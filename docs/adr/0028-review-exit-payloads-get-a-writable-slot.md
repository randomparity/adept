# 0028 — The review exit payloads get a writable slot and a named PR-body write

## Status

Accepted (2026-08-21)

Amends [0021](0021-review-summary-names-the-trial-loop-exit.md)'s payload-destination
ruling and supersedes the not-to-be-edited freeze that
`docs/workflow/plans/2026-08-18-review-summary-named-exit.md` (anatomy rule 2) places on
`skills/quest/scripts/publish-forge-review` and
`tests/fixtures/quest/publish-forge-review-test.sh`.

## Context

ADR 0021 rules that a `$trial-loop` run's exit payloads — the deferral list with each
entry's owning record path, the outstanding notes, the confirmed claim list — stay out of
the review summary and go "to the `WORK:REVIEW` comment and the pull request body". Both
destinations are unwritable for a multi-line payload, which is issue #159's finding,
verified on the branch-review loop for issue #141 and deferred there to #159 by PR #160.

**The comment has no slot.** `$quest` names the publication helper the sole `WORK:REVIEW`
writer and forbids a second comment on a nonzero helper exit. The helper's `compose_body`
composes exactly the outer marker, the summary file verbatim, the indented forge review,
and the outer sentinel — no fourth part. The summary cannot carry the lists: ADR 0021
fixes it as six exact, non-empty, single-line fields, and the same record rejects widening
it, because "those are unbounded multi-line lists; this artifact is a capped,
single-line-field header". Appending the lists to the summary file anyway would run into
`MAX_SOURCE_BYTES`, enforced after the handoff has been rewritten to the terminal
`publication-in-progress` phase — a long deferral list would park a finished, green PR for
human reconciliation.

**The body has no step.** `$deliver` composes the PR body once at `gh pr create`
(`skills/deliver/SKILL.md` step 2), `$quest` step 8 hands it nothing but the issue number,
and neither skill later edits the body for this purpose — `$deliver`'s two later body
writes are CI-cause notes it composes itself.

Anatomy rule 2 of the named-exit plan froze the helper and its test fixture on the ground
that executable code must do something a model cannot do reliably inline, and that record
declined a summary *field-list* check on that ground. That reasoning does not reach this
change. The helper exists because byte-exact composition, GitHub copy verification, and
recoverable disposal are not reliable inline; a payload slot is more of exactly that work,
not a format parse. The freeze served one change's scope boundary, and issue #159 is the
change that reopens it.

## Decision

**`compose_body` gains a bounded payload slot with its own source file, and `$quest` step
8 gains one named, verified write moment for the PR body.** The destinations ADR 0021
names are unchanged; both become writable.

**The slot.** `publish-forge-review` accepts an optional seventh argument, `PAYLOAD`.
Omitted or empty means no payload section, so every existing caller and every existing
publication keeps its exact shape. A non-empty payload is validated exactly as the summary
is: a private mode-0600 regular file with content, at most `MAX_SOURCE_BYTES`, valid
UTF-8, no NUL, no carriage return, and no whole-line outer annotation marker. The shared
checks for the summary and the payload are one code path. `compose_body` appends, after
the forge review and before the outer sentinel, a blank line, the heading
`## Review exit payloads`, and the payload verbatim — unindented like the summary it sits
beside, with the same final-newline guard the review gets so the sentinel stays outer and
whole-line-anchored. The payload is disposed with the helper's other inputs after
verification and named in the ledger's disposal record, in both modes.

The body's own cap is unchanged: `MAX_BODY_BYTES` still bounds the whole composed
annotation, payload included, and the public-safety scan still runs on the whole body. A
payload that does not fit the annotation fails before any comment is written, with every
input retained — the same failure shape the summary's size cap already produces, and
unlike that cap it fires before the handoff goes terminal, because validation precedes
composition and the handoff rewrite.

**The write moment.** `$quest` step 8, after `$deliver` reports the PR and the run
verifies its identity, composes the payload file once beside the ledger — private mode
0600, `mktemp`, atomic rename after the write, the same byte rejections the helper will
re-apply — and immediately appends its contents to the PR body under the same
`## Review exit payloads` heading with `gh pr edit --body-file`, verifying the readback
byte-for-byte. This is the one moment the body gains the section: before the
`publication-in-progress` handoff rewrite, so the write never happens in the terminal
parked phase, and never again afterwards. A failed or unverifiable body write parks the
quest before the helper with the evidence retained. The same payload file is the seventh
helper argument, so one source feeds both destinations and they cannot drift.

**ADR 0021 is amended, not superseded.** Its decision — the `exit:` field, its five
values, and the rule that the payloads stay out of the summary — stands in full. What
amends is the consequence its payload paragraph carried: the destinations it names now
have machinery, so `$quest` step 6's carry instruction and step 8's publication route
become executable rather than aspirational. The record gate's one banner form marks a
record superseded, which would falsely retire the field-set contract, so the amendment
lives here and 0021 keeps its accepted status.

## Consequences

A run that ends *converged with deferrals* or *sound with record notes* now publishes its
lists in both places ADR 0021 and `$quest` step 6 name, with no workaround and no
silent drop. PR #160's step 6 text — "keep the list with the resume facts ... and report
it to whoever receives this run" — is replaced by the write. Issue #141's
orchestrator-composed body workaround is retired by machinery.

The annotation's outer structure gains one optional section. `$quest-log`'s
`WORK:REVIEW` payload-shape paragraph, which whole-line-anchored consumers rely on,
describes the section so a reader of that skill expects it; marker safety is unchanged,
because the payload is validated against whole-line outer markers before composition.

The helper's argument count changes from six to six-or-seven. Its usage string, its
disposal record, and `$quest` step 8's invocation all name the seventh argument, so a
caller that omits it publishes exactly what it published before this record.

Nothing validates the payload's *content* beyond byte safety — the helper cannot tell a
deferral list from any other prose, and anatomy rule 2 still forbids teaching it to. A
payload carrying the wrong lists publishes cleanly, the same exposure the summary's six
free-text fields already carry.

## Considered & rejected

**Widen the summary with list fields.** verified against ADR 0021: it already rejected
per-exit payload counts because two of three describe nothing on any given run, and the
lists themselves "do not fit a single-line field". The single-line contract is the
summary's value; this record leaves it fixed.

**Hand the payload to `$deliver` and let it compose the body with the lists at
creation.** This is issue #141's workaround made machinery. verified against
`skills/deliver/SKILL.md` step 2: the body "describes only what is in the diff" — review
payloads are not diff facts, and folding them into `$deliver` widens a second skill's
contract to close a `$quest` gap. It also leaves `$trial-loop`'s notes and claim list
without a comment destination, which is half the gap.

**Post the lists as a second comment after the helper.** verified against `$quest` step 8:
the helper "is the sole `WORK:REVIEW` writer", and a second comment would split the
annotation the readback verifies into two unverified pieces.

**Let the run edit the PR body after the helper succeeds.** verified against step 8's own
sequence: after a successful helper exit the next writes are the ledger disposal record
and the `publication-verified` handoff, and the handoff phase is terminal on every resume
— a body write parked there could never be retried or distinguished from a tampered body.
Writing before the terminal rewrite keeps every failure recoverable.
