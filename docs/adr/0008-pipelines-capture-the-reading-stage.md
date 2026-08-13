# 0008 A pipeline's reading stage is lifted out, not interrogated

## Status

Accepted (2026-08-12)

## Context

ADR 0005 established that a scan reading external bytes reports its faults
rather than collapsing them into a verdict, and closed two idioms: the bare
`if ! grep` (issue #25) and the single-command discard, `cmd || true` (issue
#55). It named a third as still open — the pipeline, where the lost status
belongs to a stage upstream of `grep`. That is issue #63, and this record
decides its shape.

The shape is:

```sh
if section_body "$file" "## Status" | grep -qi '^Open'; then
```

`section_body` is `awk` reading a record off disk. If it faults it emits
nothing, `grep` reads empty input and exits 1, and the `if` reads that as an
honest "Status is not Open".

The defect is live, not theoretical. With one record made unreadable, the gate
today reports `E-STATUS: … Status must be Proposed, Deferred, or …` — a
factually wrong finding about a file it never read — in the same run in which
`check_sections` and `check_title_number`, converted under #25 and #55,
correctly report `E-SECTION-SCAN` and `E-TITLE-SCAN` for the same file.

The worst instance is quieter than that one. `marker_only_change` compares two
`protected_shape` values, and `protected_shape` is `canonicalise "$1" | awk …`
with `canonicalise` an `awk` reading the file. When that read faults, both
sides are empty, the two compare equal, and `check_not_rewritten` returns
before any of the three anti-erasure rules run. Measured with `awk` stubbed to
fault: a merged record with a protected section deleted produces `E-REWRITE` on
a working toolchain and **`Records OK.`, exit 0** on a faulting one. That is
the gate passing over the erasure it exists to catch, with no finding of any
kind.

Issue #63 proposed reading `${PIPESTATUS[@]}`. Four measurements on the floor
toolchain — bash 3.2.57 and BSD awk 20200816, the macOS system pair CLAUDE.md
pins as the floor — decided against it.

**`PIPESTATUS` does not survive a command substitution.** After
`var=$(a | b | c)` the array has length 1 and holds the assignment's own
status — the pipeline's already-collapsed status, not the stages'. Most sites
in scope are exactly `var=$(pipeline)`, so the proposed instrument is not
available where it was proposed. A fix has to restructure whatever else it does.

**`pipefail` cannot separate the two cases**, as #63 reasoned and ADR 0005
already recorded: with `awk` at 2 and `grep` then at 1 over empty input, the
rightmost-nonzero rule yields grep's 1. All three scripts already set it.

**SIGPIPE is real but secondary.** `section_body … | grep -v '^>' | grep . |
head -1` returns 141 once the section passes roughly 2000 lines or 32 KB, and 0
below it, because `head` only signals a producer still writing. No `## Status`
section approaches that, so this is not a live false red; it is a reason not to
build a rule whose verdict depends on section length. The case against
`PIPESTATUS` rests on its unavailability above, not on this.

**Absence is not a fault here.** An empty section body is an ordinary verdict
that `E-SECTION-EMPTY` already owns, so the reading stage is two-valued — read,
or could not read — unlike ADR 0005 decision 2's witnesses, where absence is a
third distinct answer.

## Decision

**1. The stage that reads external bytes is lifted out of the pipeline and its
status captured directly.** Not interrogated in place:

```sh
status=0
out=$(section_body "$file" "$heading") || status=$?
```

A bare `awk`, so no `pipefail` rule is involved and awk's own 2 arrives intact.
The `status=0` initializer is required, not decorative — ADR 0005's Consequences
say so, and under `set -u` the success path would otherwise read an unset
variable. The remaining stages then shape a shell variable.

This is ADR 0005 decision 1 applied rather than extended. That decision already
puts a command reading only in-memory input outside the scan rule, so once the
file-reading stage is lifted out, every stage left in the pipeline is one 0005
already exempts. The pipeline does not need a status protocol; it needs to stop
carrying the one stage that had something to say.

**2. A residual in-memory pipeline either feeds a verdict directly or has its
status explicitly discarded at the site.** Both are permitted; what is not
permitted is leaving the status to `set -e`. These scripts run under
`set -euo pipefail`, and today an unread nonzero from one of these assignments
does not abort only because every call path passes through
`run_profile "$name" || true` or `migrate_profile "$name" || migrate_failed=1`,
which suppress `set -e` for the whole dynamic extent. A converted function must
not depend on its caller's context for that, so where the status is not the
verdict it is discarded in the text.

The discard is written `|| :` **with an inline comment naming this record**.
Without the comment it is textually the idiom #55 closed, and the next reader
has no way to tell which half they are in — the objection this record uses
below to reject a half-measure sweep. The comment is also what issue #66 would
need if a guard is ever written for this idiom.

The nonzero being discarded is usually ordinary, not exotic: `grep .` exits 1
on any ADR whose `## Status` carries only a supersession banner.

**The exemption is by consequence, not only by input.** An in-memory stage is
exempt because its failure is not the scan-could-not-run case — but where its
empty output would produce a *pass* rather than an error, it is captured anyway.
`protected_shape`'s filter is the one such site: it reads a shell variable, yet
an empty result makes two shapes compare equal, which is the fail-open this
whole record exists to close. Discarding that status would move the fail-open
one stage right rather than removing it. The other in-memory sites fail toward a
false error, which is loud, and stay exempt. Adversarial review of the first
implementation found exactly this, after the record's own first draft had
licensed the discard.

**3. `head` does not appear in a residual pipeline whose status feeds a
verdict.** This is the SIGPIPE question #63 asked, answered by construction
rather than by policy: 141 arises only where `head` closes a pipe on a live
producer, and no site reads such a status as an answer. Sites that took a first
line with `| head -1` either take it from the captured string or discard the
pipeline's status per decision 2. The alternative — read upstream statuses and
carve out 141 — is rejected below.

**4. The in-memory class does not convert.** `printf '%s' "$var" | grep -q …`
stays as it is. ADR 0005 decision 1 already settles this and no new authority is
needed: `printf` over a shell variable is not the scan-could-not-run case. #63
left this open as a decision to make; it was already made, and recording that it
was is this clause's only work.

**5. A lifted reader that repeats becomes a named three-valued reader, on the
house pattern.** `read_section` follows `path_exists_at` and `read_base_blob`
from ADR 0005 decision 3 and the sweep in issue #64: it returns 0 or 2, and
leaves awk's real status in `read_section_status` for the caller's diagnostic —
named after the reader, as `path_exists_status`, `tracked_in_index_status` and
`base_blob_status` are, rather than a generic name that would collide under the
dynamic scoping `migrate-records.sh` gets by sourcing the checker. The body
arrives in `read_section_out`. The caller `case`s on the return and reports
`E-<RULE>-SCAN` through `err_full`, naming the file and the status, *instead of*
its ordinary negative verdict rather than alongside it.

`read_section` returns 0 or 2 with no 1: absence is not one of its answers, per
Context. It hands the body back in a global rather than on stdout because a
caller that ran it in `$( )` could not see the status, which is the defect this
record exists to close.

**6. A reader whose fault would be reported from inside a subshell is
restructured so that it is not.** `status_line_of` is called as
`status=$(status_line_of "$file")`, so a `report_failure` inside it would set
`migrate_failed=1` in a discarded subshell — ADR 0005 decision 1's
process-substitution objection, reached by a different route. It is inlined into
`report_status_leftover`, which is not in a subshell. The three loop sites that
read `< <(…)` are soluble more cheaply, by lifting the reader above the
redirection.

**7. The idiom's siblings convert with it, whatever the downstream command.**
The defect is a file-reading stage whose status is discarded, not the word
`grep`. `section_body … | sed -n …`, `section_body … | tr -d …`,
`canonicalise … | awk …`, `diff … | grep -c`, and `find … | sort | grep` are the
same defect and convert on the same terms. #63's site list named the `grep`
sites; the `sed`, `tr` and `canonicalise` siblings in the same functions were
found by reading and are converted here.

## Consequences

- **Seventeen sites convert into sixteen guarded reads** across four scripts and
  their two mirrors: eight through `read_section`, five capturing a `diff` or
  `find` upstream directly, one lifting `canonicalise` out of `protected_shape`,
  one rewriting the `marker_only_change` call the migrator made under `if !`,
  and one giving `records_in_ref`'s caller a report instead of a silent empty
  list. Seventeen into sixteen because `report_status_leftover` made two
  separate unguarded reads of `## Status` — one for the banner, one for the
  status word — and one guarded read now serves both.
- New codes, each named per rule so a test can assert which site faulted:
  `E-STATUS-SCAN`, `E-SUPERSEDE-SCAN`, `E-TARGET-SCAN`, `E-REVIEWBY-SCAN`,
  `E-SECTION-BODY-SCAN`, `E-PREAMBLE-DIFF-SCAN`, `E-APPEND-DIFF-SCAN`,
  `E-MARKER-SHAPE-SCAN`, `E-BASE-LIST-SCAN`. The migrator reports through
  `report_failure`, which already carries per-rule codes, so its sites are named
  too — `E-MIGRATE-STATUS-SCAN`, `E-MIGRATE-SECTION-SCAN`,
  `E-MIGRATE-SHAPE-SCAN`, `E-MIGRATE-DIFF-SCAN`, `E-MIGRATE-LIST-SCAN` — for
  ADR 0005 decision 1's stated reason, that a test can assert *which* site
  faulted.
- Every converted site has a regression test that was verified to bite. With
  `read_section`'s fault return neutralised the suite reports seven failures and
  the gate **exits 0**; with `marker_only_change`'s neutralised, two more; with
  `protected_shape`'s filter guard neutralised, one more, again at `got=0`.
  Where a fixture can be built on which nothing else fires, the case pins the
  silent-pass direction rather than only the message text.
- `records_in_ref` becomes three-valued on the house pattern, with git's real
  status in `records_in_ref_status`. Its `return 1` is a sentinel, and reporting
  it would have named a status git never returned — `1` being a status git could
  plausibly return, the misattribution would not even have looked wrong.
- `migrate_profile` lifts `sort` out alongside `find`. `sort` reads in-memory
  input, but a fault empties the listing and restores the "0 record(s) examined,
  exit 0" fail-open `E-MIGRATE-LIST-SCAN` exists to close — the consequence test
  above, applied a second time.
- `check_not_rewritten`'s opening `tmp=$(mktemp) || return 0` is converted too.
  It was a fail-open of the same class, silently skipping all three anti-erasure
  rules, and it made the inner `E-TMPFILE` branches unreachable — a guarantee
  the record claimed and nothing could deliver.
- The code is `E-MARKER-SHAPE-SCAN`, not `E-SHAPE-SCAN`: the shorter name is a
  substring of the pre-existing `E-BASE-SHAPE-SCAN`, so a bare grep for it
  returned both.
- `diff` keeps its status read directly rather than through `read_section`: it
  is the reading stage at those sites, and its 0 and 1 both being ordinary —
  same, and differs — makes `>= 2` the fault test. That is the one place a
  captured status is compared against 2 rather than switched three ways.
- The `<(preamble …)` process substitutions inside those `diff` calls are
  converted by writing each side to a status-checked temp file first — ADR
  0005's "guarded at its input or moved out". Comparing captured strings
  instead was rejected: `printf '%s\n' "$empty"` emits one blank line where the
  reader emitted none, which turns a section that gained content from empty into
  one removed line and fires `E-REWRITE` on it. The obvious repair,
  `printf '%s'`, is worse — it drops the final newline and makes every ordinary
  append look like a removal.
- Those temp files follow `evaluate_base_conformance` rather than
  `check_not_rewritten`: a failed `mktemp` reports `E-TMPFILE` rather than
  returning 0 silently, since a silent return here would restore the fail-open
  the conversion removes. Each is removed on every path out, including the
  early returns inside `check_sections_append_only`'s loop.
- `protected_shape` and `marker_only_change` both become three-valued, per ADR
  0005 decision 3 — a predicate that can fault returns a distinct fault value
  and its caller reports. `check_not_rewritten` reports `E-MARKER-SHAPE-SCAN` and
  returns rather than running the three anti-erasure rules against a comparison
  it could not make, and the migrator's `if ! marker_only_change` becomes a
  `case`, since `if !` collapses 1 and 2 into one branch and is exactly what
  0005's Consequences forbid for a three-valued predicate.
- `E-MARKER-SHAPE-SCAN` correctly preempts `E-HEADING-SCAN` on an unreadable record:
  once the shape comparison cannot be made, the rules behind it do not run, so
  there is one finding rather than three. `check_headings_intact`'s own
  scan-fault test moves to a `grep` stub keyed on the H1 line to keep that code
  covered.
- `E-SECTION-BODY-SCAN` reports through `err_full` where the neighbouring
  `E-SECTION-SCAN` uses `err`. The difference is real and not cosmetic: the grep
  behind `E-SECTION-SCAN` reads the working-tree file while the base pass reads
  a readable temp copy, so only the tree pass faults; `section_body`'s awk
  faults in both passes, which marks the record non-conforming at base and would
  downgrade the finding to `W-LEGACY-SHAPE` and exit 0. That `E-SECTION-SCAN`
  itself uses `err` looks like the same latent defect one idiom earlier; it
  belongs to #25's sweep rather than this one and is filed as issue #90.
- The gate keeps reporting exactly one finding per record per rule. A scan
  fault replaces the rule's negative verdict, so a converted site cannot emit
  both `E-STATUS-SCAN` and `E-STATUS`.
- Reporting stays on `err_full`, inheriting ADR 0005's consequence unchanged: a
  fault reachable only while scanning the base-ref blob is still suppressed in
  the `collect` pass and the record still reads as conforming there.
- **Sites remain outside this sweep, recorded with owners**, as ADR 0005 did.
  `gate_paths`'s `git grep … | sed … || true` reads external bytes, but its
  whole body is a pipeline feeding `sort -u`, so a finding raised inside it
  lands in a discarded subshell and it needs the restructure decision 6
  describes rather than a conversion — issue #89. `profile_migrate_markers`
  runs a four-stage `awk` pipeline over a redirected file and reads none of it;
  it is left because it fails closed, its empty output making
  `marker_only_change` false and reporting `E-SELF-CHECK` rather than writing —
  a property this record's `protected_shape` conversion preserves.
- ADR 0005's Consequences named `records_in_ref` as "a pipeline site, owned by
  issue #63", whose extraction "can empty the base record list and so disarm
  `E-COUNT-FLOOR`". Its two halves are dispositioned differently. The `printf …
  | grep -E … || true` extraction is in-memory, so decision 4 exempts it. The
  live half is the caller, `base_records=$(records_in_ref "$BASE_SHA" || true)`:
  that `|| true` discards a `return 1` raised when `git ls-tree` faults on the
  base ref, leaving `base_count` at 0 and `E-COUNT-FLOOR` disarmed exactly as
  0005 described. It is converted here rather than left to #55, which is merged.
  0005's neighbouring remark that this `git ls-tree` was status-checked "under
  #64" is a misattribution this record corrects: `raw=$(git ls-tree …) ||
  return 1` has been present since 31d3d95, the original gate import. The
  `path_exists_at`/`read_base_blob` attribution to #64 is correct.
- **Nothing enforces this record**, exactly as ADR 0005 records of itself.
  Whether a gate should detect the idiom is still issue #66's, and this record
  adds a third shape for such a gate to recognise — mitigated by decision 2's
  requirement that every deliberate discard carry a comment naming this record,
  which gives that gate something to key on other than an allowlist.
- This record is numbered 0008, not the 0007 the dispatching campaign
  pre-assigned: 0007 merged to `main` first, and 0006 is held by unmerged issue
  #50.

## Considered & rejected

**Read `${PIPESTATUS[@]}` and exempt 141**, which is what #63 proposed. It does
not work at `var=$(pipeline)` sites, which are most of them, so it would fix
part of the list by one mechanism and the rest by another. Even where it works
it buys a worse rule: the verdict then depends on whether `head` closed the pipe
before the producer finished, which is section length. Rejected on the first
ground primarily; the second is secondary, since no real section is long enough
to reach it.

**Rely on the existing `pipefail`.** Not an option so much as a restatement —
all three scripts already set it, and ADR 0005 already recorded it as necessary
and not sufficient. The measurement above confirms it: the faulting pipeline
returns grep's 1.

**Convert the in-memory class too, for uniformity.** Tempting because a reader
meeting `printf '%s' "$x" | grep -q` after this change still has to know which
half they are in — the objection ADR 0005 used to reject a half-measure sweep.
Rejected because 0005 already drew this line by content rather than by
convenience, and redrawing it here would supersede a decision this record is
applying. `printf` over a shell variable has no scan-could-not-run case to
report; converting it would add a branch that cannot fire, which is the false
guarantee `date_to_int` already declines to build. Decision 2's mandatory
comment is what answers the reader's question instead.

**Give `section_body` an internal guard that reports its own fault.** One edit
instead of sixteen. Rejected on ADR 0005's process-substitution reasoning:
`section_body` is called inside `<(…)` and `$(…)`, where `err` sets `failed=1`
into a subshell that is then discarded, so the report would be silently lost at
exactly the sites hardest to reason about. A reader that aborted the run instead
would report through the wrong channel — a gate owes a coded finding, not a
stack unwind.

**Leave `protected_shape` to a follow-up issue**, on the ground that #63's site
list does not name it. Rejected because it is the site with the worst measured
outcome — a clean `Records OK.` over a deleted protected section — and because
converting `check_sections_append_only` while leaving it green would be the
least defensible half-measure available: `check_not_rewritten` returns on
`marker_only_change` before the converted rule ever runs, so the record's
headline fix would not reach the scenario at all.

**Split the migrator's sites into a follow-up.** `migrate-records.sh` is a
developer tool rather than a CI gate, and its faults surface on a terminal a
human is already watching. Rejected for ADR 0005's stated reason: leaving half
an idiom means the next reader cannot tell which half a given line is in, and
the migrator's `report_failure` channel makes its conversions the same size as
the gate's.
