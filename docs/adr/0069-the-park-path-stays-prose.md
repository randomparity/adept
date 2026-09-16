# 0069 — The park path stays prose

## Status

Accepted (2026-09-16)

## Context

ADR 0066 ships `publish-handoff` for the merge hand-off only, and records the park path's
sentinel-omission exposure in its Consequences as an accepted residual with no owner. Issue #380
files that residual as an enhancement; issue #381 asks this record to settle four questions —
shape, an unreachable handshake, the relaxed branch-state refusal, and `status:` label ownership —
and to re-argue CLAUDE.md anatomy rule 2 without the four logged failures 0066 stood on.

#381 states the park path has zero observed failures, so rule 2's *performed inconsistently* limb
is unavailable. That premise no longer holds. Issue #390 records a post-merge audit finding **all
five** hand-written tracking blocks on one issue missing the closing sentinel, while the one block
that worker did not hand-write — the pull request's `WORK:REVIEW`, emitted by
`publish-forge-review` — carried its marker correctly; a second worker's independent audit
reproduced the pattern on its own issue. The limb is therefore available, and this record decides
the question with it rather than around it.

What #390 indicts is hand composition as a class, on every `WORK:*` type, not the park path. That
distinction is what the decision turns on.

## Decision

**The park path stays prose.** No park composer ships: not a sibling executable, not a shared
composition unit inside `skills/return-to-town/scripts/publish-handoff` with a second entry point.
`$quest`'s *On a Blocker* path keeps composing its `WORK:TRAJECTORY` note and keeps owning the
`status:` swap that follows it.

**Rule 2, re-argued.** The bar is that a script does something a model cannot do reliably inline.
#390 establishes that a model cannot reliably emit a closing sentinel — that half is now settled
against prose. It does not establish that *this* script clears the bar, because the defect it
measures is not park-shaped. A park composer removes the omission from one of the five surfaces
#390 counted and leaves it on the other four, including `WORK:SCOPE`, which is the one surface
#390 records an actual consequence for: a `WORK:SCOPE` missing its sentinel made two workers
invisible to `$resurrection`'s liveness sweep for their entire runs. The change that reaches all
five is at the shared hand-write path every annotation already goes through, and CLAUDE.md's
*Cut before adding* puts extending that existing entry point ahead of a new executable. Rule 2's
second limb is available and the park composer still fails rule 2 — not for want of evidence, but
because it is not the shape the evidence indicts.

**Question 1, shape.** 0066's rejection of a `--kind` flag does not by itself foreclose a shared
unit with separate entry points: its ground was the flag as a call-site confusion surface, and two
entry points remove the flag. The shape fails on its own terms instead. What a park entry point
could share is the two marker constants, the narrative validation, and the post-and-readback;
`resolve_destination` and `resolve_head` — the closing-reference corroboration and the remote-tip
agreement — are inapplicable to a park, which may have no pull request and no branch at all.

**Question 2, the absent handshake.** Unreachable by construction means the handshake bytes are not
in the executable. A shared unit keeps them there, so "a park cannot acquire a handshake" reverts
to an invariant maintained by whoever next edits the shared unit — caller discipline moved one file
over, which is what #381 question 2 rules out. Only a separate executable satisfies it, and
question 1 already disposes of that one.

**Question 3, the relaxed refusal.** The refusal is wrong for a park: a moved branch is a thing you
might be parking about. But removing it, together with the closing-reference corroboration a
pull-request-less park cannot satisfy, leaves markers around a narrative plus a readback — the
shape 0066 rejected for a general `post-annotation` helper as two `printf` calls per call site,
here covering one call site rather than every one.

**Question 4, label ownership.** The park keeps both steps, note then label, in that order. A
composer posting the note and not the label leaves the operation half-owned and removes no ordering
requirement. A composer swapping the label acquires label-write authority `publish-handoff`
deliberately has none of, and introduces a note-posted/label-write-failed partial state that prose
does not have.

**0066's judgments.** Its decision survives unchanged, and its rejection of the `--kind` flag is
reinforced — question 2 extends the same ground to the shared-unit variant. Its rejection of a
general `post-annotation` helper survives as a rejection of a *helper*; the reasoning that the
remaining types "would gain markers-and-sentinel only" is weaker than 0066 read it, because #390
shows markers-and-sentinel is precisely what gets dropped. One Consequences sentence does not
survive: the park residual's stated recovery, "a reader recovers from by opening the issue".

## Consequences

- The park path keeps the sentinel-omission exposure, and it is now measured rather than
  hypothetical. That is the cost of this decision, stated plainly.
- The residual's severity is bounded by the label, not by a reader opening the issue.
  `$resurrection` step 4 lists parked work by `status:blocked`/`status:needs-human` and reads
  `WORK:TRAJECTORY` only for the parked-phase note, so a sentinel-less park note loses the phase
  detail while the parked state survives in a signal a sweep already reads. The hand-off has no
  such second signal — the merge gate reads bytes and nothing else says merge-ready. 0066 ordered
  the two exposures correctly; it named a weaker recovery mechanism than the one that holds, and
  the correction runs in its favour.
- Issue #390 owns the part that matters and covers the park call site along with every other
  hand-written annotation surface. This record and #390 are not in conflict: #390 fixes the
  instruction-shape defect whatever verdict this record reaches, and this record is why no park
  composer is filed beside it.
- Issue #380's two remaining children — the composer's build and its behaviour suite — are not
  built. Closing them as not planned against this record is the campaign orchestrator's action,
  not this record's.
- No executable ships, so anatomy rules 1 through 3 are untouched by this change.
- What would reopen the question: a park-specific omission observed after #390's fix lands, or one
  the label redundancy above does not cover. Either is new evidence this record did not have.

## Considered & rejected

- **A sibling executable beside `publish-handoff`.** verified: `publish-handoff` is 646 lines
  (`wc -l`, at commit `66617c4`), and its two largest checks — `resolve_destination`'s
  closing-reference corroboration and `resolve_head`'s remote-tip agreement — are both inapplicable
  to a park with no pull request and no branch. What survives is markers around a narrative and a
  readback, covering one call site.
- **A shared composition unit with hand-off and park entry points.** judgment: the handshake bytes
  stay in the shared unit, so the property #381 requires to hold by construction becomes one an
  editor must maintain.
- **Extending the composer to own the `status:` swap.** judgment: it takes label-write authority
  0066's helper deliberately withholds, and adds a partial state — note posted, label unwritten —
  that the prose path does not have.
- **Wait for a park-specific observed failure before deciding.** judgment: #380 already recorded
  this residual once with no owner, and deferring a filed enhancement back to the same wait is how
  a residual acquires a second record and still no owner.
- **Do nothing — leave the residual unowned, as 0066 did.** verified: issue #390 measures the
  omission on all five hand-written blocks of one issue, reproduced by a second worker's
  independent audit, and names the instruction shape as its cause. Doing nothing leaves that
  connection, and the owner it implies, unrecorded.
- **Supersede ADR 0066 rather than extend it.** verified: 0066's decision — compose only the
  hand-off, no mode flag, park stays prose — is what this record upholds; only one Consequences
  sentence about the residual's recovery is corrected. A supersession banner would tell a reader
  the hand-off helper's decision no longer governs, which is false.
