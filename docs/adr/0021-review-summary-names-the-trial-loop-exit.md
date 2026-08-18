# 0021 — The review summary names the `$trial-loop` exit

## Status

Accepted (2026-08-18)

## Context

**Every `skills/` line citation in this record is at `ea43def`**, the merge-base of the change
that introduced it. That commit is where each ground was checked; the change itself moves lines
in `skills/quest/SKILL.md`, so a citation read against a later `HEAD` will not land.

`$quest` step 8 writes a durable public review summary before invoking its publication helper.
It is a fixed contract of five exact, non-empty, single-line fields in order
(`skills/quest/SKILL.md:562-568`): `verdict`, `findings`, `iterations`, `security`,
`delivered-head-sha`. `verdict:` is specified as `<trial-loop verdict>`. The summary becomes the
head of the published `WORK:REVIEW` annotation, above the indented forge review
(`skills/quest-log/SKILL.md:299-309`).

`$trial-loop` has run outcomes that are not verdicts. *converged with deferrals*
(`skills/trial-loop/SKILL.md:593-596`), *sound with record notes* (`:645-653`), and *converged
on own surface* (`:697-705`) are each required to be reported distinctly. Each fires while
findings still stand that the reviewer did not clear — that is what each exit is for — so the
last reviewer verdict on all three is ordinarily `needs-attention`; the loop's caller contract
states it outright for *sound with record notes* (`:762-763`). So a run that ended in a distinct
non-blocking exit publishes `verdict: needs-attention` and nothing else, which reads as the
opposite of what happened.

Nothing catches it. `validate_content` in `skills/quest/scripts/publish-forge-review:151-181`
checks the summary's file mode, size, UTF-8 validity, NUL and CR bytes, and outer annotation
markers; `compose_body:183-190` then `cat`s the file verbatim. The helper never parses the
summary, so a summary missing a field publishes cleanly.

ADR 0020 hit this and declined to decide it: its Consequences record that the exit's note and
claim lists reach the annotation and the pull request body but "not the `$quest` review summary:
that is a fixed five-field single-line contract with no member for either list, and widening it
is issue #143." No accepted record governs the field set. ADR 0016 governs the publication
mechanism, not what the summary says.

## Decision

**The summary gains one field, `exit:`, and `verdict:` keeps the reviewer's verdict.** The
contract becomes six exact, non-empty, single-line fields in order, with `exit:` second:

```text
verdict: <trial-loop reviewer verdict>
exit: <trial-loop run outcome, or none>
findings: <count>
iterations: <count>
security: <$detect-evil verdict or not triggered>
delivered-head-sha: <full exact delivered PR head SHA>
```

`verdict:` and `exit:` are two different facts about the same `$trial-loop` run — the last run
on the branch, the one `findings:` and `iterations:` already count. `verdict:` records what the
selected reviewer returned; `exit:` records how the loop ended. Overloading one field with both
would erase the only record of whether a reviewer ever cleared the branch.

**`exit:` takes exactly one of five values**, one per way a `$trial-loop` run can reach step 8:

| `$trial-loop` run ending | `exit:` | `verdict:` observed |
|---|---|---|
| the reviewer returned `approve` | `none` | `approve` |
| *converged with deferrals* | `converged-with-deferrals` | `needs-attention` |
| *sound with record notes* | `sound-with-record-notes` | `needs-attention` |
| *converged on own surface* | `converged-on-own-surface` | `needs-attention` or `approve` |
| stopped as blocked at the iteration budget, and a human explicitly approved continuing | `blocked-at-budget` | `needs-attention` |

**Only the `exit:` column is prescribed.** `verdict:` is always the verdict the selected
reviewer actually returned on the last pass, never a value derived from the exit; the third
column records what that verdict is on a typical run of each row, so a caller who observes
something else writes what it observed. *converged on own surface* is the row where that
matters: its confirming pass may return no finding at all (`skills/trial-loop/SKILL.md:697-701`),
and a run routed there whose confirming pass returns `approve` writes `verdict: approve` beside
`exit: converged-on-own-surface`.

The fifth row is the one path by which a blocked run reaches this contract. Cap exhaustion stops
the workflow, but only "without explicit user approval" (`:654-657`), so an approved
continuation runs on to `$deliver` and must be able to say so — that is precisely the run whose
`verdict: needs-attention` means what it says. Every other stop parks the issue instead of
publishing: `$quest`'s blocker path (`skills/quest/SKILL.md:626-642`) takes an unresolvable
finding to `status:needs-human`, and ending a cycle for rescoping without new authority ends the
run there (`skills/trial-loop/SKILL.md:665-667`, `:713-716`).

`none` rather than `approve` in the first row: the field answers "did the run take a named
exit", and repeating the verdict there would make the two fields look like one fact stated
twice.

**ADR 0011 governs this vocabulary, and this is its discharge.** That record permits a domain
enum only where its contract states an explicit one-way conversion to the canonical vocabulary
and says the domain value is neither a finding severity nor a review verdict. The table above is
that conversion — every `exit:` value maps to the `verdict:` beside it and never the reverse —
and an `exit:` value is neither a severity nor a verdict. `blocked-at-budget` is written
qualified rather than as a bare `blocked` for the same record's reason.

**The exits' payloads stay out of the summary.** Deferral records with their owning paths,
outstanding notes with the finding each came from, and the claim list marked confirmed, refuted
or not-checkable-here go to the `WORK:REVIEW` comment and the pull request body, which is where
`$trial-loop`'s own report obligation (`:741-754`) and ADR 0020 already send them. Those are
unbounded multi-line lists; this artifact is a capped, single-line-field header. `exit:` is the
routing key that tells a reader which list to expect below it.

**`validate_content` does not gain a field-list check.** The helper is declined new executable
surface here; see the rejection below.

## Consequences

A reader of a published `WORK:REVIEW` can now tell a branch that stopped on an unresolved
finding from one that took a named non-blocking exit, without reading the forge review below
it. `verdict: needs-attention` alone no longer carries that whole question.

Nothing validates the field list, before or after this change. A summary written with five
fields, or carrying an `exit:` value outside the five, still publishes; the byte-for-byte
readback proves the file is what was written, not that it is well formed, and the consequence
is a misleading published artifact rather than a failed publication. That gap is one field
wider than it was, and it is the same exposure the other five fields already carry. Accepted:
the write is a single act by the same agent that read the contract two steps earlier, and
closing it means a parser in the helper (rejected below).

`$bards-tale` is the one machine consumer that carries a summary field forward. Its step 3d
(`skills/bards-tale/SKILL.md:202-213`) reads the latest complete `WORK:REVIEW` block for the
iteration count and carries the verdict into its narrative, so until it reads `exit:` too a
retrospective still narrates a named exit as blocked. Filed as issue #149;
`skills/bards-tale/SKILL.md` is outside this change's surface. `$campaign`'s merge step reads
the same summary (`skills/campaign/SKILL.md`, step 6) but as a human-read hold decision, which
`exit:` helps rather than misleads.

Adding a second field to a fixed-shape contract sets the precedent that the summary grows one
scalar at a time. The bound this record leaves for the next such request is the one it applied
to itself: a field earns a place here when it is a single token that changes how a reader routes,
and it does not when it is a list or a per-exit quantity.

The named exits' payloads now have exactly one home — the annotation body and the pull request
description — and nothing checks that a run naming an exit in `exit:` actually carried the
corresponding list there. That is the same disclosure-not-a-gate bound ADR 0020 records for the
exit itself, and the price of anatomy rule 4.

`$quest` step 6 still routes only on `approve`, *sound with record notes*, and blocked. This
record fixes what a caller writes in `exit:` for *converged with deferrals* and *converged on own
surface*, so issue #141 can add the step 6 routing for those two without reopening the field set.

## Considered & rejected

**Do nothing — keep the five-field contract and leave the exit name to the annotation prose.**
This is #138's workaround, recorded at `skills/quest/SKILL.md:432-436`.
verified: the summary is read on its own, not only as the head of a whole annotation.
`$campaign`'s merge step reads "the
PR body, its acceptance criteria, and the `WORK:REVIEW` summary" when deciding a hold
(`skills/campaign/SKILL.md`, step 6), and `$bards-tale` step 3d extracts fields straight out of
the block for its narrative (`skills/bards-tale/SKILL.md:202-213`). A summary whose one outcome
field contradicts the run is a defect the prose below it does not reach either reader.

**Write the exit name into `verdict:`, replacing the reviewer's verdict.** verified against
`skills/trial-loop/SKILL.md:645-653` and `:762-763`: a named exit is reported *in addition to*
the reviewer's last verdict, not instead of it. Collapsing them destroys the only field saying
whether a reviewer ever returned `approve`, makes `verdict:` non-comparable between two runs
that both wrote it, and — on the *converged on own surface* row, where the confirming pass may
return `approve` — would overwrite a genuine clearance with an exit name.

**Add per-exit payload counts — a notes count, a claims count, a deferral-record count.**
judgment: shape. Each applies to exactly one exit, so on any given run two of the three describe
nothing, while "exact non-empty single-line fields in order" requires all three to be written
anyway. A single generic count instead would name three different quantities depending on the
exit, which is worse than no count. And the counts are not what a reader needs — the lists are,
and they do not fit a single-line field.

**Give `validate_content` a field-list check.** verified: the helper does not parse the summary
at any point — `validate_content:151-181` checks bytes and file mode, `compose_body:190` `cat`s
the file — so this means teaching it to parse a format it otherwise only copies, plus the suite
that new branch needs. Anatomy rule 2 permits a script only where a model cannot do the thing
reliably inline, and writing six named lines from a contract read two steps earlier is not that.
It would also put the field list in a second place, to be kept in step with this record and with
`skills/quest/SKILL.md` — the drift the repo removes elsewhere. Declined; the check the helper
does own is whether the bytes are safe to publish, which is a different question.

**Allow `exit:` to be omitted when the run ended on `approve`.** verified:
`skills/quest/SKILL.md:558-560` requires "these exact, non-empty single-line fields in order",
and an optional field breaks that invariant for every reader and for any future check. `none`
costs one line and keeps the shape fixed.
