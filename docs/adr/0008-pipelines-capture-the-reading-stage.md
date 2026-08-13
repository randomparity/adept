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

Issue #63 proposed reading `${PIPESTATUS[@]}`. Four measurements on the floor
toolchain — bash 3.2.57 and BSD awk 20200816, the macOS system pair CLAUDE.md
pins as the floor — decided against it.

**`PIPESTATUS` does not survive a command substitution.** After
`var=$(a | b | c)` the array is `(0)`: length 1, describing the assignment,
because the pipeline ran in the substitution's subshell. Most sites in scope are
exactly `var=$(pipeline)`, so the proposed instrument is not available where it
was proposed. A fix has to restructure whatever else it does.

**`pipefail` cannot separate the two cases**, as #63 reasoned and ADR 0005
already recorded: with `awk` at 2 and `grep` then at 1 over empty input, the
rightmost-nonzero rule yields grep's 1. All three scripts already set it.

**SIGPIPE is real and it tracks record size, not record content.**
`section_body … | grep -v '^>' | grep . | head -1` returns 141 on a large
section and 0 on a small one, because `head` only signals a producer still
writing. A rule reading upstream statuses would have to carve 141 out, and
would then be a gate whose verdict depends on how long a section is.

**Absence is not a fault here.** An empty section body is an ordinary verdict
that `E-SECTION-EMPTY` already owns, so the reading stage is two-valued — read,
or could not read — unlike ADR 0005 decision 2's witnesses, where absence is a
third distinct answer.

## Decision

**1. The stage that reads external bytes is lifted out of the pipeline and its
status captured directly.** Not interrogated in place. `out=$(section_body
"$file" "$heading") || status=$?` runs a bare `awk`, so no `pipefail` rule is
involved and awk's own 2 arrives intact. The remaining stages then shape a
shell variable.

This is ADR 0005 decision 1 applied rather than extended. That decision already
puts a command reading only in-memory input outside the scan rule, so once the
file-reading stage is lifted out, every stage left in the pipeline is one 0005
already exempts. The pipeline does not need a status protocol; it needs to stop
carrying the one stage that had something to say.

**2. No converted site's verdict reads a pipeline's exit status, so 141 needs
no policy.** This is the SIGPIPE question #63 asked, answered by dissolving it.
A `head`-truncated pipeline over a captured variable may still return 141; that
status is discarded, and after decision 1 it is discarded from a pipeline whose
stages all read in-memory input, which is the case 0005 exempts. The
alternative — read upstream statuses and exempt 141 — is rejected below.

**3. The in-memory class does not convert.** `printf '%s' "$var" | grep -q …`
stays as it is. ADR 0005 decision 1 already settles this and no new authority is
needed: `printf` over a shell variable is not the scan-could-not-run case. #63
left this open as a decision to make; it was already made, and recording that it
was is this clause's only work.

**4. A lifted reader that repeats becomes a named three-valued reader, on the
house pattern.** `read_section` follows `path_exists_at` and `read_base_blob`
from ADR 0005 decision 3 and issue #64: it returns 0 or 2, leaves the tool's
real status in a `_status` global for the caller's diagnostic, and puts the body
in an `_out` global. The caller `case`s on the return and reports
`E-<RULE>-SCAN` through `err_full`, naming the file and the status, *instead of*
its ordinary negative verdict rather than alongside it.

`read_section` returns 0 or 2 with no 1: absence is not one of its answers, per
Context.

**5. The idiom's siblings convert with it, whatever the downstream command.**
The defect is a file-reading stage whose status is discarded, not the word
`grep`. `section_body … | sed -n …`, `section_body … | tr -d …`, `diff … |
grep -c`, and `find … | sort | grep` are the same defect and convert on the same
terms. #63's site list named the `grep` sites; four `sed`/`tr` siblings in the
same functions were found by reading and are converted here.

## Consequences

- Fourteen sites convert across four scripts and their two mirrors. Eight go
  through `read_section`; the `diff` and `find` sites capture their own
  upstream directly, since their upstream is not `section_body`.
- New codes, each named per rule so a test can assert which site faulted:
  `E-STATUS-SCAN`, `E-SUPERSEDE-SCAN`, `E-TARGET-SCAN`, `E-REVIEWBY-SCAN`,
  `E-SECTION-EMPTY-SCAN`, `E-PREAMBLE-DIFF-SCAN`, `E-APPEND-DIFF-SCAN`. The
  migrator has no `::error::` channel of its own and reports through
  `report_failure`, per ADR 0005 decision 1's "report through the channel that
  exists".
- `diff` keeps its status read directly rather than through `read_section`: it
  is the reading stage at those sites, and its 0/1 both being ordinary — same,
  and differs — makes `>= 2` the fault test. That is the one place a captured
  status is compared against 2 rather than switched three ways.
- The `<(preamble …)` process substitutions inside those `diff` calls are
  converted by writing each side to a status-checked temp file first — ADR
  0005's "guarded at its input or moved out". Comparing captured strings
  instead was rejected: `printf '%s\n' "$empty"` emits one blank line where the
  reader emitted none, which would turn a section that gained content from
  empty into one removed line and fire `E-SECTION-GUTTED` on it.
- The gate keeps reporting exactly one finding per record per rule. A scan
  fault replaces the rule's negative verdict, so a converted site cannot emit
  both `E-STATUS-SCAN` and `E-STATUS`.
- Reporting stays on `err_full`, inheriting ADR 0005's consequence unchanged: a
  fault reachable only while scanning the base-ref blob is still suppressed in
  the `collect` pass and the record still reads as conforming there.
- **Nothing enforces this record**, exactly as ADR 0005 records of itself.
  Whether a gate should detect the idiom is still issue #66's, and this record
  adds a third shape to whatever that gate would have to recognise.
- ADR 0005's Consequences named `records_in_ref` as a pipeline site owned by
  #63. It is a `printf`-over-a-variable site, so decision 3 disposes of it: it
  does not convert. The `git ls-tree` above it was already status-checked under
  #64, so nothing there reads external bytes unguarded.
- This record is numbered 0008, not the 0007 the dispatching campaign
  pre-assigned: 0007 merged to `main` first, and 0006 is held by unmerged issue
  #50.

## Considered & rejected

**Read `${PIPESTATUS[@]}` and exempt 141**, which is what #63 proposed. It does
not work at `var=$(pipeline)` sites, which are most of them, so it would fix
part of the list by one mechanism and the rest by another. Even where it works
it buys a worse rule: the verdict then depends on whether `head` closed the pipe
before the producer finished, which is record size. Rejected on both counts.

**Set no `pipefail` change and rely on the existing one.** Not an option so much
as a restatement — all three scripts already set it, and ADR 0005 already
recorded it as necessary and not sufficient. The measurement above confirms it:
the faulting pipeline returns grep's 1.

**Convert the in-memory class too, for uniformity.** Tempting because a reader
meeting `printf '%s' "$x" | grep -q` after this change still has to know which
half they are in — the objection ADR 0005 used to reject a half-measure sweep.
Rejected because 0005 already drew this line by content rather than by
convenience, and redrawing it here would supersede a decision this record is
extending. `printf` over a shell variable has no scan-could-not-run case to
report; converting it would add a branch that cannot fire, which is the false
guarantee `date_to_int` already declines to build.

**Give `section_body` an internal guard that reports its own fault.** One edit
instead of fourteen. Rejected on ADR 0005's process-substitution reasoning:
`section_body` is called inside `<(…)` and `$(…)`, where `err` sets `failed=1`
into a subshell that is then discarded, so the report would be silently lost at
exactly the sites hardest to reason about. A reader that aborted the run instead
would report through the wrong channel — a gate owes a coded finding, not a
stack unwind.

**Split the migrator's sites into a follow-up.** `migrate-records.sh` is a
developer tool rather than a CI gate, and its faults surface on a terminal a
human is already watching. Rejected for ADR 0005's stated reason: leaving half
an idiom means the next reader cannot tell which half a given line is in, and
the migrator's `report_failure` channel makes its conversions the same size as
the gate's.
