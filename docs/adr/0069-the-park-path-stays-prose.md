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

## Decision

**The park path stays prose.** No park composer ships: not a sibling executable, not a shared
composition unit inside `skills/return-to-town/scripts/publish-handoff` with a second entry point.
`$quest`'s *On a Blocker* path keeps composing its `WORK:TRAJECTORY` note and keeps owning the
`status:` swap that follows it.

**Rule 2, re-argued — and conceded.** The bar is that a script does something a model cannot do
reliably inline. #390 settles that against prose, and this record does not contest it: a model
cannot reliably emit a closing sentinel, the one well-formed block in its audit is the one a
program emitted, and the defect tracks hand composition rather than any one annotation type. A park
composer would clear the *performed inconsistently* limb. **Rule 2 is met, and it is not what
decides this.**

What decides it is the rung above rule 2. CLAUDE.md's *Cut before adding* asks whether the thing is
already in the codebase before it asks for new surface, and it is: every hand-composed block goes
through quest-log's annotation recipe, so a check placed there reaches the park path and every
other hand-written type at once. Issue #390 owns that recipe and is fixing it. A park composer
would add an executable to close on one call site a defect a change to shared instructions closes
on all of them — and both would then be live, with the composer's own call site the only one
covered twice. That ground is stronger than a rule-2 argument would have been, because it does not
depend on how the observed instances happened to be distributed.

**Question 1, shape.** 0066 rejected a `--kind` flag on reachability: a park note that acquired a
handshake would authorize a merge of parked work, and the flag was "the only way that becomes
reachable". Separate entry points meet that ground rather than dodging it — a park entry point that
never calls the compose step leaves the handshake unreachable with no flag to set wrongly — so the
rejection does not carry over. Nor does the shared surface argue against it: `resolve_destination`
and `resolve_head` are 132 of 646 lines, while the narrative validation, the bounded network calls
ADR 0068 requires of every caller, the public-safety scan, and the whole-line assertions against
the stored body are all park-applicable. **If a composer were warranted, the shared unit is the
shape** — which is why no shape question decides this record.

**Question 2, the absent handshake.** It does not discriminate between the composer shapes: the
park entry point above, a separate executable holding no handshake bytes, and a validator that
composes nothing all satisfy it. What must be said plainly is that **prose, the shape adopted here,
is the one shape that does not.** Under prose the handshake's absence is held by instruction, which
is the caller discipline #381 rules out. Two things bound that without removing it: the merge gate's
part-4 selection requires a `MERGE-READY` line for `HEAD_SHA`, so a park note lacking one cannot
authorize a merge, and a park note acquiring one would have to be composed deliberately rather than
omitted by accident — the opposite of the only failure direction #390 measures. That is a bound,
not the guarantee #381 asked for, and the gap is recorded below.

**Question 3, the relaxed refusal.** The refusal is wrong for a park and would have to go: a moved
branch is a thing you might be parking about, and a park may have no branch at all. That is a
change to make if a composer is ever built, not a reason to build one.

**Question 4, label ownership.** The caller keeps both steps, note then label, in that order. The
note-posted/label-unwritten window is not a composer's to create or remove: the prose path already
has it, and `skills/quest/SKILL.md` records the consequence — a sweep re-labels such an issue as in
flight, because the label is the only thing that says parked. A composer posting only the note
leaves that window as it is; one swapping the label would take label-write authority 0066's helper
withholds and merely move the window between its own two writes.

**0066's judgments.** Its decision survives unchanged, and its `--kind` rejection survives on its
own reachability ground — question 1 gives the reason separate entry points do not inherit it. Its
rejection of a general `post-annotation` helper survives as a rejection of a *helper*, though the
reasoning that the other types "would gain markers-and-sentinel only" is weaker than 0066 read it:
#390 shows markers-and-sentinel is precisely what gets dropped. One Consequences sentence does not
survive — the park residual's stated recovery, "a reader recovers from by opening the issue".

## Consequences

- **The park path keeps the sentinel-omission exposure, and only half of it is bounded.** That is
  the cost of this decision, stated plainly. In an ordinary park the label bounds the *state*:
  `$resurrection` step 4 lists parked work by `status:blocked`/`status:needs-human`. The note fails
  worse than "missing" — quest-log's latest-complete recipe selects on both markers and takes
  `last`, so a sentinel-less park note is filtered out and the newest *earlier* complete block, a
  stale hand-off or a previous park, is handed back as current. That is a wrong answer, not an
  absent one. In an interrupted park — note posted, worker gone before the label swap — there is no
  label either, `skills/quest/SKILL.md` says the sweep re-labels that issue as in flight, and the
  misleading note is the only record. That window is unbounded, and 0066 named no recovery for it.
- **Whether the residual closes depends on which fix #390 lands.** Its *Fix directions* offer either
  or both; its *Acceptance* requires both, including write-time detection, which would close this
  exposure for the park and every other hand-written type. A worked-example fix alone narrows it and
  leaves the interrupted-park window. #390 shipping short of its own acceptance is what reopens this
  question, and #380 — which filed this residual — stays its record until then. The two are not in
  conflict: #390 fixes the instruction shape whatever verdict this record reaches, and this record
  is why no park composer is filed beside it.
- Issue #380's two remaining children — the composer's build and its behaviour suite — are not
  built. Closing them as not planned against this record is the campaign orchestrator's action.
- **#381's question 2 is answered "no" for the adopted shape, and that is a real gap.** Prose holds
  the absent handshake by instruction, not by construction — the one requirement this record
  declines rather than meets. It is the strongest argument against this verdict, and a reader
  weighing a future park composer should start there.
- **Extending rather than superseding leaves no forward pointer on 0066.** This repository's ADR
  convention makes a `Superseded by` banner the only edit a merged record permits — a convention,
  not a gate rule, since `check-records.sh` excludes `## Status` from its append-only comparison.
  The corrected sentence therefore stays in place. Accepted: the banner would falsely claim 0066's
  decision no longer governs.
- No executable ships, so anatomy rules 1 through 3 are untouched by this change.

## Considered & rejected

- **A sibling executable beside `publish-handoff`.** verified: `wc -l` gives 646 lines at commit
  `66617c4`, of which `resolve_destination` and `resolve_head` are 132, leaving 646 − 132 = 514 a
  sibling could not share. Not all 514 is park-applicable — the compose step and its handshake
  assertions sit inside it and question 1 excludes them — but a sibling duplicates the reusable part
  a shared unit would have reused. The worse of the two composer shapes, on a decision declining both.
- **A shared composition unit with hand-off and park entry points.** judgment: the better composer
  shape, rejected because this record declines a composer on the ground stated in the Decision —
  not on anything about the shape. A future record reversing this one should start from it.
- **A park-side validator the caller runs against a body it composed.** judgment: it is #390's own
  second fix direction scoped to one call site, and #390 can apply the same check at the shared
  hand-write path for every type at no greater cost. 0066's prevention-over-detection ground is
  weaker here — this record ships no composer — so the narrower scope is what sinks it.
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
