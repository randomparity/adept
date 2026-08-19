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
findings still stand that the reviewer did not clear — that is what each exit is for, and `:594`
states the mechanism: the reviewer "cannot return `approve` while a defensible finding stands".
So all three carry `needs-attention`, bar one case — *converged on own surface* ends on a
confirming pass that may return none — and a run that ended in a distinct non-blocking exit
publishes `verdict: needs-attention` and nothing else, which reads as the opposite of what
happened.

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
on the branch, the one `findings:` and `iterations:` already count. `verdict:` is unchanged in
meaning and stays the verdict the selected reviewer actually returned on the last pass, never a
value derived from the exit; `exit:` records how the loop ended. Overloading one field with both
would erase the only record of whether a reviewer ever cleared the branch.

**`exit:` takes exactly one of five values**, one per way a `$trial-loop` run can reach step 8:

| `$trial-loop` run ending | `exit:` | `verdict:` observed | run was blocked |
|---|---|---|---|
| the reviewer returned `approve`, having taken no named exit | `none` | `approve` | no |
| *converged with deferrals* | `converged-with-deferrals` | `needs-attention` | no |
| *sound with record notes* | `sound-with-record-notes` | `needs-attention` | no |
| *converged on own surface* | `converged-on-own-surface` | `needs-attention`, or `approve` when its confirming pass returns none | no |
| stopped as blocked at the iteration budget, then continued on explicit human approval | `blocked-at-budget` | `needs-attention` | yes |

**A named exit outranks `none`** wherever a run matches both rows. The overlap is real: a
*converged on own surface* run ends on a confirming pass that may return `approve`
(`skills/trial-loop/SKILL.md:697-701`), and writing `none` there would discard the fact that the
loop reached the exit by reviewing its own output. So `none` is written only for a run that
ended on the approve bullet having taken no named exit, and that row is the only one where
`exit:` and `verdict:` carry the same news.

The fifth row is the only path by which a blocked run reaches this contract: cap exhaustion
stops the workflow, but only "without explicit user approval" (`:654-657`). `$quest` documents
no such resume today — issue #151 — so **`blocked-at-budget` may not be written until it does**,
and until then a run stopped at the budget parks and publishes no summary at all. The value is
fixed here so the change that adds the path has one to use rather than minting its own. Every
other stop ends the run without publishing, rescoping without new authority included
(`:665-667`, `:713-716`).

**The run `exit:` describes is the last `$trial-loop` run on the branch** — the same run
`verdict:`, `findings:` and `iterations:` describe. A `$gauntlet`-only re-review, which step 7
permits after simplification (`skills/quest/SKILL.md:524-531`), is not a loop run: it produces
no exit and leaves `exit:` as the last loop run set it. A step 6 or step 7 re-entry that *is* a
full loop run replaces all four fields together, `none` included.

**ADR 0011 governs this vocabulary, and this is its discharge.** That record permits a domain
enum only where its contract states an explicit one-way conversion to the canonical vocabulary
and says the domain value is neither a finding severity nor a review verdict. The table's third
column is that conversion, one row per member and one way only, into the `approve |
needs-attention` vocabulary 0011 names; `verdict:` carries that value directly, so a consumer
reads it rather than deriving it, and the fourth column is the separate routing fact 0011's
`blocked` reservation clause governs. An `exit:` value is neither a finding severity nor a
review verdict, and `blocked-at-budget` is qualified rather than a bare `blocked` for that same
clause's reason.

**The exits' payloads stay out of the summary.** Deferral records with their owning paths,
outstanding notes with the finding each came from, and the claim list marked confirmed, refuted
or not-checkable-here go to the `WORK:REVIEW` comment and the pull request body, which is where
`$trial-loop`'s own report obligation (`:741-754`) and ADR 0020 already send them. Those are
unbounded multi-line lists; this artifact is a capped, single-line-field header. `exit:` tells a
reader which of the named exits' payloads to expect below; a `none` run may still carry a
deferral list, because `$trial-loop` discloses those on every exit.

## Consequences

A reader of a published `WORK:REVIEW` can now tell a branch that stopped on an unresolved
finding from one that took a named non-blocking exit, without reading the forge review below
it. `verdict: needs-attention` alone no longer carries that whole question.

Nothing validates the field list, before or after this change. A summary written with five
fields, or carrying an `exit:` value outside the five, still publishes: the consequence is a
misleading published artifact rather than a failed publication, one field wider than before and
the same exposure the other five already carry.

`$bards-tale` is the one machine consumer that carries a summary field forward. Its step 3d
(`skills/bards-tale/SKILL.md:202-213`) reads the latest complete `WORK:REVIEW` block for the
iteration count and carries the verdict into its narrative, so until it reads `exit:` too a
retrospective still narrates a named exit as blocked. Filed as issue #149;
`skills/bards-tale/SKILL.md` is outside this change's surface. That issue also owns the reading
of the summaries already published, which carry five fields and no `exit:` line: absence is not
`none` — such a summary says nothing about how its run ended. Nothing rewrites a published
annotation.

Adding a second field to a fixed-shape contract sets the precedent that the summary grows one
scalar at a time. This record accepted that cost for one field.

`$quest` step 6 still routes only on `approve`, *sound with record notes*, and blocked. This
record fixes what a caller writes in `exit:` for *converged with deferrals* and *converged on own
surface*, so issue #141 can add the step 6 routing for those two without reopening the field set.

## Considered & rejected

**Do nothing — keep the five-field contract and leave the exit name to the annotation prose.**
This is #138's workaround, recorded at `skills/quest/SKILL.md:432-436`.
verified: the summary is consumed field by field, not only as prose. `$bards-tale` step 3d
extracts the iteration count and the verdict out of the block by name
(`skills/bards-tale/SKILL.md:202-213`), so an exit named only in the prose beside the summary is
not where a field-reading consumer looks. Do-nothing leaves that consumer nothing to read for
the one fact the exit exists to carry.

**Qualify `verdict:` instead — write `needs-attention (sound with record notes)`.** This is the
smallest change that fits the reported problem and needs no new field.
verified against `docs/adr/0011-canonical-workflow-review-vocabulary.md`: that record makes
`approve | needs-attention` the cross-workflow review verdict, and a qualified value is no
longer one of the two. It also stops being comparable between runs — the same field would hold a
bare word on some and a word-plus-parenthetical on others — which is the property `$bards-tale`
depends on when it carries the verdict forward. A second field costs one line and keeps both
values canonical.

**Write the exit name into `verdict:`, replacing the reviewer's verdict.** verified against
`skills/trial-loop/SKILL.md:746-748`, the report obligation: the run reports "the final verdict"
and, for *sound with record notes*, also says so "by that name" — the exit accompanies the
verdict rather than replacing it. Collapsing them destroys the only field saying
whether a reviewer ever returned `approve`, and leaves ADR 0011's canonical verdict unwritten.

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
`skills/quest/SKILL.md` — the drift the repo removes elsewhere. That argument binds this record
too: `skills/quest/SKILL.md:543-544` enumerates the five members again in prose, and the
implementation stops it enumerating rather than adding `exit:` to it, so the contract block stays
the one place. Declined; the check the helper does own is whether the bytes are safe to publish,
which is a different question.

**Allow `exit:` to be omitted when the run ended on `approve`.** verified:
`skills/quest/SKILL.md:558-560` requires "these exact, non-empty single-line fields in order",
and an optional field breaks that invariant for every reader and for any future check. `none`
costs one line and keeps the shape fixed.
