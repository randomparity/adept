# Sweep the discarded-status verdict swallow out of the record gate

Issue: #55. Decision record: [0005](../../adr/0005-scan-faults-are-reported-not-collapsed.md).
Split-out follow-up: #63.

## Goal

Every site in the shipped gate and asset scripts where a **single command's**
exit status is discarded, while that command reads **external bytes** (a file on
disk or a git object) and its result feeds an **authoritative verdict**,
captures the status explicitly and reports a fault instead of silently passing.

## Scope

The four idioms in scope all discard a single command's status outright:

- `cmd || true` — the status is thrown away and an empty result stands in.
- `cmd && return 0` with an unconditional `return 1` fallthrough — every
  non-zero outcome, fault or honest miss, lands on the same `return 1`.
- `cmd || continue` — the same, one loop iteration at a time.
- `[ -n "$(cmd)" ]` — the status is discarded by the command substitution and
  only the output is tested, so a fault reads as empty output.

Explicitly **out of scope**, owned by #63: every pipeline idiom, where the
status that is lost belongs to a stage upstream of the last command. Recovering
it needs `${PIPESTATUS[@]}` plus a policy for SIGPIPE/141 from a `| head -1`
tail, which is a design question with no precedent here. `check-records.sh:865`
belongs to #63 rather than here despite its trailing `|| true`: the pipeline
ends in `sed`, which always exits 0, so the `|| true` is already dead and only
`PIPESTATUS` can recover `git grep`'s status.

Also out of scope, with reasons recorded in the issue's `WORK:SCOPE` charter:
`check-records.sh:987` (tolerates a repo function's documented `return 1`),
`check-records.sh:1063` (`run_profile || true` is deliberate, so one profile's
failure cannot hide another's findings), the two URL extractions in
`create-verified-issue.sh` and `profiles/github.sh` (in-memory input, and an
empty result already has an explicit non-silent handler), and everything under
`tests/fixtures/` and `*-test.sh` (test harnesses, not gate verdicts).

Also out of scope and owned by **#64**, found during this design's ADR review:
`check_not_rewritten:507` and `evaluate_base_conformance:547` read a base blob
with `git cat-file blob` and fail open on any non-zero status, silently
exempting a record from the append-only rules. Same defect class, different
function family, and the fix depends on `path_exists_at` landing here first.

## Findings that shaped the design

Established by probing git directly in this repository, not from documentation:

| command | matched | absent / no match | fault |
|---|---|---|---|
| `git cat-file -e <ref>:<path>` | 0 | **128** | **128** |
| `git ls-tree -r --name-only <ref> -- <path>` | 0, output | 0, empty | 128 |
| `git grep -qF <needle> <ref> -- <path>` | 0 | 1 | 128 |
| `grep`, `rg` | 0 | 1 | >= 2 |

`git cat-file -e` cannot be made to report a fault, because its normal absent
case is already 128. Every existence witness therefore moves to `git ls-tree`.
This is the substance of ADR 0005 decision 2.

`git ls-tree` returns 0 for a directory absent from the ref, so the only way the
listing at `gate_paths` can fault is an **empty pathspec** — which happens when
`repo_relative` returns nothing because the script lives outside the repo. That
site needs an input guard, not a status capture (ADR 0005 decision 1).

## Design

A new helper in `check-records.sh` concentrates the existence witness:

```
path_exists_at <ref> <path>  ->  0 present | 1 absent | 2 fault
```

It runs `git ls-tree -r --name-only "$ref" -- "$path"`, capturing the status. A
non-zero status yields `2`. A zero status yields `0` when the output is
non-empty and `1` when it is empty. It emits no diagnostic; callers report.

Predicates that can now fault become three-valued and their callers `case` on
the result, reporting the scan fault **instead of** the ordinary negative
verdict, never alongside it (ADR 0005 decision 3).

## Sites and their behaviour

Each row is a distinct converted site. `.github/scripts/**` has a byte-identical
mirror under `skills/tome-of-lore/assets/**`; every change lands in both.

| # | function | file | fault code |
|---|---|---|---|
| 1 | `check_headings_intact` heading listing | `check-records.sh` | `E-HEADING-LIST-SCAN` |
| 2 | `check_sections_append_only` section listing | `check-records.sh` | `E-SECTION-LIST-SCAN` |
| 3 | `renumbered_elsewhere` candidate witness | `check-records.sh` | `E-RENUMBER-SCAN` |
| 4 | `check_gate_files` protected-path witness | `check-records.sh` | `E-GATE-SCAN` |
| 5 | `gate_existed_at` both witnesses | `check-records.sh` | `E-GATE-WITNESS-SCAN` |
| 6 | `check_title_number` title read | `profiles/adr.sh` | `E-TITLE-SCAN` |
| 7 | `resolve_tracker` declaration count | `quest-log/assets/tracker.sh` | usage exit |
| 8 | `gate_paths` profile listing | `check-records.sh` | none — input guard |
| 9 | `dir_in_ref` record-directory witness | `check-records.sh` | `E-DIR-SCAN` |

Site 8 takes an input guard rather than a status capture and emits no code, per
ADR 0005 decision 1.

`tracker.sh` carries no coded-error channel, so site 7 reports through the usage
exit it already fails through, per ADR 0005 decision 1.

Required behaviour per site:

1. **`check_headings_intact`** — the listing `grep -E '^#+ '` over the base-ref
   copy runs into a variable first. On `>= 2`, `E-HEADING-LIST-SCAN` names the
   record path and the status, and the function returns without iterating, so
   the per-heading loop cannot report a clean pass over a list it never got.
2. **`check_sections_append_only`** — the listing `grep -E '^## '` over the same
   copy is split from the `grep -vxF '## Status'` filter that follows it. Only
   the first reads a file; the filter reads memory and stays with #63. On
   `>= 2`, `E-SECTION-LIST-SCAN` names the path and status and the function
   returns.
3. **`renumbered_elsewhere`** — returns `0` renumbered, `1` not renumbered, `2`
   fault. Its caller reports `E-RENUMBER-SCAN` on `2` and suppresses its own
   `E-GONE` for that record, because a scan that did not run establishes
   neither.
4. **`check_gate_files`** — the per-path base-ref witness reports `E-GATE-SCAN`
   on a fault instead of skipping the path. A skipped path is silently
   unprotected, which is the condition the whole self-protection rule exists to
   detect.
5. **`gate_existed_at`** — returns `0` existed, `1` did not, `2` fault. The
   `git grep` witness captures its own status; `1` is an honest miss and `>= 2`
   is a fault. On `2` the caller reports `E-GATE-WITNESS-SCAN` and emits
   neither `E-GATE-EMPTY-SET` nor `I-GATE-BOOTSTRAP`.
6. **`check_title_number`** — on `>= 2`, `E-TITLE-SCAN` names the file and
   status and the function returns, so no `E-TITLE-MISMATCH` is emitted against
   a title that was never read. Removing that spurious second finding is called
   for by name in issue #55.
7. **`resolve_tracker`** — an `rg -c` fault exits with the usage status and a
   message naming the file and the status, matching the loose-probe branch
   directly below it. It must not fall through to `matches=0`, which routes a
   write to the default tracker.
8. **`gate_paths`** — the profile pathspec is computed into a variable and the
   listing runs only when it is non-empty, matching the `[ -n "$rel" ]` guard
   the surrounding emissions already use.
9. **`dir_in_ref`** — already uses `git ls-tree`, but discards its status inside
   a command substitution and tests only emptiness, so a fault reads as "the
   record directory did not exist at the base ref". It returns `0` existed, `1`
   did not, `2` fault; `run_profile` reports `E-DIR-SCAN` on `2` instead of
   `E-PROFILE-DIR-MISSING`, which would name the wrong cause. Its two existing
   fail-open guards — an empty ref, and a ref that is not a commit — are
   deliberate and keep returning `0`.

Two comments in `profiles/debt.sh` (and its mirror) currently defer their
pipeline sites to #55. #55 no longer owns them, so they are retargeted to #63.
Comment text only.

## Error message form

Every new code follows the form PR #54 established, so the suite's
`::[a-z]*::<CODE>: ` matcher and a reader's eye both keep working:

```
E-HEADING-LIST-SCAN: docs/adr/0001-x.md: could not list headings (grep exit 2)
```

The path, what could not be done, and the exit status in parentheses.

## Testing

One regression test per converted site, each asserting the gate exits non-zero
**and** the specific code fired — `run_case` already checks both.

The base-ref copies these scans read are `mktemp` files the process creates and
removes itself, so no fixture can `chmod` them ahead of time. Sites 1, 2 and 6
therefore use a **PATH-stubbed `grep`** that faults only on the argument the
target call passes and `exec`s the real `grep` for everything else — the shape
the suite already uses for the migrator's section-scan test. Site 7 stubs `rg`
the same way against `tracker-test.sh`'s existing sandbox.

Sites 3, 4, 5 and 9 read git objects rather than files, so they use a
PATH-stubbed `git` that faults only on the `ls-tree`/`grep` invocation under
test and defers otherwise.

Site 8's guard is proven by the existing `E-GATE-UNLOCATABLE` path: with the
script outside the repo, `repo_relative` returns empty and the listing must not
run.

Each test must be shown to bite — break the conversion, watch the case redden,
revert — before it counts.

## Acceptance criteria

1. Every site above branches on a captured status and reports a coded fault on
   `>= 2` (or, for site 8, cannot reach a fault at all).
2. No site reports a scan fault *and* its rule's own negative verdict for the
   same condition.
3. A regression test per site, each verified to fail when its conversion is
   reverted.
4. `.github/scripts/**` stays byte-identical to `skills/tome-of-lore/assets/**`.
5. `just verify` is green, run bare.
6. `git cat-file -e` appears nowhere in `check-records.sh` as an existence
   witness.

## Constraints

- **Bash 3.2** is the floor. No `mapfile`, no `readarray`, no associative
  arrays.
- `local x=$(cmd)` masks `cmd`'s status in `$?`. Declare, then assign on its own
  line, everywhere a status is captured.
- `rg` in gate scripts passes `--no-config`.
- The checkout root is written `$WORK` in this document; this repository is
  public and an absolute path is host identity.
