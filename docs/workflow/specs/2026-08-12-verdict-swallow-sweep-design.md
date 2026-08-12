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
tail, which is a design question with no precedent here.

`check-records.sh:865` is a different case and an earlier draft of this spec got
its reason wrong. `pipefail` **is** set, so `git grep | sed || true` does
discard `git grep`'s 128 — the `|| true` is live, not dead, and `|| status=$?`
would recover it without `PIPESTATUS`, because `sed` is the only other stage and
does not fail on valid input. It is nonetheless out of scope here for the same
reason as site 8: it sits inside `gate_paths`, which runs in a process
substitution and has no reporting channel (ADR 0005 decision 1). It is recorded
with site 8's residual, not deferred to #63.

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

## Extent of the sweep

So a later reader can re-run it rather than trust it: every file under
`.github/scripts/`, `skills/`, and `scripts/` was scanned for the four idioms
above. The shipped scripts it reached, and their dispositions:

| script | disposition |
|---|---|
| `check-records.sh` (+ mirror) | sites 1-5, 8, 9 here; pipeline sites to #63; blob reads to #64 |
| `profiles/adr.sh` (+ mirror) | site 6 here; two pipeline sites to #63 |
| `profiles/debt.sh` (+ mirror) | two pipeline sites to #63; comment retarget here |
| `quest-log/assets/tracker.sh` | site 7 here |
| `migrate-records.sh` (+ mirror) | five sites, all pipelines — #63. It is a migrator run by hand, not a gate, so none of its sites gate a merge. |
| `quest-log/assets/profiles/github.sh` | one site, in-memory URL extraction with an explicit empty-result handler — no fix |
| `quest-log/assets/cleared-dependencies.sh` | one `&& return 0`, on a tracker API error string rather than a scan of external bytes — outside this goal's definition |
| `bounty/scripts/create-verified-issue.sh` | one site, same in-memory URL extraction — no fix |
| `scripts/list-shell-sources.sh` | one `read ... || return 1` in `is_shell_source`: an unreadable file reads as "not a shell source" and drops out of the lint and format inventory. Same class, different mechanism — owned by **#69** |

One further residual the sweep found and does not fix: `tracked_in_index`
(`check-records.sh:371`) wraps `git ls-files --error-unmatch` and collapses a
fault into "not tracked", which three callers read as authoritative — including
a literal `tracked_in_index ... || continue` at `renumbered_elsewhere:415`. Same
class, but converting it requires a separate post-fault decision at each of the
three callers. Owned by issue **#69**.

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

It keeps `2>/dev/null`, matching the witnesses it replaces and the reason
`records_in_ref` already gives: a bare `fatal:` from git is not part of the
gate's interface, and the coded `::error::` line is. The cost is that every git
fault reaches the caller as the single value `2` and the diagnostic can only
report that, not git's own message — accepted, because the alternative is
letting raw git text into the gate's output.

Predicates that can now fault become three-valued and their callers `case` on
the result, reporting the scan fault **instead of** the ordinary negative
verdict, never alongside it (ADR 0005 decision 3).

Two rules bind every three-valued predicate here:

- **A positive answer outranks a fault.** Where the predicate loops over several
  candidates or witnesses, a fault is remembered and returned only once the loop
  has exhausted every candidate without a positive answer. A witness that
  genuinely found evidence is not made unreliable by a sibling probe failing.
- **Scan faults report through `err_full`, not `err`.** `err` downgrades to
  `W-LEGACY-SHAPE` for a record that was already non-conforming at the base ref,
  so a scan fault reported through it leaves the gate at exit 0 — the silent
  pass this change exists to remove. A fault describes the scan, not the record,
  so it must not be downgradable. `adr.sh`'s existing `E-INDEX-SCAN` already
  uses `err_full` for this reason. The rule's own verdicts
  (`E-TITLE-MISMATCH`, `E-GONE`) keep whichever channel they use today.

  `err_full` does **not** cover the base-ref `collect` pass: both helpers are
  suppressed there, because that pass keeps a verdict and discards findings by
  design. A fault reachable only while scanning the base-ref blob is therefore
  unreported and the record reads as conforming. Accepted rather than fixed —
  the alternative is a fourth emit mode, which costs more than the case is
  worth. Recorded in ADR 0005's Consequences.

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
   fault. It loops over candidate records, so a fault on one candidate is
   remembered and returned only if no later candidate matches; a positive match
   outranks it. Its caller reports `E-RENUMBER-SCAN` on `2` and suppresses its
   own `E-GONE` for that record, because a scan that did not run establishes
   neither.
4. **`check_gate_files`** — on a fault witnessing one protected path, the loop
   reports `E-GATE-SCAN` and skips that path's body, so no `E-GATE-GONE` is
   attributed to a path whose base-ref presence is unknown. It still counts the
   path toward `gate_path_count`, so the empty-set branch below cannot report
   `I-GATE-BOOTSTRAP` — "no gate existed here" — off the back of a witness that
   never ran. Skipping the path silently, as today, leaves it unprotected, which
   is the condition the self-protection rule exists to detect.
5. **`gate_existed_at`** — returns `0` existed, `1` did not, `2` fault. Both
   witnesses capture their own status; for `git grep`, `1` is an honest miss and
   `>= 2` is a fault. It runs two loops over several basenames, so the same
   positive-outranks-fault rule applies: a fault is returned only when no
   witness found anything. On `2` the caller reports `E-GATE-WITNESS-SCAN` and
   emits neither `E-GATE-EMPTY-SET` nor `I-GATE-BOOTSTRAP`.
6. **`check_title_number`** — on `>= 2`, `E-TITLE-SCAN` names the file and
   status **through `err_full`** and the function returns, so no
   `E-TITLE-MISMATCH` is emitted against a title that was never read. Removing
   that spurious second finding is called for by name in issue #55. `err_full`
   is required rather than incidental: this rule runs in both passes, and `err`
   would let the base-ref pass collect the fault silently and a grandfathered
   record downgrade it to a warning, leaving the gate green on a scan that never
   ran.
7. **`resolve_tracker`** — an `rg -c` fault exits with the usage status and a
   message naming the file and the status, matching the loose-probe branch
   directly below it. It must not fall through to `matches=0`, which routes a
   write to the default tracker.

   `EXIT_USAGE` labels an I/O fault as a usage error, and `tracker.sh` does
   define an `EXIT_TRANSPORT`. Matching the adjacent branch is still the choice
   here: PR #54 established `EXIT_USAGE` for exactly this fault three lines
   away, and re-classing both branches is a contract change for `tracker.sh`'s
   callers that belongs in its own change, not smuggled into a sweep.
8. **`gate_paths`** — the profile pathspec is computed into a variable and the
   listing runs only when it is non-empty, matching the `[ -n "$rel" ]` guard
   the surrounding emissions already use. This closes the reachable trigger, not
   every trigger: `git ls-tree` can still fault against a damaged object store,
   and `gate_paths` runs inside a process substitution where it has no reporting
   channel (ADR 0005 decision 1). That residual is accepted here and stated
   rather than claimed closed — giving this one function a fault channel means
   the sentinel protocol ADR 0005 rejects.
9. **`dir_in_ref`** — already uses `git ls-tree`, but discards its status inside
   a command substitution and tests only emptiness, so a fault reads as "the
   record directory did not exist at the base ref". It returns `0` existed, `1`
   did not, `2` fault; `run_profile` reports `E-DIR-SCAN` on `2` instead of
   `E-PROFILE-DIR-MISSING`, which would name the wrong cause, and then
   `return 1` exactly as the `E-PROFILE-DIR-MISSING` branch does. Continuing
   instead would run `collect_records` and `E-COUNT-FLOOR` against a base ref it
   has just failed to read, and `E-COUNT-FLOOR` compares a base record count
   that would be zero for the same unread reason — disarming the one rule that
   catches a clean run over nothing. Its two existing fail-open guards — an
   empty ref, and a ref that is not a commit — are deliberate and keep
   returning `0`.

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
PATH-stubbed `git` that faults only on the invocation under test and defers
otherwise. Which invocation each stub keys on has to be stated, because several
sites issue argument-similar calls:

Every `git` stub keys on **both** the subcommand and the path argument, because
three of these sites issue an `ls-tree` and a subcommand-only stub fires for
whichever runs first:

- Site 3 keys on `ls-tree` naming a **candidate record** path, in a fixture
  where a record was renumbered so `renumbered_elsewhere` actually reaches its
  candidate loop.
- Site 4 keys on `ls-tree` naming a **protected gate file** path.
- Site 5 needs two cases, because its two witnesses fault independently and the
  second only runs once the first found nothing:
  - the `ls-tree` witness, keyed on a path under `SELF_DIR` in a fixture with no
    gate file at the base ref, so `gate_existed_at` is reached at all; and
  - the workflow witness, keyed on `git grep ... -- .github/workflows`, in a
    fixture where the `SELF_DIR` witness legitimately finds nothing.

  Without the first case the `cat-file`-to-`ls-tree` conversion — the change
  ADR 0005 decision 2 exists for — ships untested.
- Site 9 keys on `ls-tree` naming the **record directory**.

Site 7's fixture needs care for a different reason: with an `AGENTS.md` that
*does* declare a tracker, `resolve_tracker` exits non-zero both before and after
the conversion — the loose probe PR #54 already fixed catches the fault first —
so such a test passes without the change and proves nothing. The fixture is a
git root whose `AGENTS.md` contains **no** `issue-tracker:` line, with `rg`
stubbed to fault only on the strict `-c` pattern. Before the conversion that
run exits 0 and prints `github`; after it, exit 1 naming the file and status.

Site 8's guard is proven by the existing `E-GATE-UNLOCATABLE` path: with the
script outside the repo, `repo_relative` returns empty and the listing must not
run.

Each test must be shown to bite — break the conversion, watch the case redden,
revert — before it counts.

## Acceptance criteria

1. Sites 1-7 and 9 branch on a captured status and report a fault on `>= 2`
   through the channel item 6 names. Site 8 instead guards the input that made
   its fault reachable; its residual is recorded above, not closed.
2. No site reports a scan fault *and* its rule's own negative verdict for the
   same condition.
3. A regression test per converted site, each verified to fail when its
   conversion is reverted. Site 8 is exempt and is the only exemption: it adds a
   guard rather than a fault branch, its remaining trigger is a damaged object
   store that no fixture can stage, and the `E-GATE-UNLOCATABLE` path does not
   reach it. It is covered by inspection and by the existing gate suite staying
   green, and that limit is recorded rather than papered over with a test that
   would pass before the change.
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
