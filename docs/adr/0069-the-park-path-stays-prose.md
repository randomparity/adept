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

What #390 indicts is hand composition as a class, across quest-log's annotation types. That
distinction is what the decision turns on.

## Decision

**The park path stays prose.** No park composer ships: not a sibling executable, not a shared
composition unit inside `skills/return-to-town/scripts/publish-handoff` with a second entry point.
`$quest`'s *On a Blocker* path keeps composing its `WORK:TRAJECTORY` note and keeps owning the
`status:` swap that follows it.

**Rule 2, re-argued.** The bar is that a script does something a model cannot do reliably inline.
#390 settles that half against prose: a model cannot reliably emit a closing sentinel, and the one
well-formed block in the audit is the one a program emitted. What it does not establish is that a
*park* composer clears the bar, and the audit is where that shows. Its five blocks are five blocks
on one issue, not five annotation types, and the `WORK:TRAJECTORY` among them was a hand-off, not a
park. A park composer would have corrected none of them. The measured instances are spread across
whatever types a worker hand-writes, so the change that reaches them is at the hand-write path
those types share, and CLAUDE.md's *Cut before adding* puts extending that existing surface ahead
of a new executable.

The audit carries a second fact that decides it. Those hand-off blocks were hand-written **after**
`publish-handoff` shipped — a composer existed for exactly that block and the workers composed by
hand anyway. Shipping a composer therefore does not by itself stop hand composition; what governs
whether one is reached for is the instruction shape, which is #390's to fix. A park composer would
be bypassed the same way, on a path with fewer instances to begin with. Rule 2's second limb is
available and a park composer still fails rule 2 — not for want of evidence, but because it is not
the shape the evidence indicts.

**Question 1, shape.** 0066's rejection of a `--kind` flag does not by itself foreclose a shared
unit with separate entry points: its ground was the flag as a call-site confusion surface, and two
entry points remove the flag. The shape fails on what would be left to share. A park entry point
could reuse the two marker constants, the narrative validation, and the post-and-readback;
`resolve_destination` and `resolve_head` — the closing-reference corroboration and the remote-tip
agreement — are inapplicable to a park, which may have no pull request and no branch at all. A
shared unit whose shared part is two constants and a readback is not worth the coupling.

**Question 2, the absent handshake.** This question does not discriminate between the shapes, and
saying so is more useful than forcing it to. A park entry point that never calls the hand-off's
compose step cannot emit a handshake, which is a control-flow property rather than caller
discipline; a separate executable containing no handshake bytes satisfies it too; and a validator
that composes nothing carries no handshake to begin with. All three meet #381's requirement.
Question 1 is what eliminates the shared unit, and the bullets below eliminate the rest.

**Question 3, the relaxed refusal.** The refusal is wrong for a park: a moved branch is a thing you
might be parking about. But removing it, together with the closing-reference corroboration a
pull-request-less park cannot satisfy, leaves markers around a narrative plus a readback — the
shape 0066 rejected for a general `post-annotation` helper as two `printf` calls per call site,
here covering one call site rather than every one.

**Question 4, label ownership.** The caller keeps both steps, note then label, in that order. The
note-posted/label-unwritten window is not something a composer creates or removes: the prose path
already has it, and `skills/quest/SKILL.md` records its consequence — a sweep re-labels such an
issue as in flight, because the label is the only thing that says parked. A composer posting only
the note leaves that window exactly as it is. A composer swapping the label would take label-write
authority 0066's helper deliberately withholds, and would move the window rather than close it, to
between the two writes it now owns.

**0066's judgments.** Its decision survives unchanged, and its rejection of the `--kind` flag
survives on its own call-site ground. Its rejection of a general `post-annotation` helper survives
as a rejection of a *helper*; the reasoning that the remaining types "would gain
markers-and-sentinel only" is weaker than 0066 read it, because #390 shows markers-and-sentinel is
precisely what gets dropped. One Consequences sentence does not survive: the park residual's stated
recovery, "a reader recovers from by opening the issue".

## Consequences

- The park path keeps the sentinel-omission exposure. That is the cost of this decision, stated
  plainly.
- **The exposure has two shapes and only one is bounded.** In an ordinary park the label bounds it:
  `$resurrection` step 4 lists parked work by `status:blocked`/`status:needs-human` and reads
  `WORK:TRAJECTORY` only for the parked-phase note, so a sentinel-less note loses the phase detail
  while the parked state survives in a signal a sweep already reads. In an interrupted park — note
  posted, worker gone before the label swap — there is no label, `skills/quest/SKILL.md` says the
  sweep re-labels that issue as in flight, and a sentinel-less note is then the only record and
  unreadable. That window is real and unbounded, and it is the residual's true shape. 0066 named a
  recovery weaker than the bounded case and no recovery at all for this one.
- **Whether the residual closes depends on which fix #390 lands.** Its *Fix directions* offer either
  or both; its *Acceptance* requires both, including write-time detection. Meeting that acceptance
  closes this exposure for the park along with every other hand-written type; a worked-example fix
  alone narrows it, leaving the interrupted-park window. #390 shipping short of its own acceptance is
  what reopens this question, and #380 — which filed this residual — stays its record until then.
- Issue #390 owns the defect and covers the park call site along with every other hand-written
  surface. This record and #390 are not in conflict: #390 fixes the instruction shape whatever
  verdict this record reaches, and this record is why no park composer is filed beside it.
- Issue #380's two remaining children — the composer's build and its behaviour suite — are not
  built. Closing them as not planned against this record is the campaign orchestrator's action.
- **Extending rather than superseding leaves no forward pointer on 0066.** The adr profile accepts
  only a `Superseded by` banner in a merged record's Status, so the sentence corrected here stays
  uncorrected in place and a reader reaching 0066 first is not sent on. Accepted: the banner would
  falsely claim 0066's hand-off decision no longer governs.
- No executable ships, so anatomy rules 1 through 3 are untouched by this change.

## Considered & rejected

- **A sibling executable beside `publish-handoff`.** verified: `publish-handoff` is 646 lines
  (`wc -l`, at commit `66617c4`), and its two largest functions — `resolve_destination`'s
  closing-reference corroboration and `resolve_head`'s remote-tip agreement — are both inapplicable
  to a park with no pull request and no branch. What survives is markers around a narrative and a
  readback, for one call site.
- **A shared composition unit with hand-off and park entry points.** judgment: question 1's
  remainder is the whole objection — two constants and a readback do not earn a shared unit.
- **A park-side validator the caller runs against a body it composed.** judgment: it is #390's own
  second fix direction scoped to one call site, and #390 can apply the same check at the shared
  hand-write path for every type at no greater cost. 0066 rejected a validator on
  prevention-over-detection grounds; that ground is weaker here, because this record ships no
  composer for detection to be measured against, and the narrower scope is what sinks it.
- **Extending the composer to own the `status:` swap.** judgment: it takes label-write authority
  0066's helper withholds, and relocates the unwritten-label window rather than closing it.
- **Wait for a park-specific observed failure before deciding.** judgment: #380 already recorded
  this residual once with no owner, and deferring a filed enhancement back to the same wait is how
  a residual acquires a second record and still no owner.
- **Do nothing — leave the residual unowned, as 0066 did.** verified: #390 measures the omission on
  all five hand-written blocks of one issue, reproduced by a second worker's independent audit, and
  names the instruction shape as its cause. Doing nothing leaves that connection unrecorded.
- **Supersede ADR 0066 rather than extend it.** verified: 0066's decision — compose only the
  hand-off, no mode flag, park stays prose — is what this record upholds, and only one Consequences
  sentence is corrected, so the banner would say something false.
