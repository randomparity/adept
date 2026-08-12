# Implementation plan — sweep the discarded-status verdict swallow

**Goal.** Nine sites in the record gate and `tracker.sh` stop discarding a
scan's exit status, so a scan that could not run reports a fault instead of
passing as a scan that ran and found nothing.

**Architecture.** `check-records.sh` is a single-file gate: profile files supply
record-kind knowledge, the engine enforces shared rules, and findings are
emitted as coded `::error::` lines. This change adds one helper
(`path_exists_at`), converts eight scan sites to capture their status, and adds
one input guard. `tracker.sh` is a standalone dispatcher whose faults exit with
a code, not a `::error::` line.

**Stack.** Bash only. No new dependencies.

Design: [spec](../specs/2026-08-12-verdict-swallow-sweep-design.md) ·
[ADR 0005](../../adr/0005-scan-faults-are-reported-not-collapsed.md) · issue #55.

## Global Constraints

Every task's requirements implicitly include this section.

- **Bash 3.2 is the floor.** macOS ships 3.2.57. No `mapfile`, no `readarray`,
  no associative arrays, no `${var^^}`.
- **All three scripts run under `set -euo pipefail`.** A bare failing command
  aborts the script, and so does `cmd; status=$?`. The only safe capture is:
  ```sh
  status=0
  cmd ... || status=$?
  ```
  Declare the variable with `local` on its own line first — `local x=$(cmd)`
  masks `cmd`'s status in `$?`.
- **Never call a three-valued predicate under `if !` or in an `&&`/`||` chain
  that branches on it.** Both collapse `1` and `2` into one branch and reinstate
  the defect. Capture the status and `case` on it.
- **Scan faults report through `err_full`, never `err`.** `err` downgrades to
  `W-LEGACY-SHAPE` for a record already non-conforming at the base ref, leaving
  the gate at exit 0. Note `err_full` is still suppressed in the `collect` pass,
  which discards findings by design — see ADR 0005's Consequences.
- **Mirrors must stay byte-identical.** After editing any of
  `check-records.sh`, `check-records-test.sh`, `migrate-records.sh`,
  `profiles/adr.sh`, `profiles/debt.sh`, `records.yml` under
  `.github/scripts/`, copy it to `skills/tome-of-lore/assets/`. `just records`
  runs `cmp -s` on all six.
- **`rg` in gate scripts passes `--no-config`.**
- Message form: `E-<RULE>-SCAN: <path>: <what failed> (<tool> exit <status>)`.
  **`<status>` must be the tool's real exit status, never a predicate's sentinel
  `2`.** A three-valued predicate collapses every fault to `2`, so each one also
  records the underlying status in a file-scope variable that its caller
  interpolates. `check-records.sh` already carries state this way — `records`,
  `failed`, `renumbered_to`, `base_verdict` are all read through bash's dynamic
  scoping — so this follows the file's existing convention rather than
  introducing one.
- Declare **every** variable a converted function uses on its `local` line.
  Under `set -u` an undeclared one is not merely untidy; and a `local` line that
  omits a status variable makes it global by accident, which two functions here
  would then share.
- The checkout root is `$WORK`; never write an absolute path into a tracked
  file.

**Guardrail commands.** `just hooks` once per clone, before anything else —
it installs prek and the managed pre-push hook. `just verify` is the full suite.
During the build, each task verifies with both of:

```sh
BASE_SHA=$(git rev-parse origin/main) just records
just commit-check
```

`just records` runs the gate suite and the mirror `cmp`; `just commit-check`
runs lint (shellcheck), format-check (shfmt) and public-safety, which `records`
does not. Both take seconds. Note the mirror `cmp` is the **last** thing
`records` does, so while the suite is red the mirror check has not run at all —
a green `records` is the only evidence the mirrors match.

Run gates bare — no pipes, no `|| true`.

## File map

| file | change |
|---|---|
| `.github/scripts/check-records.sh` | `path_exists_at` helper; sites 1, 2, 3, 4, 5, 8, 9 |
| `.github/scripts/profiles/adr.sh` | site 6 |
| `.github/scripts/profiles/debt.sh` | comment retarget only, #55 -> #63 |
| `.github/scripts/check-records-test.sh` | regression cases for sites 1-6, 9 |
| `skills/tome-of-lore/assets/{check-records.sh,check-records-test.sh,profiles/adr.sh,profiles/debt.sh}` | byte copies |
| `skills/quest-log/assets/tracker.sh` | site 7 |
| `tests/fixtures/quest-log/tracker-test.sh` | regression case for site 7 |

## Task 1 — `path_exists_at`, and site 9 (`dir_in_ref`)

The helper plus its simplest consumer, so the helper is proven before three
more callers depend on it.

**Files.** `.github/scripts/check-records.sh`,
`.github/scripts/check-records-test.sh`, and both mirrors.

**Interfaces.** Provides, for tasks 2 and 3:

```sh
# 0 = present at ref, 1 = absent at ref, 2 = scan faulted
path_exists_at <ref> <path>
```

`dir_in_ref <ref> <dir>` changes from `0 present / 1 absent` to
`0 present / 1 absent / 2 fault`.

### Steps

1. Add the failing test first. In `check-records-test.sh`, beside the existing
   `E-PROFILE-DIR-MISSING` case, add a case that stubs `git` to fault on an
   `ls-tree` naming the record directory and expects exit 1 with `E-DIR-SCAN`.

   **The fixture has a precondition that is easy to miss.** `dir_in_ref` is only
   reached when `[ ! -d "$RECORD_DIR" ]` — a directory present in the working
   tree short-circuits before the witness runs, and the case would pass without
   the change. Build the fixture the way the existing
   `E-PROFILE-DIR-MISSING` case does, then remove the record directory from the
   **working tree only**, leaving it present at the base ref, so the guard is
   true and the witness is what decides. Read the neighbouring case in the suite
   and copy its fixture helper and `base_of`/`BASE_SHA` wiring rather than
   inventing names; the helper names differ between the checker and migrator
   sections of that file.

   The stub keys on subcommand **and** path:

   ```sh
   d=$(migrator_dir dir_scan_fault)   # or the matching fixture helper
   stub_bin="$SCRATCH/git-dir-fault-bin"
   mkdir -p "$stub_bin"
   real_git=$(command -v git)
   cat >"$stub_bin/git" <<STUB
   #!/usr/bin/env bash
   sub=\$1
   for arg in "\$@"; do
     if [ "\$sub" = ls-tree ] && [ "\$arg" = "docs/debt" ]; then
       printf 'fatal: fixture-fault: simulated object store error\n' >&2
       exit 128
     fi
   done
   exec "$real_git" "\$@"
   STUB
   chmod +x "$stub_bin/git"
   ```

   Drive it with `run_case "record dir scan faults" 1 E-DIR-SCAN "$d" BASE_SHA="$b" PATH="$stub_bin:$PATH"`.
2. Run `BASE_SHA=$(git rev-parse origin/main) just records`. Expect the new case
   to fail with `exit=0 but E-DIR-SCAN never fired` — the fault currently reads
   as "directory absent", and with the directory present in the tree the gate
   passes.
3. Add the helper immediately above `dir_in_ref`:

   ```sh
   # Existence at a ref, with a fault distinguishable from an absence.
   # `git cat-file -e` cannot do this: it exits 128 both for a path absent from a
   # valid ref and for a bad ref (ADR 0005). `git ls-tree` exits 0 with empty
   # output for an absent path and non-zero only for a real fault.
   # stderr is suppressed for the reason records_in_ref gives: a bare `fatal:`
   # from git is not this gate's interface, its coded ::error:: lines are.
   path_exists_at() {
     local ref=$1 path=$2 out status=0
     path_exists_status=0
     out=$(git ls-tree -r --name-only "$ref" -- "$path" 2>/dev/null) || status=$?
     if [ "$status" -ne 0 ]; then
       path_exists_status=$status
       return 2
     fi
     [ -n "$out" ] || return 1
     return 0
   }
   ```

   Declare `path_exists_status=0` at file scope beside the other engine
   globals. The predicate's own `2` is a sentinel; `path_exists_status` carries
   git's real status (128 for a bad ref or a damaged object) and is what every
   caller's diagnostic interpolates. Without it each `E-*-SCAN` message would
   report "git exit 2", which is not a status git ever returned.
4. Rewrite `dir_in_ref` to delegate, keeping both fail-open guards:

   ```sh
   dir_in_ref() {
     local ref=$1 dir=$2 status=0
     [ -n "$ref" ] || return 0
     git rev-parse --verify --quiet "${ref}^{commit}" >/dev/null || return 0
     path_exists_at "$ref" "$dir" || status=$?
     return "$status"
   }
   ```
5. Convert `run_profile`'s caller. It currently reads
   `if [ ! -d "$RECORD_DIR" ] && ! dir_in_ref ...`, an `if !` on what is now a
   three-valued predicate — exactly the collapse the constraints forbid:

   ```sh
   local dir_status=0
   if [ ! -d "$RECORD_DIR" ]; then
     dir_in_ref "${BASE_SHA:-}" "$RECORD_DIR" || dir_status=$?
     case $dir_status in
     0) ;;
     1)
       err "E-PROFILE-DIR-MISSING: profile '$name' is enabled but $RECORD_DIR exists at neither the base ref nor the tree"
       return 1
       ;;
     *)
       err_full "E-DIR-SCAN: $RECORD_DIR: could not check the record directory at ${BASE_SHA:-} (git exit $path_exists_status)"
       return 1
       ;;
     esac
   fi
   ```

   The `return 1` on a fault matters: continuing would run `E-COUNT-FLOOR`
   against a base ref just proven unreadable, and its base count would be zero
   for that same reason, disarming the rule that catches a clean run over
   nothing.
6. Copy both files to their mirrors:
   ```sh
   cp .github/scripts/check-records.sh skills/tome-of-lore/assets/check-records.sh
   cp .github/scripts/check-records-test.sh skills/tome-of-lore/assets/check-records-test.sh
   ```
7. Run `BASE_SHA=$(git rev-parse origin/main) just records`. Expect the new case
   to pass and the existing `E-PROFILE-DIR-MISSING` case to stay green — the
   absent-directory path must still report the old code.
8. Prove the test bites: temporarily change the `*)` arm to `1)`'s body, re-run,
   confirm the new case reddens, revert.
9. Commit.

**Acceptance.** `path_exists_at` exists and is used by `dir_in_ref`; a stubbed
`ls-tree` fault on the record directory reports `E-DIR-SCAN` and exits 1; the
pre-existing `E-PROFILE-DIR-MISSING` case is unchanged; mirrors compare equal.

## Task 2 — Site 3, `renumbered_elsewhere`

**Files.** `.github/scripts/check-records.sh`,
`.github/scripts/check-records-test.sh`, and both mirrors.

**Interfaces.** Consumes `path_exists_at` from task 1.
`renumbered_elsewhere <base> <path>` changes from `0 renumbered / 1 not` to
`0 renumbered / 1 not / 2 fault`.

### Steps

1. Add the failing test. Use the existing renumber fixture (a record whose
   number changed with content unchanged, which today reports
   `note: ... was renumbered to ...` and exits 0), plus a `git` stub faulting on
   `ls-tree` naming the **candidate** record path. Expect exit 1 and
   `E-RENUMBER-SCAN`.
2. Run the suite. Expect failure: the fault currently reads as "candidate did
   not exist at base", so the candidate is still considered and the run exits 0.
3. Replace the discarding witness at the top of the candidate loop:

   ```sh
   # was: git cat-file -e "${base}:${candidate}" 2>/dev/null && continue
   cand_status=0
   path_exists_at "$base" "$candidate" || cand_status=$?
   case $cand_status in
   0) continue ;;          # existed at base, not a renumber destination
   1) ;;                   # absent at base, a real candidate
   *) scan_faulted=$path_exists_status; continue ;;
   esac
   ```

   Declare `cand_status` and `scan_faulted=0` in the function's `local` line.
4. Return the fault only after the loop, so a positive match outranks a fault on
   a sibling candidate:

   ```sh
   # replaces the bare `return 1` at the end
   if [ "$scan_faulted" -ne 0 ]; then
     path_exists_status=$scan_faulted
     return 2
   fi
   return 1
   ```
5. Convert the caller in `check_no_disappearances`, which is currently
   `if renumbered_elsewhere ...; then ... else err E-GONE ... fi`:

   ```sh
   renum_status=0
   renumbered_elsewhere "$base" "$record" || renum_status=$?
   case $renum_status in
   0) info "note: $record was renumbered to $renumbered_to (content unchanged)" ;;
   1) err "E-GONE: $record is no longer a record at that path (deleted, moved, untracked, or renamed with its content changed) — resolve records in place with a '> **Resolved by ...**' banner" ;;
   *) err_full "E-RENUMBER-SCAN: $record: could not search for a renumbered copy at $base (git exit $path_exists_status)" ;;
   esac
   ```

   Declare `renum_status` on `check_no_disappearances`'s `local` line.

   `E-GONE` keeps `err` — it is a record-conformance verdict and stays
   downgradable. The scan fault uses `err_full`. The two are alternatives, never
   both, so a fault does not also claim the record is gone.
6. Copy to mirrors. Run the suite; the new case passes, and the existing
   renumber and `E-GONE` cases stay green.
7. Prove the test bites, then commit.

**Acceptance.** A stubbed `ls-tree` fault on a candidate reports
`E-RENUMBER-SCAN`, not `E-GONE`, and exits 1; a genuine renumber still reports
the `note:` line and exits 0; a genuinely gone record still reports `E-GONE`.

## Task 3 — Sites 4 and 5, gate self-protection

One task because both live in `check_gate_files` and its witness, and a reviewer
could not accept one without the other.

**Files.** `.github/scripts/check-records.sh`,
`.github/scripts/check-records-test.sh`, and both mirrors.

**Interfaces.** Consumes `path_exists_at`. `gate_existed_at <base>` changes from
`0 existed / 1 did not` to `0 existed / 1 did not / 2 fault`.

### Steps

1. Add three failing tests:
   - site 4: `git` stub faulting on `ls-tree` naming a **protected gate file**
     path; expect exit 1 and `E-GATE-SCAN`;
   - site 5a: a fixture with no gate file at the base ref (so `gate_existed_at`
     runs at all) plus a stub faulting on `ls-tree` naming a path under
     `SELF_DIR`. **The path must be one `gate_paths` does not itself emit**, or
     the stub fires at site 4 first, reports `E-GATE-SCAN`, and increments
     `gate_path_count` — which takes `check_gate_files` out of its empty-set
     branch so `gate_existed_at` never runs. Pin the key to a known basename
     that reaches the witness but not the protected set, and say in the step
     which one and why. Expect exit 1 and `E-GATE-WITNESS-SCAN`;
   - site 5b: the same fixture with the `SELF_DIR` witness legitimately finding
     nothing, plus a stub faulting on `git grep ... -- .github/workflows`;
     expect exit 1 and `E-GATE-WITNESS-SCAN`.
2. Run the suite; all three fail. Today site 4's fault skips the path silently
   and site 5's reports `I-GATE-BOOTSTRAP` at exit 0.
3. Site 4 — in `check_gate_files`'s loop, replace
   `git cat-file -e "${base}:${self}" 2>/dev/null || continue`:

   ```sh
   self_status=0
   path_exists_at "$base" "$self" || self_status=$?
   case $self_status in
   0) ;;
   1) continue ;;
   *)
     err_full "E-GATE-SCAN: $self: could not check the gate file at $base (git exit $path_exists_status)"
     gate_path_count=$((gate_path_count + 1))
     continue
     ;;
   esac
   gate_path_count=$((gate_path_count + 1))
   ```

   Declare `self_status` on `check_gate_files`'s `local` line.

   Counting the path on a fault is deliberate: the empty-set branch below must
   not report `I-GATE-BOOTSTRAP` — "no gate existed here" — on the strength of a
   witness that never ran. Skipping the body is also deliberate: no
   `E-GATE-GONE` may be attributed to a path whose base-ref presence is unknown.
4. Site 5 — in `gate_existed_at`, replace both witnesses and remember a fault:

   ```sh
   gate_existed_at() {
     local base=$1 rel name status faulted=0

     rel=$(repo_relative "$SELF_DIR")
     if [ -n "$rel" ]; then
       while IFS= read -r name; do
         [ -n "$name" ] || continue
         status=0
         path_exists_at "$base" "${rel}/${name}" || status=$?
         case $status in
         0) return 0 ;;
         1) ;;
         *) faulted=1 ;;
         esac
       done < <(gate_known_basenames)
     fi

     while IFS= read -r name; do
       [ -n "$name" ] || continue
       status=0
       git grep --no-color -qF "$name" "$base" -- .github/workflows 2>/dev/null || status=$?
       case $status in
       0) return 0 ;;
       1) ;;
       *) faulted=1 ;;
       esac
     done < <(gate_known_basenames)

     [ "$faulted" -eq 0 ] || return 2
     return 1
   }
   ```

   A positive witness returns immediately, so it outranks a fault on any other
   witness. `git grep` exits 1 for no match and 128 for a bad ref, so `>= 2` is
   a genuine fault there.
5. Convert the caller — currently `if gate_existed_at "$base"; then ... else ...`:

   ```sh
   local existed_status=0
   gate_existed_at "$base" || existed_status=$?
   case $existed_status in
   0) err "E-GATE-EMPTY-SET: no gate file from the base ref is protected — a rename must declare its predecessors in GATE_PREDECESSORS" ;;
   1) info "I-GATE-BOOTSTRAP: no gate existed at $base — this is the change installing it" ;;
   *) err_full "E-GATE-WITNESS-SCAN: $gate_witness_path: could not determine whether a gate existed at $base (git exit $path_exists_status)" ;;
   esac
   ```
6. Copy to mirrors. Run the suite. The three new cases pass; the existing
   `E-GATE-EMPTY-SET`, `E-GATE-GONE` and `I-GATE-BOOTSTRAP` cases stay green.
   The bootstrap case is the important regression check — it must still exit 0.
7. Prove each of the three bites, then commit.

**Acceptance.** Faults in either witness report `E-GATE-WITNESS-SCAN` and never
`I-GATE-BOOTSTRAP`; a fault witnessing a protected path reports `E-GATE-SCAN`
and still counts toward `gate_path_count`; all pre-existing gate cases unchanged.

## Task 4 — Sites 1 and 2, the two listing greps

**Files.** `.github/scripts/check-records.sh`,
`.github/scripts/check-records-test.sh`, and both mirrors.

**Interfaces.** None consumed or provided; both are self-contained.

### Steps

1. Add two failing tests, both with a `grep` stub that faults on the listing
   pattern only and `exec`s the real `grep` otherwise — the shape the suite
   already uses for the migrator's section-scan case:
   - fault on `^#+ ` -> expect exit 1 and `E-HEADING-LIST-SCAN`;
   - fault on `^## ` -> expect exit 1 and `E-SECTION-LIST-SCAN`.

   Both need a fixture where a merged record is edited, so
   `check_not_rewritten` runs — and each needs its own, because the two rules
   fire on different edits:
   - Site 1's fixture makes an **addition-only** edit (append a paragraph;
     remove nothing from any section body, the preamble, or the heading set), so
     no other rule fires and the pre-change run genuinely exits 0. An edit that
     also removes a line would report `E-REWRITE` and the case would pass at
     exit 1 without the change, proving nothing.
   - Site 2's fixture likewise edits only in a way that leaves `E-REWRITE` and
     `E-HEADING-REWRITTEN` silent before the change.

   Also confirm `marker_only_change` does not short-circuit the fixture's edit
   before either rule runs.
2. Run the suite; both fail, exiting 0 because an empty list means zero loop
   iterations.
3. Site 1 — in `check_headings_intact`, hoist the listing out of the process
   substitution:

   ```sh
   check_headings_intact() {
     local tmp=$1 path=$2 heading grep_status list_status=0 headings
     headings=$(grep -E '^#+ ' "$tmp") || list_status=$?
     case $list_status in
     0 | 1) ;;
     *)
       err_full "E-HEADING-LIST-SCAN: $path: could not list the base ref's headings (grep exit $list_status)"
       return 0
       ;;
     esac
     while IFS= read -r heading; do
       ...unchanged body...
     done <<<"$headings"
   }
   ```

   `1` is "the base blob had no headings", which is legitimate. The `<<<` feeds
   the loop in the current shell, as the process substitution did, so `err_full`
   still reaches `failed`.

   Rewrite the existing comment above the loop in the same step. It currently
   explains the *process substitution* — "Fed by a process substitution on
   `done`, so `err_full` runs in the current shell rather than a piped
   subshell" — and that construct is gone. The reason is unchanged and the
   construct is not, so the comment must say herestring; leaving it describes
   code that is no longer there, and deleting it loses why the shape matters.
4. Site 2 — in `check_sections_append_only`, split the listing from the filter.
   Only the listing reads a file; the `grep -vxF` filter reads memory and stays
   with #63:

   ```sh
   local sections=$APPEND_ONLY_SECTIONS list_status=0 all_sections
   if [ "$sections" = "*" ]; then
     all_sections=$(grep -E '^## ' "$tmp") || list_status=$?
     case $list_status in
     0 | 1) ;;
     *)
       err_full "E-SECTION-LIST-SCAN: $path: could not list the base ref's sections (grep exit $list_status)"
       return 0
       ;;
     esac
     sections=$(printf '%s\n' "$all_sections" | grep -vxF '## Status') || true
   fi
   ```
5. Copy to mirrors. Run the suite; both new cases pass and the existing
   `E-REWRITE` and `E-HEADING-REWRITTEN` cases stay green.
6. Prove both bite, then commit.

**Acceptance.** A faulting heading listing reports `E-HEADING-LIST-SCAN`; a
faulting section listing reports `E-SECTION-LIST-SCAN`; both exit 1; a record
with no headings or no sections still passes.

## Task 5 — Site 6, `check_title_number`

**Files.** `.github/scripts/profiles/adr.sh`,
`.github/scripts/check-records-test.sh`, and both mirrors.

### Steps

1. Add the failing test: an ADR-profile fixture with a `grep` stub faulting on
   `-m1 '^# '`; expect exit 1, `E-TITLE-SCAN`, and **no** `E-TITLE-MISMATCH`.
   `run_case` already fails a case whose expected code never fired; assert the
   absence by grepping the captured stderr for `E-TITLE-MISMATCH` and failing if
   present.
2. Run the suite; it fails — today the fault yields an empty title and a
   spurious `E-TITLE-MISMATCH`.
3. Convert:

   ```sh
   check_title_number() {
     local file=$1 label=$2 name num title title_status=0
     name=${label##*/}
     num=${name%%-*}
     title=$(grep -m1 '^# ' "$file") || title_status=$?
     case $title_status in
     0 | 1) ;;
     *)
       err_full "E-TITLE-SCAN: $label: could not read the title line (grep exit $title_status)"
       return 0
       ;;
     esac
     if ! printf '%s' "$title" | grep -qE "^# ${num} "; then
       err "E-TITLE-MISMATCH: $label: title '$title' does not begin '# $num ' — the H1's number is the record's number"
     fi
   }
   ```

   `err_full` is required, not stylistic: this rule runs in both passes, and
   `err` would let the base pass collect the fault silently and a grandfathered
   record downgrade it to a warning, leaving the gate green over an unread
   title. The `printf | grep -qE` line below is a #63 site and stays as is.
4. Copy to mirrors. Run the suite; the new case passes, the existing
   `E-TITLE-MISMATCH` case stays green.
5. Prove it bites, then commit.

**Acceptance.** A faulting title read reports `E-TITLE-SCAN` alone and exits 1;
a genuinely mismatched title still reports `E-TITLE-MISMATCH`.

## Task 6 — Site 7, `resolve_tracker`

**Files.** `skills/quest-log/assets/tracker.sh`,
`tests/fixtures/quest-log/tracker-test.sh`. No mirror.

### Steps

1. Add the failing test. The fixture must be a git root whose `AGENTS.md`
   contains **no** `issue-tracker:` line, with `rg` stubbed to fault only on the
   strict `-c` pattern. With a declaration present the run exits non-zero before
   and after the change — the loose probe catches it — and the test would prove
   nothing.
2. Run `./tests/fixtures/quest-log/tracker-test.sh`. Expect failure: today the
   run exits 0 printing `github`.
3. Convert:

   ```sh
   local root agents matches loose_status count_status=0
   ...
   matches=$(rg -c '^issue-tracker: [a-z0-9-]+\r?$' "$agents") || count_status=$?
   case $count_status in
   0 | 1) ;;
   *)
     die "$EXIT_USAGE" usage \
       "could not scan $agents for issue-tracker declarations (rg exit $count_status)"
     ;;
   esac
   matches=${matches:-0}
   ```

   `EXIT_USAGE` matches the loose-probe branch three lines below, which PR #54
   established for the same fault. Re-classing both to `EXIT_TRANSPORT` is a
   `tracker.sh` caller-contract change and is deliberately not bundled here.
4. Run the tracker suite; the new case passes and the existing malformed,
   multiple-declaration and no-declaration cases stay green.
5. Prove it bites, then commit.

**Acceptance.** An `rg -c` fault exits 1 naming the file and status; a repo with
no `AGENTS.md` still resolves to `github` at exit 0; a malformed declaration
still reports the malformed-declaration message.

## Task 7 — Site 8's guard, and the `debt.sh` comment retarget

Small and non-testable, so it is last and has no test step.

**Files.** `.github/scripts/check-records.sh`,
`.github/scripts/profiles/debt.sh`, and both mirrors.

### Steps

1. In `gate_paths`, compute the pathspec first and guard it, matching the
   `[ -n "$rel" ]` guard its neighbouring emissions already use:

   ```sh
   # was: done < <(git ls-tree -r --name-only "$base" -- "$(repo_relative "$SELF_DIR/profiles")" 2>/dev/null || true)
   profiles_rel=$(repo_relative "$SELF_DIR/profiles")
   if [ -n "$profiles_rel" ]; then
     while IFS= read -r profile; do
       ...unchanged body...
     done < <(git ls-tree -r --name-only "$base" -- "$profiles_rel" 2>/dev/null || true)
   fi
   ```

   Declare `profiles_rel` in the function's `local` line. An empty pathspec is
   the only trigger a fixture could reach; `git ls-tree` returns 0 for a
   directory merely absent from the ref. The `|| true` stays: `gate_paths` runs
   inside a process substitution and has no reporting channel, so a damaged
   object store remains an accepted residual (ADR 0005 decision 1). Add a
   comment saying exactly that, so the next reader does not take the remaining
   `|| true` for an oversight.
2. In `profiles/debt.sh`, change the two in-place deferral comments that name
   issue #55 to name **#63** — the issue that now owns the pipeline-into-grep
   idiom. Comment text only; no code changes.
3. Copy both to mirrors.
4. Run `just verify` in full, bare. Expect exit 0.
5. Commit.

**Acceptance.** `gate_paths` never invokes `git ls-tree` with an empty
pathspec; the remaining `|| true` carries a comment naming its accepted
residual; `debt.sh`'s two comments point at #63; `just verify` green.

## Final verification

```sh
just verify
```

Bare, no pipes. Expect exit 0, with the record suite reporting its case count
all passing, `Records OK.`, and no `record gate mismatch` line.

Then confirm the sweep's own claim:

```sh
rg -n --no-config 'cat-file -e' .github/scripts/check-records.sh
```

Expect no matches — ADR 0005 decision 2 removes it as an existence witness.

## Rollback

Every task is a single commit touching a script and its mirror. Reverting one
commit restores both halves of a mirror pair together, so no task can leave the
`cmp` check failing on its own.

Tasks 2, 3 and 1 are ordered by a real dependency: tasks 2 and 3 call
`path_exists_at`, which task 1 defines. Partial rollback is therefore
reverse-order only — revert 3 and 2 before 1. Reverting task 1 alone leaves live
callers of an undefined function, which `set -u` does not catch and which fails
only on the path that calls it.
