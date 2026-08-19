# The review summary names the `$trial-loop` exit — design

Issue: randomparity/adept#143. Decision record:
`docs/adr/0021-review-summary-names-the-trial-loop-exit.md`.
Serial successor: #141, which adds `$quest` step 6 routing for two of the exits named here.

Every `skills/` line citation below is at `ea43def`, this change's merge-base with `main`.

## Problem

`$quest` step 8 writes a durable public review summary — five exact, non-empty, single-line
fields in order (`skills/quest/SKILL.md:562-568`) — and hands it to
`skills/quest/scripts/publish-forge-review`, which makes it the head of the published
`WORK:REVIEW` annotation. `verdict:` is specified as `<trial-loop verdict>`.

`$trial-loop` has three run outcomes that are not verdicts: *converged with deferrals*
(`skills/trial-loop/SKILL.md:596`), *sound with record notes* (`:646`), and *converged on own
surface* (`:697-698`). Each must be reported distinctly, and on each the reviewer's last verdict
is `needs-attention`. So a run ending in a distinct non-blocking exit publishes
`verdict: needs-attention` alone, which reads as the opposite of what happened, and the exits'
payloads have no field to occupy.

Nothing catches it: `validate_content`
(`skills/quest/scripts/publish-forge-review:151-181`) checks file mode, size, UTF-8, NUL, CR and
outer markers, and `compose_body:190` then `cat`s the summary verbatim.

ADR 0020 deferred the decision to this issue rather than making it; ADR 0016 governs the
publication mechanism, not the field set.

## Requirements

Sourced from #143's *What would resolve it* and the frozen `WORK:SCOPE` on that issue.

1. An accepted record fixes the field set, says whether `verdict:` keeps the reviewer verdict,
   and says what a caller writes for each named `$trial-loop` exit — including the two #141
   covers.
2. `skills/quest/SKILL.md` states the contract in one place.
3. Step 6's paragraph at `:432-436`, which describes the workaround and points at this issue as
   tracked separately, describes the landed behaviour instead.
4. The write discipline is unchanged: exact non-empty single-line fields in order, byte-for-byte
   readback before rename, mode 0600.
5. A run ending in any of the three named exits publishes a summary that says so.
6. Whether `validate_content` gains a field-list check is decided, not assumed, and any new
   executable surface clears anatomy rule 2.
7. `just verify` passes, `just records` included.
8. No automated gate asserts on the new prose (anatomy rule 4).

## Design

The decision and its rejected alternatives live in ADR 0021 and are not restated here. What the
implementation has to produce:

**One added field.** The contract becomes six fields, `exit:` second:

```text
verdict: <trial-loop reviewer verdict>
exit: <trial-loop run outcome, or none>
findings: <count>
iterations: <count>
security: <$detect-evil verdict or not triggered>
delivered-head-sha: <full exact delivered PR head SHA>
```

`verdict:` is unchanged in meaning — the reviewer's last verdict on the last `$trial-loop` run,
the run `findings:` and `iterations:` already count.

**Five permitted `exit:` values**, one per way a run can reach step 8:

| run ending | `exit:` | `verdict:` observed | blocked |
|---|---|---|---|
| reviewer returned `approve`, no named exit | `none` | `approve` | no |
| *converged with deferrals* | `converged-with-deferrals` | `needs-attention` | no |
| *sound with record notes* | `sound-with-record-notes` | `needs-attention` | no |
| *converged on own surface* | `converged-on-own-surface` | `needs-attention`, or `approve` on a clean confirming pass | no |
| blocked at the iteration budget, continued on explicit human approval | `blocked-at-budget` | `needs-attention` | yes |

A named exit outranks `none` wherever both rows match. `blocked-at-budget` may not be written
until `$quest` documents the resume path (issue #151); until then such a run parks and publishes
nothing. Only the `exit:` column is prescribed; `verdict:` is whatever the reviewer returned.
Every other stop parks the issue before `$deliver` rather than publishing. The run described is
the last `$trial-loop` run on the branch — the one `verdict:`, `findings:` and `iterations:`
already describe; a step 7 `$gauntlet`-only re-review is not a loop run and changes none of them.

**Payloads stay out.** Deferral records with owning paths, outstanding notes with their
findings, and the confirmed/refuted/not-checkable claim list continue to the `WORK:REVIEW` body
and the pull request description. They are unbounded multi-line lists; the summary is a capped
single-line-field header.

**No new executable surface.** `validate_content` is unchanged, so
`skills/quest/scripts/publish-forge-review` and `tests/fixtures/quest/publish-forge-review-test.sh`
are untouched. Rationale is ADR 0021's rejection of the field-list check.

**`skills/quest-log/SKILL.md` is untouched.** Its `WORK:REVIEW` payload shape at `:299-309`
describes the annotation's outer structure — summary first, then `## Forge whole-branch review`
indented four spaces — and names no summary field. Adding a field inside the summary does not
change what that section describes.

## Files changed

| file | change |
|---|---|
| `docs/adr/0021-review-summary-names-the-trial-loop-exit.md` | new — the decision |
| `skills/quest/SKILL.md` | *Ship It*: the six-field block, the `exit:` value list, and `:543-544`'s prose enumeration of the members (stops enumerating, points at the block); step 6: replace the workaround paragraph |
| `docs/workflow/specs/2026-08-18-review-summary-named-exit-design.md` | this file |
| `docs/workflow/plans/2026-08-18-review-summary-named-exit.md` | the implementation plan |

## Out of scope

- `$quest` step 6 routing for *converged with deferrals* and *converged on own surface* — issue
  #141, dispatched after this merges. This change fixes what those two write in `exit:`; it adds
  no routing prose for them.
- `$trial-loop`'s exits and report obligations — unchanged.
- The `WORK:REVIEW` annotation's outer payload shape — ADR 0016.
- Teaching `$bards-tale` step 3d to read `exit:` — issue #149, filed during this change's ADR
  review. Until then a retrospective narrates a named exit as blocked.

## Verification

`just verify` in the worktree, bare. `just records` is the gate that reads the new ADR: it
requires the five level-2 sections, a `## Status` body of `Accepted (YYYY-MM-DD)`, and an H1
beginning `# 0021 `. The ADR-index policy here is `directory` — `docs/adr/README.md` carries no
index table and the gate warns (`W-INDEX-TABLE`) if one appears, so no index row is added.

No test asserts on the new prose, per anatomy rule 4. The behaviour this change alters is what a
model writes into a runtime artifact, which no gate in this repo inspects — the same enforcement
posture the other five fields have always had, recorded as a residual in ADR 0021's Consequences.
