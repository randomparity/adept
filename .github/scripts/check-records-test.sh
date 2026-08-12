#!/usr/bin/env bash
# Regression tests for check-records.sh.
#
# The checker is the only mechanically enforced constraint behind the record convention, so its
# failure mode is the dangerous one: reporting a clean run over nothing. Every rule it
# claims has a case here, and every case asserts the exit status rather than the output,
# because a green exit is exactly what an erasure attempt is trying to obtain.
#
# Each case builds a throwaway git repo under a scratch directory, runs the real
# checker against it, and compares the exit status to the expectation. Nothing here
# touches the repository it lives in.
#
# Usage: check-records-test.sh [scratch-dir]
#
# A run builds roughly seven thousand files, and the scratch tree it created is removed when
# every case passes. A red or aborted run keeps it, because those fixtures are the only record
# of what failed. An explicitly supplied scratch-dir is the caller's and is never removed.
#
# Needs bash, git, and POSIX find/sed/awk/grep/sort/uniq/diff/mktemp/date — nothing else.
# No perl, no Python, no GNU-only flags, no bash-4 constructs: an adopter's gate must not go
# red for a missing interpreter. It resolves the workflow template from either the
# publishing layout (beside the scripts) or the adopted one (../workflows/).
#
# It also needs the rest of the gate beside it — the checker, the migrator, and both profiles
# (see REQUIRED_ASSETS). An install that omitted one exits 2 before the first case rather than
# deriving failures from it.

set -euo pipefail

# Hook runners can export repository-local Git variables such as GIT_DIR and
# GIT_WORK_TREE. Clear them before creating fixtures so each `git -C` command
# targets the disposable repository named by the suite.
while IFS= read -r variable; do
  [ -n "$variable" ] || continue
  unset "$variable"
done < <(git rev-parse --local-env-vars)

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CHECKER="$SCRIPT_DIR/check-records.sh"

allocate_owned_scratch() {
  mktemp -d "${TMPDIR:-/tmp}/check-records-test.XXXXXX"
}

# Whether the scratch tree is this script's to delete. A caller who names one owns it, and
# gets it back either way; the default one is ours and is cleaned up on a green run.
if [ "$#" -ge 1 ]; then
  SCRATCH=$1
  SCRATCH_OWNED=no
else
  SCRATCH=$(allocate_owned_scratch)
  SCRATCH_OWNED=yes
fi

passed=0
failed=0
# Read by on_exit to tell an abort from a completed run. Not derivable from passed/failed: a run
# that dies mid-way has both, and so does one that finished with failures.
summary_reached=no

# A fresh repo containing one valid record, committed, with BASE pointing at it.
new_repo() {
  local dir=$1
  mkdir -p "$dir/docs/debt"
  git -C "$dir" init -q .
  git -C "$dir" config user.email test@example.invalid
  git -C "$dir" config user.name "check-records test"
  mkdir -p "$dir/.github/scripts" "$dir/.github/workflows"
  cp "$CHECKER" "$dir/.github/scripts/check-records.sh"
  mkdir -p "$dir/.github/scripts/profiles"
  cp "$SCRIPT_DIR/profiles/debt.sh" "$dir/.github/scripts/profiles/debt.sh"
  # A realistic stub: the checker derives its protected workflow set by finding workflows
  # that invoke it, so a stub that never mentions it would not be protected.
  cat >"$dir/.github/workflows/records.yml" <<'YAML'
name: records
on: pull_request
jobs:
  records:
    runs-on: ubuntu-latest
    steps:
      - run: ./.github/scripts/check-records.sh
YAML
}

write_record() {
  local dir=$1 name=$2 status=${3:-Open} target=${4:-docs/debt} review=${5:-2099-01-01}
  cat >"$dir/docs/debt/$name" <<EOF
# ${name%%-*} — test record

## Status

$status
review-by: $review

## Concern

A real concern with a body.

## Why deferred

Valid but outside the charter.

## Non-regression boundary

Must not make it worse.

## What would resolve it

A specific fix.

## Provenance

target: $target
Found by a test.
EOF
}

# The workflow template lives beside the scripts when they ship together (publishing
# layout) and at ../workflows/ once a repo has adopted them. Assuming the former is what
# made this suite abort in the layout it exists to verify.
find_template() {
  local candidate
  for candidate in "$SCRIPT_DIR/records.yml" "$SCRIPT_DIR/../workflows/records.yml"; do
    if [ -f "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

# Every asset this suite resolves out of its own directory. An adopting repo's copy of the suite
# sits in .github/scripts/, so "beside me" is where the install put things, and a row the install
# table omitted is a file that is simply not there.
#
# Without this, an incomplete install reported as a handful of `cp: No such file or directory`
# lines on stderr, four derived case failures, and then an abort under set -e at the one fixture
# that copies outside a command substitution — none of which names the install. That was the
# failure shape for every repo that followed a table listing five of the six files.
#
# Two shipped files are deliberately absent from the list. records.yml, because find_template
# resolves it from either layout and already fails with a message at its use site, so naming it
# here would duplicate a live check rather than add one. And this script, because it is the one
# running — do not "complete" the list by adding it.
#
# Newline-delimited rather than an array, matching GATE_PREDECESSORS in the checker and for the
# same reason: bash 3.2 is the macOS system shell, where "${arr[@]}" on an empty array is fatal
# under set -u.
REQUIRED_ASSETS="check-records.sh
migrate-records.sh
profiles/adr.sh
profiles/debt.sh"

require_assets() {
  local asset missing=""
  while IFS= read -r asset; do
    [ -n "$asset" ] || continue
    [ -f "$SCRIPT_DIR/$asset" ] || missing="$missing $asset"
  done <<<"$REQUIRED_ASSETS"
  [ -n "$missing" ] || return 0

  printf 'error: incomplete install — missing beside this suite:%s\n' "$missing" >&2
  printf 'error: looked in %s\n' "$SCRIPT_DIR" >&2
  printf "error: the tome-of-lore skill's install table lists every file the gate needs;\n" >&2
  printf "error: copy the missing one(s) from that skill's assets/ and re-run.\n" >&2
  return 1
}

# run_case <name> <expected-exit> <expected-code|-> <repo-dir> [env assignments...]
#
# The expected code matters as much as the exit status. Asserting only the status lets a
# case pass because some *other* rule fired, which is how a suite goes green against a
# checker whose anti-erasure rules have been removed. `-` means "assert no code".
#
# GITHUB_ACTIONS is unset for every case and set explicitly by the ones that test CI
# behavior, so the suite behaves identically on a laptop and on a runner. Inheriting it
# made two cases fail inside CI, which failed the job before the gate ever ran.
run_case() {
  local name=$1 expected=$2 code=$3 dir=$4
  shift 4
  local got=0
  if (cd "$dir" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt "$@" ./.github/scripts/check-records.sh) \
    >"$dir/.out" 2>"$dir/.err"; then
    got=0
  else
    got=1
  fi

  local why=""
  if [ "$got" != "$expected" ]; then
    why="expected exit=$expected got=$got"
  elif [ "$code" != "-" ] && ! grep -q "::[a-z]*::$code: " "$dir/.err"; then
    why="exit=$got but $code never fired"
  elif [ "$code" = "-" ] && grep -q '::error::' "$dir/.err"; then
    why="unexpected error: $(sed -n 's/^::error:://p' "$dir/.err" | head -1)"
  fi

  if [ -z "$why" ]; then
    passed=$((passed + 1))
    printf '  ok   %-44s exit=%s %s\n' "$name" "$got" "$code"
  else
    failed=$((failed + 1))
    printf '  FAIL %-44s %s\n' "$name" "$why"
    head -3 "$dir/.err" | sed 's/^/         /'
  fi
}

# A case that starts from a committed valid record and mutates the working tree.
# case_dir <name> [status] [target] [review-by]
#
# The record is written with its final content *before* the base commit. Fixtures used to
# commit a default record and edit it afterwards, which now trips the append-only rule —
# correctly, since that is the rewrite vector.
case_dir() {
  local name=$1
  local dir="$SCRATCH/$name"
  new_repo "$dir"
  write_record "$dir" "0001-valid.md" "${2:-Open}" "${3:-docs/debt}" "${4:-2099-01-01}"
  git -C "$dir" add -A
  git -C "$dir" commit -qm base
  printf '%s' "$dir"
}

base_of() { git -C "$1" rev-parse HEAD; }

# An ADR fixture: docs/adr/ instead of docs/debt/, both profiles installed, and a README.md in
# the record directory, which is the exempt non-record the ADR convention puts there.
new_adr_repo() {
  local dir=$1
  mkdir -p "$dir/docs/adr"
  git -C "$dir" init -q .
  git -C "$dir" config user.email test@example.invalid
  git -C "$dir" config user.name "check-records test"
  mkdir -p "$dir/.github/scripts/profiles" "$dir/.github/workflows"
  cp "$CHECKER" "$dir/.github/scripts/check-records.sh"
  cp "$SCRIPT_DIR/profiles/adr.sh" "$SCRIPT_DIR/profiles/debt.sh" \
    "$dir/.github/scripts/profiles/"
  cat >"$dir/.github/workflows/records.yml" <<'YAML'
name: records
on: pull_request
jobs:
  records:
    runs-on: ubuntu-latest
    steps:
      - run: ./.github/scripts/check-records.sh
YAML
  cat >"$dir/docs/adr/README.md" <<'MD'
# Architecture Decision Records

The files in this directory are the index. There is deliberately no summary table.
MD
}

# write_adr <dir> <name> [status-body] [extra-status-line]
write_adr() {
  local dir=$1 name=$2 status=${3:-Accepted (2026-01-01)} extra=${4:-}
  cat >"$dir/docs/adr/$name" <<EOF
# ${name%%-*} — test decision

## Status

$status
$extra

## Context

Why this came up.

## Decision

What we decided.

## Consequences

What follows from it.

## Considered & rejected

- Something else, because it was worse.
EOF
}

# adr_dir <name> [status-body] [extra-status-line] — a committed ADR repo with one record.
adr_dir() {
  local name=$1
  local dir="$SCRATCH/$name"
  new_adr_repo "$dir"
  write_adr "$dir" "0001-first.md" "${2:-Accepted (2026-01-01)}" "${3:-}"
  git -C "$dir" add -A
  git -C "$dir" commit -qm base
  printf '%s' "$dir"
}

# migrator_dir <name> — a committed repo whose one record carries every legacy marker shape
# at once, with the migrator installed beside the checker. Beside is not incidental: the
# migrator sources the checker out of its own directory for canonicalise and the allowance.
migrator_dir() {
  local name=$1
  local dir="$SCRATCH/$name"
  new_repo "$dir"
  cp "$SCRIPT_DIR/migrate-records.sh" "$dir/.github/scripts/migrate-records.sh"
  chmod +x "$dir/.github/scripts/migrate-records.sh"
  write_record "$dir" "0001-valid.md"
  sed -e 's/^# 0001 — /# 1. /' -e 's/^## Status$/## status:/' -e 's/^Open$/open/' \
    -e 's/^target: /- target: /' "$dir/docs/debt/0001-valid.md" >"$dir/.rec"
  mv "$dir/.rec" "$dir/docs/debt/0001-valid.md"
  git -C "$dir" add -A
  git -C "$dir" commit -qm base
  printf '%s' "$dir"
}

# run_migrator <name> <expected-exit> <expected-code|-> <repo-dir> [args...]
#
# Output goes to siblings of the repo rather than into it: the migrator refuses a dirty
# worktree, and run_case's own `.out`/`.err` inside the fixture would be exactly that.
run_migrator() {
  local name=$1 expected=$2 code=$3 dir=$4
  shift 4
  local got=0
  if (cd "$dir" && env -u GITHUB_ACTIONS RECORD_PROFILES="${MIGRATE_PROFILES-debt}" \
    ./.github/scripts/migrate-records.sh "$@") >"$dir.mout" 2>"$dir.merr"; then
    got=0
  else
    got=1
  fi

  local why=""
  if [ "$got" != "$expected" ]; then
    why="expected exit=$expected got=$got"
  elif [ "$code" != "-" ] && ! grep -q "^error: $code: " "$dir.merr"; then
    why="exit=$got but $code never fired"
  elif [ "$code" = "-" ] && [ -s "$dir.merr" ]; then
    why="unexpected error: $(head -1 "$dir.merr")"
  fi

  if [ -z "$why" ]; then
    passed=$((passed + 1))
    printf '  ok   %-44s exit=%s %s\n' "$name" "$got" "$code"
  else
    failed=$((failed + 1))
    printf '  FAIL %-44s %s\n' "$name" "$why"
    head -3 "$dir.merr" | sed 's/^/         /'
  fi
}

# should_clean_scratch <exit-code> <owned> <dir> — the scratch-removal decision, hoisted out of
# on_exit so the suite can assert it. Removal happens after the summary line, so no case can
# observe its own scratch tree being removed; only the decision is reachable from inside a run.
should_clean_scratch() {
  [ "$1" -eq 0 ] && [ "$2" = yes ] && [ -n "$3" ]
}

# should_report_abort <exit-code> <summary-reached> — the abort-notice decision, hoisted for the
# same reason should_clean_scratch is: a decision taken inside a trap is otherwise unobservable
# from inside a run, and this one shipped wrong because no case asserted it.
#
# The condition is "did the summary print", which is what the notice claims. It used to be
# "were there zero failures", a proxy that agrees only when the abort precedes every failure —
# exactly the run that needs the notice least. A run that recorded failures and *then* died
# printed neither the notice nor the summary, so five FAIL lines and silence was
# indistinguishable from a run that finished with five failures. Reproducible by dropping
# migrate-records.sh from REQUIRED_ASSETS and running a five-file install: 118 cases pass, 5
# fail, the rest never run, and the old guard called that a finished run.
should_report_abort() {
  [ "$1" -ne 0 ] && [ "$2" = no ]
}

# An abort under set -e printed no summary at all, so a suite that died at case 38 of 48
# looked like one that had finished. Always report where it got to.
#
# The tree also has to go. Each run leaves about seven thousand files behind, and repeated runs
# exhausted a tmpfs inode table and blocked every tool on the machine. Only a green run of a
# scratch tree this script created is removed — see should_clean_scratch.
on_exit() {
  local code=$?
  if should_report_abort "$code" "$summary_reached"; then
    printf '\nABORTED after %d passing and %d failing case(s) — exit %d, no summary reached\n' \
      "$passed" "$failed" "$code"
  fi
  if should_clean_scratch "$code" "$SCRATCH_OWNED" "$SCRATCH"; then
    rm -rf "$SCRATCH"
  elif [ -n "$SCRATCH" ] && [ -d "$SCRATCH" ]; then
    printf 'scratch retained at %s\n' "$SCRATCH"
  fi
}

# Its own function, not inline in main: a `return` here must skip only these cases. Inline,
# a template-resolution failure returned from main, silently skipping every later case and
# exiting 0 — which is how a mutation sweep came back with 31 survivors and no explanation.
adoption_cases() {
  local d b template
  d="$SCRATCH/adoption"
  mkdir -p "$d/docs/debt" "$d/.github/scripts" "$d/.github/workflows"
  git -C "$d" init -q .
  git -C "$d" config user.email test@example.invalid
  git -C "$d" config user.name "check-records test"
  cp "$SCRIPT_DIR/check-records.sh" "$SCRIPT_DIR/check-records-test.sh" "$d/.github/scripts/"
  mkdir -p "$d/.github/scripts/profiles"
  cp "$SCRIPT_DIR/profiles/debt.sh" "$d/.github/scripts/profiles/"
  if ! template=$(find_template); then
    printf '  FAIL %-44s cannot locate records.yml from %s\n' "adoption fixture" "$SCRIPT_DIR"
    failed=$((failed + 1))
    return 0
  fi
  cp "$template" "$d/.github/workflows/records.yml"
  chmod +x "$d/.github/scripts"/*.sh
  write_record "$d" "0001-adopted.md"
  git -C "$d" add -A
  git -C "$d" commit -qm "adopt the deferral gate"
  b=$(base_of "$d")
  run_case "adopted gate validates a good record" 0 - "$d" BASE_SHA="$b"

  # And that the installed copy protects the installed workflow, which is only true if the
  # derivation found it at the adopted paths.
  git -C "$d" rm -q .github/workflows/records.yml
  run_case "adopted gate protects its own workflow" 1 E-GATE-GONE "$d" BASE_SHA="$b"

  # The trap the installation procedure now warns about: an adopter that installs the four
  # files but skips the first-record commit passes the local smoke test (no BASE_SHA, so an
  # absent docs/debt/ is not yet a failure) and then goes red on every PR once CI supplies
  # one. write_record is deliberately not called here.
  d="$SCRATCH/adoption_no_records"
  mkdir -p "$d/.github/scripts" "$d/.github/workflows"
  git -C "$d" init -q .
  git -C "$d" config user.email test@example.invalid
  git -C "$d" config user.name "check-records test"
  cp "$SCRIPT_DIR/check-records.sh" "$SCRIPT_DIR/check-records-test.sh" "$d/.github/scripts/"
  mkdir -p "$d/.github/scripts/profiles"
  cp "$SCRIPT_DIR/profiles/debt.sh" "$d/.github/scripts/profiles/"
  cp "$template" "$d/.github/workflows/records.yml"
  chmod +x "$d/.github/scripts"/*.sh
  git -C "$d" add -A
  git -C "$d" commit -qm "adopt the deferral gate, no record yet"
  b=$(base_of "$d")
  run_case "adoption with no first record passes locally with no BASE_SHA" 0 - "$d" BASE_SHA=
  run_case "same adoption fails once CI supplies BASE_SHA" 1 E-PROFILE-DIR-MISSING "$d" BASE_SHA="$b"
}

main() {
  trap on_exit EXIT
  mkdir -p "$SCRATCH"
  printf 'check-records.sh regression tests\nscratch: %s\n\n' "$SCRATCH"

  # Both sides of this placement carry weight. After the scratch line, because that line is the
  # only affordance pointing an operator at a retained tree and the cleanup case reads it back;
  # before the first case, because the message an adopter needs is about their install, not the
  # four case failures a missing asset derives. Exit rather than count a failure: an incomplete
  # install is not a finding about the records, and a partial run over the wrong asset set is
  # the clean-run-over-nothing this suite exists to prevent.
  require_assets || exit 2

  printf -- '-- valid input --\n'
  d=$(case_dir valid)
  run_case "valid record" 0 - "$d" BASE_SHA="$(base_of "$d")"

  d=$(case_dir resolved "> **Resolved by PR #12** (2026-01-01)")
  run_case "resolved via banner" 0 - "$d" BASE_SHA="$(base_of "$d")"

  printf -- '-- record structure --\n'
  d=$(case_dir missing_section)
  sed '/^## Why deferred$/d' "$d/docs/debt/0001-valid.md" >"$d/.tmp" && mv "$d/.tmp" "$d/docs/debt/0001-valid.md"
  run_case "missing required section" 1 E-SECTION-MISSING "$d" BASE_SHA="$(base_of "$d")"

  d=$(case_dir empty_section)
  sed '/^Valid but outside the charter\.$/d' "$d/docs/debt/0001-valid.md" >"$d/.tmp" && mv "$d/.tmp" "$d/docs/debt/0001-valid.md"
  run_case "section present but empty" 1 E-SECTION-EMPTY "$d" BASE_SHA="$(base_of "$d")"

  d=$(case_dir bad_status)
  write_record "$d" "0001-valid.md" "Maybe"
  run_case "unreadable status" 1 E-STATUS "$d" BASE_SHA="$(base_of "$d")"

  d=$(case_dir banner_no_referent)
  write_record "$d" "0001-valid.md" "> **Resolved by** (2026-01-01)"
  run_case "banner naming nothing" 1 E-BANNER-FORM "$d" BASE_SHA="$(base_of "$d")"

  d=$(case_dir banner_future)
  write_record "$d" "0001-valid.md" "> **Resolved by nothing at all** (2999-01-01)"
  run_case "banner dated in the future" 1 E-BANNER-FUTURE "$d" BASE_SHA="$(base_of "$d")"

  d=$(case_dir banner_double)
  write_record "$d" "0001-valid.md" "> **Resolved by PR #1** (2999-01-01)
> **Resolved by PR #2** (2026-01-01)"
  run_case "two resolution banners" 1 E-BANNER-COUNT "$d" BASE_SHA="$(base_of "$d")"

  d=$(case_dir no_target)
  sed '/^target: /d' "$d/docs/debt/0001-valid.md" >"$d/.tmp" && mv "$d/.tmp" "$d/docs/debt/0001-valid.md"
  run_case "no target line" 1 E-TARGET-MISSING "$d" BASE_SHA="$(base_of "$d")"

  d=$(case_dir target_wrong_section)
  sed -e '/^target: /d' -e 's|^## Concern$|## Concern\
\
target: docs/debt|' "$d/docs/debt/0001-valid.md" >"$d/.tmp" && mv "$d/.tmp" "$d/docs/debt/0001-valid.md"
  run_case "target line outside Provenance" 1 E-TARGET-MISSING "$d" BASE_SHA="$(base_of "$d")"

  d=$(case_dir bad_reviewby)
  write_record "$d" "0001-valid.md" Open docs/debt "July 2026"
  run_case "malformed review-by" 1 E-REVIEWBY-FORM "$d" BASE_SHA="$(base_of "$d")"

  d=$(case_dir missing_reviewby)
  sed '/^review-by: /d' "$d/docs/debt/0001-valid.md" >"$d/.tmp" &&
    mv "$d/.tmp" "$d/docs/debt/0001-valid.md"
  run_case "missing review-by on open record" 1 E-REVIEWBY-MISSING "$d" \
    BASE_SHA="$(base_of "$d")"

  d=$(case_dir resolved_without_reviewby "> **Resolved by PR #12** (2026-01-01)")
  sed '/^review-by: /d' "$d/docs/debt/0001-valid.md" >"$d/.tmp" &&
    mv "$d/.tmp" "$d/docs/debt/0001-valid.md"
  run_case "resolved record without review-by" 0 - "$d" BASE_SHA="$(base_of "$d")"

  d=$(case_dir stale_reviewby Open docs/debt "2020-01-01")
  run_case "stale review-by warns only" 0 W-REVIEWBY-STALE "$d" BASE_SHA="$(base_of "$d")"

  # A resolution banner discharges the concern, so the re-evaluation date stops meaning anything
  # and the warning must not fire. Bespoke, because run_case asserts a code is present and the
  # whole assertion here is that none is. It greps the bare code rather than
  # `::warning::W-REVIEWBY-STALE`: a downgraded finding is relabelled W-LEGACY-SHAPE and keeps
  # the original code in parentheses, so matching only the reported form would pass on a
  # grandfathered record that still warned.
  d=$(case_dir resolved_stale_reviewby "> **Resolved by PR #12** (2026-01-01)" docs/debt "2020-01-01")
  printf '  %-4s %-44s ' "" "resolved record with a passed review-by"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$(base_of "$d")" \
    ./.github/scripts/check-records.sh) >"$d/.out" 2>"$d/.err"; then
    if grep -q 'REVIEWBY-STALE' "$d/.err"; then
      failed=$((failed + 1))
      printf 'FAIL W-REVIEWBY-STALE fired on a discharged concern\n'
    else
      passed=$((passed + 1))
      printf 'ok   exit=0 no staleness warning\n'
    fi
  else
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$(sed -n 's/^::error:://p' "$d/.err" | head -1)"
  fi

  # The guard above suppresses the staleness rule only. A malformed date is a malformed field
  # whichever state the record is in, and this case is what stops the guard being widened to the
  # whole check: moved above the form rule, it would turn this exit-1 green.
  d=$(case_dir resolved_bad_reviewby "> **Resolved by PR #12** (2026-01-01)")
  write_record "$d" "0001-valid.md" "> **Resolved by PR #12** (2026-01-01)" docs/debt "July 2026"
  run_case "malformed review-by when resolved" 1 E-REVIEWBY-FORM "$d" BASE_SHA="$(base_of "$d")"

  # The resolved verdict is per record, and every other case here holds one record, so nothing
  # else would notice it leaking. Records are enumerated in sorted order, which makes 0001
  # resolved and 0002 open the direction a leak would travel: 0002's warning would vanish.
  # Code and path are matched by separate greps rather than one pattern: a downgraded finding is
  # relabelled and moves the code from the front of the line to the end, so no positional regex
  # spans both shapes. The assertion is about which record was named, not how.
  d="$SCRATCH/reviewby_no_leak"
  new_repo "$d"
  write_record "$d" "0001-resolved.md" "> **Resolved by PR #12** (2026-01-01)" docs/debt "2020-01-01"
  write_record "$d" "0002-open.md" Open docs/debt "2020-01-01"
  git -C "$d" add -A
  git -C "$d" commit -qm base
  printf '  %-4s %-44s ' "" "resolved verdict does not leak to the next"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$(base_of "$d")" \
    ./.github/scripts/check-records.sh) >"$d/.out" 2>"$d/.err"; then
    if grep 'REVIEWBY-STALE' "$d/.err" | grep -q '0002-open\.md' &&
      ! grep 'REVIEWBY-STALE' "$d/.err" | grep -q '0001-resolved\.md'; then
      passed=$((passed + 1))
      printf 'ok   exit=0 warned for the open record only\n'
    else
      failed=$((failed + 1))
      printf 'FAIL staleness did not land on exactly the open record\n'
    fi
  else
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$(sed -n 's/^::error:://p' "$d/.err" | head -1)"
  fi

  d=$(case_dir orphan_target Open "src/gone.ts")
  run_case "orphaned target warns only" 0 W-ORPHAN-TARGET "$d" BASE_SHA="$(base_of "$d")"

  d=$(case_dir duplicate_number)
  write_record "$d" "0001-second.md"
  run_case "duplicate record number" 1 E-DUP-NUMBER "$d" BASE_SHA="$(base_of "$d")"

  d=$(case_dir stray_md)
  printf 'not a record\n' >"$d/docs/debt/notes.md"
  run_case "stray markdown file" 1 E-NOT-RECORD "$d" BASE_SHA="$(base_of "$d")"

  d=$(case_dir stray_txt)
  printf 'not a record\n' >"$d/docs/debt/notes.txt"
  run_case "stray non-markdown file" 1 E-NOT-RECORD "$d" BASE_SHA="$(base_of "$d")"

  printf -- '-- disappearance vectors --\n'
  d=$(case_dir deleted)
  b=$(base_of "$d")
  git -C "$d" rm -q docs/debt/0001-valid.md
  run_case "record deleted" 1 E-GONE "$d" BASE_SHA="$b"

  d=$(case_dir renamed)
  b=$(base_of "$d")
  git -C "$d" mv docs/debt/0001-valid.md docs/debt/0001-valid.md.retired
  run_case "renamed to a non-record name" 1 E-GONE "$d" BASE_SHA="$b"

  d=$(case_dir moved_subdir)
  b=$(base_of "$d")
  mkdir -p "$d/docs/debt/archive"
  git -C "$d" mv docs/debt/0001-valid.md docs/debt/archive/0001-valid.md
  run_case "moved into a subdirectory" 1 E-GONE "$d" BASE_SHA="$b"

  d=$(case_dir symlink_record)
  b=$(base_of "$d")
  printf 'decoy\n' >"$d/docs/decoy.md"
  git -C "$d" rm -q docs/debt/0001-valid.md
  mkdir -p "$d/docs/debt" # git removes the now-empty directory
  ln -s ../decoy.md "$d/docs/debt/0001-valid.md"
  run_case "record replaced by a symlink" 1 E-RECORD-SYMLINK "$d" BASE_SHA="$b"

  d=$(case_dir symlink_dir)
  b=$(base_of "$d")
  mkdir -p "$d/real-debt"
  git -C "$d" rm -qr docs/debt
  mkdir -p "$d/docs" # git removes docs/ once it is empty
  ln -s ../real-debt "$d/docs/debt"
  run_case "record directory replaced by a symlink" 1 E-DIR-SYMLINK "$d" BASE_SHA="$b"

  d=$(case_dir symlink_collapse)
  b=$(base_of "$d")
  write_record "$d" "0002-other.md"
  git -C "$d" add -A
  git -C "$d" commit -qm two
  b=$(base_of "$d")
  git -C "$d" rm -q docs/debt/0001-valid.md
  ln -s 0002-other.md "$d/docs/debt/0001-valid.md"
  run_case "two records collapsed via symlink" 1 E-RECORD-SYMLINK "$d" BASE_SHA="$b"

  printf -- '-- the gate defends itself --\n'
  d=$(case_dir gate_script_deleted)
  b=$(base_of "$d")
  git -C "$d" rm -q .github/scripts/check-records.sh
  # Restore an untracked copy so the checker can still run and report its own removal.
  mkdir -p "$d/.github/scripts"
  cp "$CHECKER" "$d/.github/scripts/check-records.sh"
  run_case "checker deleted in the diff" 1 E-GATE-GONE "$d" BASE_SHA="$b"

  d=$(case_dir gate_workflow_deleted)
  b=$(base_of "$d")
  git -C "$d" rm -q .github/workflows/records.yml
  run_case "workflow deleted in the diff" 1 E-GATE-GONE "$d" BASE_SHA="$b"

  d=$(case_dir gate_suite_deleted)
  b=$(base_of "$d")
  cp "$SCRIPT_DIR/check-records-test.sh" "$d/.github/scripts/check-records-test.sh"
  git -C "$d" add -A
  git -C "$d" commit -qm "add the suite"
  b=$(base_of "$d")
  git -C "$d" rm -q .github/scripts/check-records-test.sh
  run_case "suite deleted in the diff" 1 E-GATE-GONE "$d" BASE_SHA="$b"

  # The gate held itself to a weaker standard than the records: [ -f ] follows a symlink,
  # so a gate file swapped for a tracked link to something inert passed.
  d=$(case_dir gate_symlinked)
  b=$(base_of "$d")
  printf 'name: inert\n' >"$d/.github/workflows/inert.yml"
  rm "$d/.github/workflows/records.yml"
  ln -s inert.yml "$d/.github/workflows/records.yml"
  git -C "$d" add -A
  git -C "$d" commit -qm "swap the workflow for a link"
  run_case "gate file replaced by a tracked symlink" 1 E-GATE-SYMLINK "$d" BASE_SHA="$b"

  printf -- '-- the gate survives renaming itself --\n'
  # A rename empties the base-ref-derived protected set, because every path gate_paths
  # derives is new and no declared predecessor covers this particular rename. That must
  # fail rather than pass quietly. Built by hand rather than via case_dir/new_repo: the
  # latter always includes a profiles/ directory at the base commit, which would keep the
  # protected set non-empty regardless of the rename and defeat the case.
  d="$SCRATCH/renamed_gate"
  mkdir -p "$d/docs/debt" "$d/.github/scripts" "$d/.github/workflows"
  git -C "$d" init -q .
  git -C "$d" config user.email test@example.invalid
  git -C "$d" config user.name "check-records test"
  cp "$SCRIPT_DIR/check-records.sh" "$d/.github/scripts/check-records.sh"
  chmod +x "$d/.github/scripts/check-records.sh"
  cat >"$d/.github/workflows/records.yml" <<'YAML'
name: records
on: pull_request
jobs:
  records:
    runs-on: ubuntu-latest
    steps:
      - run: ./.github/scripts/check-records.sh
YAML
  write_record "$d" "0001-valid.md"
  git -C "$d" add -A
  git -C "$d" commit -qm base
  b=$(base_of "$d")
  git -C "$d" mv .github/scripts/check-records.sh .github/scripts/check-renamed.sh
  # Needed for the run below to get past profile resolution; not present at the base
  # commit, so it does not pad the protected-set count.
  mkdir -p "$d/.github/scripts/profiles"
  cp "$SCRIPT_DIR/profiles/debt.sh" "$d/.github/scripts/profiles/debt.sh"
  printf '  %-4s %-44s ' "" "gate renamed with no predecessor declared"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$b" \
    ./.github/scripts/check-renamed.sh) >"$d/.o" 2>"$d/.e"; then
    failed=$((failed + 1))
    printf 'FAIL passed with an undeclared rename\n'
  elif grep -q '::error::E-GATE-EMPTY-SET: ' "$d/.e"; then
    passed=$((passed + 1))
    printf 'ok   exit=1 E-GATE-EMPTY-SET\n'
  else
    failed=$((failed + 1))
    printf 'FAIL failed for another reason: %s\n' "$(sed -n 's/^::error:://p' "$d/.e" | head -1)"
  fi

  # A rename must still be caught even when the repo's own workflow happens to sit at the
  # literal path one of GATE_PREDECESSORS' own path-form entries names
  # (.github/workflows/debt.yml — the exact filename the adoption table has told every
  # adopter to create). That literal path must never be checked directly regardless of
  # this repo: gate_paths's predecessor loop excludes any .github/workflows/* key for
  # exactly this reason. Without the exclusion, this fixture's own untouched debt.yml —
  # wholly unrelated to the undeclared script rename below — would keep the protected set
  # non-empty and mask it, turning E-GATE-EMPTY-SET into a silent pass. Deliberately not
  # named records.yml, unlike every other fixture in this suite: the collision this case
  # exists to catch is specifically with the literal old name.
  d="$SCRATCH/renamed_gate_workflow_collision"
  mkdir -p "$d/docs/debt" "$d/.github/scripts" "$d/.github/workflows"
  git -C "$d" init -q .
  git -C "$d" config user.email test@example.invalid
  git -C "$d" config user.name "check-records test"
  cp "$SCRIPT_DIR/check-records.sh" "$d/.github/scripts/check-records.sh"
  chmod +x "$d/.github/scripts/check-records.sh"
  cat >"$d/.github/workflows/debt.yml" <<'YAML'
name: debt
on: pull_request
jobs:
  records:
    runs-on: ubuntu-latest
    steps:
      - run: ./.github/scripts/check-records.sh
YAML
  write_record "$d" "0001-valid.md"
  git -C "$d" add -A
  git -C "$d" commit -qm base
  b=$(base_of "$d")
  git -C "$d" mv .github/scripts/check-records.sh .github/scripts/check-renamed.sh
  mkdir -p "$d/.github/scripts/profiles"
  cp "$SCRIPT_DIR/profiles/debt.sh" "$d/.github/scripts/profiles/debt.sh"
  printf '  %-4s %-44s ' "" "undeclared rename, workflow shares the old literal path"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$b" \
    ./.github/scripts/check-renamed.sh) >"$d/.o" 2>"$d/.e"; then
    failed=$((failed + 1))
    printf 'FAIL passed with an undeclared rename\n'
  elif grep -q '::error::E-GATE-EMPTY-SET: ' "$d/.e"; then
    passed=$((passed + 1))
    printf 'ok   exit=1 E-GATE-EMPTY-SET\n'
  else
    failed=$((failed + 1))
    printf 'FAIL failed for another reason: %s\n' "$(sed -n 's/^::error:://p' "$d/.e" | head -1)"
  fi

  # The other half of E-GATE-EMPTY-SET: a rename that *does* declare its predecessor is
  # exempt, and only where the named successor exists as a tracked, non-symlink regular file.
  # A gate that moves directories needs the path form, since the old path is not under the new
  # SELF_DIR at all.
  d="$SCRATCH/declared_rename"
  mkdir -p "$d/docs/debt" "$d/ci/profiles" "$d/.github/workflows"
  git -C "$d" init -q .
  git -C "$d" config user.email test@example.invalid
  git -C "$d" config user.name "check-records test"
  cp "$SCRIPT_DIR/check-records.sh" "$d/ci/check-records.sh"
  cp "$SCRIPT_DIR/profiles/debt.sh" "$d/ci/profiles/debt.sh"
  chmod +x "$d/ci/check-records.sh"
  cat >"$d/.github/workflows/records.yml" <<'YAML'
name: records
on: pull_request
jobs:
  records:
    runs-on: ubuntu-latest
    steps:
      - run: ./ci/check-records.sh
YAML
  write_record "$d" "0001-valid.md"
  git -C "$d" add -A
  git -C "$d" commit -qm base
  b=$(base_of "$d")
  git -C "$d" mv ci scripts
  # Declare the move, the way a renaming PR does: two path-form entries prepended to the
  # constant. The tabs below are literal tab characters in the shell string. Each entry is
  # passed as its own single-line -v var and joined inside awk with a separate print per
  # line — a sed replacement with \t and \n would produce those two characters literally on
  # BSD sed and silently declare nothing, and a single multi-line -v value is a GNU-awk-only
  # extension that BSD/one-true awk (macOS) rejects outright.
  ins1="ci/check-records.sh	scripts/check-records.sh"
  ins2="ci/profiles/debt.sh	scripts/profiles/debt.sh"
  awk -v ins1="$ins1" -v ins2="$ins2" '
    /^GATE_PREDECESSORS="/ && !seen {
      print "GATE_PREDECESSORS=\"" ins1
      print ins2
      sub(/^GATE_PREDECESSORS="/, "")
      seen = 1
    }
    { print }
  ' "$d/scripts/check-records.sh" >"$d/.chk"
  mv "$d/.chk" "$d/scripts/check-records.sh"
  chmod +x "$d/scripts/check-records.sh"
  grep -c "$(printf 'ci/check-records.sh\tscripts/check-records.sh')" \
    "$d/scripts/check-records.sh" >/dev/null # must print 1; guards against a silent no-op
  git -C "$d" add -A
  printf '  %-4s %-44s ' "" "declared directory rename is exempt"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$b" \
    ./scripts/check-records.sh) >"$d/.o" 2>"$d/.e"; then
    if grep -q 'was renamed to' "$d/.o"; then
      passed=$((passed + 1))
      printf 'ok   exit=0 predecessor exempted\n'
    else
      failed=$((failed + 1))
      printf 'FAIL exit=0 but no rename note printed\n'
    fi
  else
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$(sed -n 's/^::error:://p' "$d/.e" | head -1)"
  fi

  d=$(case_dir basename_rename)
  b=$(base_of "$d")
  git -C "$d" mv .github/scripts/check-records.sh .github/scripts/check-gate.sh
  ins="check-records.sh	check-gate.sh"
  awk -v ins="$ins" '
    /^GATE_PREDECESSORS="/ && !seen {
      print "GATE_PREDECESSORS=\"" ins
      sub(/^GATE_PREDECESSORS="/, "")
      seen = 1
    }
    { print }
  ' "$d/.github/scripts/check-gate.sh" >"$d/.chk"
  mv "$d/.chk" "$d/.github/scripts/check-gate.sh"
  chmod +x "$d/.github/scripts/check-gate.sh"
  git -C "$d" add -A
  printf '  %-4s %-44s ' "" "declared same-directory rename is exempt"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$b" \
    ./.github/scripts/check-gate.sh) >"$d/.o" 2>"$d/.e"; then
    if grep -q 'was renamed to' "$d/.o"; then
      passed=$((passed + 1))
      printf 'ok   exit=0 basename predecessor exempted\n'
    else
      failed=$((failed + 1))
      printf 'FAIL exit=0 but no rename note printed\n'
    fi
  else
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$(sed -n 's/^::error:://p' "$d/.e" | head -1)"
  fi

  # A gate script renamed across directories *and* to a new basename, in the same commit
  # as its workflow's rename, with both declared. The predecessor-path loop in gate_paths
  # excludes .github/workflows/* keys unconditionally (renamed_gate_workflow_collision
  # above is why), so the workflow predecessor can only enter the protected set through the
  # needle search — and the needle search only fires on a basename the mapping itself
  # retired. This proves that path end to end: the needle "check-gate.sh" (this entry's own
  # key basename, differing from its own successor's basename "check-records.sh") finds the
  # base ref's workflow, which is what makes the exemption reachable at all; the exemption
  # itself then comes from the separately declared workflow entry.
  d="$SCRATCH/renamed_gate_and_workflow"
  mkdir -p "$d/docs/debt" "$d/ci/profiles" "$d/.github/workflows"
  git -C "$d" init -q .
  git -C "$d" config user.email test@example.invalid
  git -C "$d" config user.name "check-records test"
  cp "$SCRIPT_DIR/check-records.sh" "$d/ci/check-gate.sh"
  cp "$SCRIPT_DIR/profiles/debt.sh" "$d/ci/profiles/debt.sh"
  chmod +x "$d/ci/check-gate.sh"
  cat >"$d/.github/workflows/gate.yml" <<'YAML'
name: gate
on: pull_request
jobs:
  records:
    runs-on: ubuntu-latest
    steps:
      - run: ./ci/check-gate.sh
YAML
  write_record "$d" "0001-valid.md"
  git -C "$d" add -A
  git -C "$d" commit -qm base
  b=$(base_of "$d")
  git -C "$d" mv ci scripts
  git -C "$d" mv scripts/check-gate.sh scripts/check-records.sh
  git -C "$d" mv .github/workflows/gate.yml .github/workflows/records.yml
  ins1="ci/check-gate.sh	scripts/check-records.sh"
  ins2=".github/workflows/gate.yml	.github/workflows/records.yml"
  awk -v ins1="$ins1" -v ins2="$ins2" '
    /^GATE_PREDECESSORS="/ && !seen {
      print "GATE_PREDECESSORS=\"" ins1
      print ins2
      sub(/^GATE_PREDECESSORS="/, "")
      seen = 1
    }
    { print }
  ' "$d/scripts/check-records.sh" >"$d/.chk"
  mv "$d/.chk" "$d/scripts/check-records.sh"
  chmod +x "$d/scripts/check-records.sh"
  git -C "$d" add -A
  printf '  %-4s %-44s ' "" "declared cross-directory rename of gate and workflow"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$b" \
    ./scripts/check-records.sh) >"$d/.o" 2>"$d/.e"; then
    if grep -qF 'ci/check-gate.sh was renamed to scripts/check-records.sh' "$d/.o" &&
      grep -qF '.github/workflows/gate.yml was renamed to .github/workflows/records.yml' "$d/.o"; then
      passed=$((passed + 1))
      printf 'ok   exit=0 script and workflow predecessors exempted\n'
    else
      failed=$((failed + 1))
      printf 'FAIL exit=0 but expected rename notes missing\n'
    fi
  else
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$(sed -n 's/^::error:://p' "$d/.e" | head -1)"
  fi

  # Same rename, but the workflow half is left undeclared. The needle still discovers the
  # base ref's workflow — the needle search does not consult the workflow mapping at all —
  # so it still enters the protected set; with no successor declared for it, that must
  # report E-GATE-GONE rather than pass or silently drop the workflow from the set.
  d="$SCRATCH/renamed_gate_and_workflow_undeclared"
  mkdir -p "$d/docs/debt" "$d/ci/profiles" "$d/.github/workflows"
  git -C "$d" init -q .
  git -C "$d" config user.email test@example.invalid
  git -C "$d" config user.name "check-records test"
  cp "$SCRIPT_DIR/check-records.sh" "$d/ci/check-gate.sh"
  cp "$SCRIPT_DIR/profiles/debt.sh" "$d/ci/profiles/debt.sh"
  chmod +x "$d/ci/check-gate.sh"
  cat >"$d/.github/workflows/gate.yml" <<'YAML'
name: gate
on: pull_request
jobs:
  records:
    runs-on: ubuntu-latest
    steps:
      - run: ./ci/check-gate.sh
YAML
  write_record "$d" "0001-valid.md"
  git -C "$d" add -A
  git -C "$d" commit -qm base
  b=$(base_of "$d")
  git -C "$d" mv ci scripts
  git -C "$d" mv scripts/check-gate.sh scripts/check-records.sh
  git -C "$d" mv .github/workflows/gate.yml .github/workflows/records.yml
  ins="ci/check-gate.sh	scripts/check-records.sh"
  awk -v ins="$ins" '
    /^GATE_PREDECESSORS="/ && !seen {
      print "GATE_PREDECESSORS=\"" ins
      sub(/^GATE_PREDECESSORS="/, "")
      seen = 1
    }
    { print }
  ' "$d/scripts/check-records.sh" >"$d/.chk"
  mv "$d/.chk" "$d/scripts/check-records.sh"
  chmod +x "$d/scripts/check-records.sh"
  git -C "$d" add -A
  printf '  %-4s %-44s ' "" "cross-directory workflow rename left undeclared"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$b" \
    ./scripts/check-records.sh) >"$d/.o" 2>"$d/.e"; then
    failed=$((failed + 1))
    printf 'FAIL passed with an undeclared workflow rename\n'
  elif grep -q '::error::E-GATE-GONE: \.github/workflows/gate\.yml ' "$d/.e"; then
    passed=$((passed + 1))
    printf 'ok   exit=1 E-GATE-GONE\n'
  else
    failed=$((failed + 1))
    printf 'FAIL failed for another reason: %s\n' "$(sed -n 's/^::error:://p' "$d/.e" | head -1)"
  fi

  # The gate's own protected-path witness, unable to run. It used to be `git cat-file -e ... ||
  # continue`, so a fault silently dropped the path from the protected set — the one condition
  # the self-protection rule exists to detect. The fault must be named, and the path must still
  # count, or the empty-set branch would go on to report a bootstrap.
  d=$(case_dir gate_self_scan_fault)
  b=$(base_of "$d")
  stub_bin="$SCRATCH/git-gate-fault-bin"
  mkdir -p "$stub_bin"
  real_git=$(command -v git)
  cat >"$stub_bin/git" <<STUB
#!/usr/bin/env bash
if [ "\$1" = ls-tree ]; then
  for arg in "\$@"; do
    if [ "\$arg" = .github/scripts/check-records.sh ]; then
      printf 'fatal: fixture-fault: simulated object store error\n' >&2
      exit 128
    fi
  done
fi
exec "$real_git" "\$@"
STUB
  chmod +x "$stub_bin/git"
  run_case "gate file witness faults, not silently unprotected" 1 E-GATE-SCAN "$d" \
    BASE_SHA="$b" PATH="$stub_bin:$PATH"

  # A base ref that predates the gate is the adoption PR, and it must not be red — and it
  # must say why, per the same discipline as every other rule: assert both the exit status
  # and which code fired. Bespoke rather than run_case: I-GATE-BOOTSTRAP is informational,
  # emitted via `info` to stdout, not the `::[a-z]*::CODE: ` stderr form run_case greps for,
  # so run_case's code assertion cannot express it. Without this, deleting the `info` line
  # entirely would leave the suite green — already-passing exit=0 is not evidence the rule
  # fired.
  d="$SCRATCH/bootstrap"
  mkdir -p "$d/docs/debt" "$d/.github/scripts/profiles" "$d/.github/workflows"
  git -C "$d" init -q .
  git -C "$d" config user.email test@example.invalid
  git -C "$d" config user.name "check-records test"
  printf 'placeholder\n' >"$d/README.md"
  git -C "$d" add -A
  git -C "$d" commit -qm "before the gate"
  b=$(base_of "$d")
  cp "$SCRIPT_DIR/check-records.sh" "$d/.github/scripts/"
  cp "$SCRIPT_DIR/profiles/debt.sh" "$d/.github/scripts/profiles/"
  chmod +x "$d/.github/scripts/check-records.sh"
  write_record "$d" "0001-first.md"
  git -C "$d" add -A
  printf '  %-4s %-44s ' "" "base ref predates the gate"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$b" \
    ./.github/scripts/check-records.sh) >"$d/.out" 2>"$d/.err"; then
    if grep -q 'I-GATE-BOOTSTRAP' "$d/.out"; then
      passed=$((passed + 1))
      printf 'ok   exit=0 I-GATE-BOOTSTRAP\n'
    else
      failed=$((failed + 1))
      printf 'FAIL exit=0 but I-GATE-BOOTSTRAP never printed\n'
    fi
  else
    failed=$((failed + 1))
    printf 'FAIL failed for another reason: %s\n' "$(sed -n 's/^::error:://p' "$d/.err" | head -1)"
  fi

  # The same bootstrap shape with a witness that cannot run. gate_existed_at is only reached
  # when the protected set came out empty, which is exactly what the bootstrap fixture
  # produces, so it is reused for both witnesses below. A fault used to be indistinguishable
  # from every witness finding nothing, reporting the exit-0 I-GATE-BOOTSTRAP over a scan that
  # never happened -- the silent pass an undeclared rename would hide behind.
  #
  # The SELF_DIR witness. Keyed on `.github/scripts/debt.sh`: gate_known_basenames offers it
  # (the profiles predecessor mapping retires that basename) but gate_paths never emits it,
  # because that mapping's key carries a slash and so resolves to its own path rather than a
  # SELF_DIR sibling. A key gate_paths did emit would fault at the protected-path witness
  # first, count the path, and take check_gate_files out of the empty-set branch entirely.
  stub_bin="$SCRATCH/git-witness-selfdir-bin"
  mkdir -p "$stub_bin"
  real_git=$(command -v git)
  cat >"$stub_bin/git" <<STUB
#!/usr/bin/env bash
if [ "\$1" = ls-tree ]; then
  for arg in "\$@"; do
    if [ "\$arg" = .github/scripts/debt.sh ]; then
      printf 'fatal: fixture-fault: simulated object store error\n' >&2
      exit 128
    fi
  done
fi
exec "$real_git" "\$@"
STUB
  chmod +x "$stub_bin/git"
  printf '  %-4s %-44s ' "" "SELF_DIR witness faults, not a bootstrap"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$b" \
    PATH="$stub_bin:$PATH" ./.github/scripts/check-records.sh) >"$d/.o2" 2>"$d/.e2"; then
    failed=$((failed + 1))
    printf 'FAIL exit=0 on a witness that never ran\n'
  elif grep -q '::error::E-GATE-WITNESS-SCAN: ' "$d/.e2"; then
    passed=$((passed + 1))
    printf 'ok   exit=1 E-GATE-WITNESS-SCAN\n'
  else
    failed=$((failed + 1))
    printf 'FAIL failed for another reason: %s\n' "$(sed -n 's/^::error:://p' "$d/.e2" | head -1)"
  fi

  # The workflow witness, reached only once the SELF_DIR witness has found nothing -- which is
  # this fixture's ordinary state, so no stubbing of the first witness is needed to get here.
  stub_bin="$SCRATCH/git-witness-workflow-bin"
  mkdir -p "$stub_bin"
  cat >"$stub_bin/git" <<STUB
#!/usr/bin/env bash
if [ "\$1" = grep ]; then
  for arg in "\$@"; do
    if [ "\$arg" = .github/workflows ]; then
      printf 'fatal: fixture-fault: simulated object store error\n' >&2
      exit 128
    fi
  done
fi
exec "$real_git" "\$@"
STUB
  chmod +x "$stub_bin/git"
  printf '  %-4s %-44s ' "" "workflow witness faults, not a bootstrap"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$b" \
    PATH="$stub_bin:$PATH" ./.github/scripts/check-records.sh) >"$d/.o3" 2>"$d/.e3"; then
    failed=$((failed + 1))
    printf 'FAIL exit=0 on a witness that never ran\n'
  elif grep -q '::error::E-GATE-WITNESS-SCAN: ' "$d/.e3"; then
    passed=$((passed + 1))
    printf 'ok   exit=1 E-GATE-WITNESS-SCAN\n'
  else
    failed=$((failed + 1))
    printf 'FAIL failed for another reason: %s\n' "$(sed -n 's/^::error:://p' "$d/.e3" | head -1)"
  fi

  # gate_existed_at has two witnesses, and `renamed_gate` above happens to satisfy both at
  # once (its base-ref workflow names "check-records.sh", which is also the literal
  # basename sitting in SELF_DIR at that ref) — so neither witness is individually proven.
  # These two isolate them: no workflow at all reaches only the SELF_DIR witness, and a
  # gate that moved directories as well as names reaches only the workflow witness.
  d="$SCRATCH/renamed_no_workflow"
  mkdir -p "$d/docs/debt" "$d/.github/scripts"
  git -C "$d" init -q .
  git -C "$d" config user.email test@example.invalid
  git -C "$d" config user.name "check-records test"
  cp "$SCRIPT_DIR/check-records.sh" "$d/.github/scripts/check-records.sh"
  chmod +x "$d/.github/scripts/check-records.sh"
  write_record "$d" "0001-valid.md"
  git -C "$d" add -A
  git -C "$d" commit -qm base
  b=$(base_of "$d")
  git -C "$d" mv .github/scripts/check-records.sh .github/scripts/check-renamed.sh
  mkdir -p "$d/.github/scripts/profiles"
  cp "$SCRIPT_DIR/profiles/debt.sh" "$d/.github/scripts/profiles/debt.sh"
  printf '  %-4s %-44s ' "" "SELF_DIR witness alone: renamed, no workflow at all"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$b" \
    ./.github/scripts/check-renamed.sh) >"$d/.o" 2>"$d/.e"; then
    failed=$((failed + 1))
    printf 'FAIL passed with an undeclared rename\n'
  elif grep -q '::error::E-GATE-EMPTY-SET: ' "$d/.e"; then
    passed=$((passed + 1))
    printf 'ok   exit=1 E-GATE-EMPTY-SET\n'
  else
    failed=$((failed + 1))
    printf 'FAIL failed for another reason: %s\n' "$(sed -n 's/^::error:://p' "$d/.e" | head -1)"
  fi

  d="$SCRATCH/renamed_moved_dir"
  mkdir -p "$d/docs/debt" "$d/.github/workflows"
  git -C "$d" init -q .
  git -C "$d" config user.email test@example.invalid
  git -C "$d" config user.name "check-records test"
  cp "$SCRIPT_DIR/check-records.sh" "$d/check-records.sh"
  chmod +x "$d/check-records.sh"
  # A repo-root gate layout: the script lives at the repo root at the base ref, invoked
  # from there, so nothing under the current SELF_DIR (.github/scripts, once it moves)
  # exists at that ref — only the workflow names it.
  cat >"$d/.github/workflows/records.yml" <<'YAML'
name: records
on: pull_request
jobs:
  records:
    runs-on: ubuntu-latest
    steps:
      - run: ./check-records.sh
YAML
  write_record "$d" "0001-valid.md"
  git -C "$d" add -A
  git -C "$d" commit -qm base
  b=$(base_of "$d")
  mkdir -p "$d/.github/scripts/profiles"
  git -C "$d" mv check-records.sh .github/scripts/check-renamed.sh
  cp "$SCRIPT_DIR/profiles/debt.sh" "$d/.github/scripts/profiles/debt.sh"
  printf '  %-4s %-44s ' "" "workflow witness alone: renamed and moved directories"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$b" \
    ./.github/scripts/check-renamed.sh) >"$d/.o" 2>"$d/.e"; then
    failed=$((failed + 1))
    printf 'FAIL passed with an undeclared rename\n'
  elif grep -q '::error::E-GATE-EMPTY-SET: ' "$d/.e"; then
    passed=$((passed + 1))
    printf 'ok   exit=1 E-GATE-EMPTY-SET\n'
  else
    failed=$((failed + 1))
    printf 'FAIL failed for another reason: %s\n' "$(sed -n 's/^::error:://p' "$d/.e" | head -1)"
  fi

  # gate_known_basenames' `.sh`-only filter is what keeps a `.yml` GATE_PREDECESSORS
  # basename out of the bootstrap witness. Without it, "records.yml" — a basename from the
  # mapping's own debt.yml -> records.yml entries — becomes a known basename, and
  # gate_existed_at's workflow-content witness matches it against any base-ref workflow that
  # merely mentions "records.yml" for an unrelated reason. That turns a legitimate adoption's
  # I-GATE-BOOTSTRAP into E-GATE-EMPTY-SET: the false red the closed set exists to prevent.
  d="$SCRATCH/bootstrap_unrelated_yml_mention"
  mkdir -p "$d/docs/debt" "$d/.github/workflows"
  git -C "$d" init -q .
  git -C "$d" config user.email test@example.invalid
  git -C "$d" config user.name "check-records test"
  cat >"$d/.github/workflows/unrelated.yml" <<'YAML'
name: unrelated
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      # see shared/skills/tome-of-lore/assets/records.yml for the gate config elsewhere
      - run: echo hello
YAML
  git -C "$d" add -A
  git -C "$d" commit -qm "before the gate, with an unrelated records.yml mention"
  b=$(base_of "$d")
  mkdir -p "$d/.github/scripts/profiles"
  cp "$SCRIPT_DIR/check-records.sh" "$d/.github/scripts/"
  cp "$SCRIPT_DIR/profiles/debt.sh" "$d/.github/scripts/profiles/"
  chmod +x "$d/.github/scripts/check-records.sh"
  write_record "$d" "0001-first.md"
  git -C "$d" add -A
  printf '  %-4s %-44s ' "" "unrelated records.yml mention doesn't defeat bootstrap"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$b" \
    ./.github/scripts/check-records.sh) >"$d/.out" 2>"$d/.err"; then
    if grep -q 'I-GATE-BOOTSTRAP' "$d/.out"; then
      passed=$((passed + 1))
      printf 'ok   exit=0 I-GATE-BOOTSTRAP\n'
    else
      failed=$((failed + 1))
      printf 'FAIL exit=0 but I-GATE-BOOTSTRAP never printed\n'
    fi
  else
    failed=$((failed + 1))
    printf 'FAIL failed for another reason: %s\n' "$(sed -n 's/^::error:://p' "$d/.err" | head -1)"
  fi

  # gate_paths' needle loop has the same `.sh`-only filter, guarding the protected set rather
  # than the bootstrap witness. Without it, "debt.yml" — the retired basename in the
  # .github/workflows/debt.yml -> records.yml mapping entry — becomes a needle, and any
  # base-ref workflow whose text merely contains "debt.yml" (a comment, a stale filename
  # reference, nothing to do with this gate) is pulled into the protected set by content
  # match. Deleting that unrelated workflow must be allowed; without the filter it reports
  # E-GATE-GONE on a file that was never part of the gate.
  d="$SCRATCH/unrelated_workflow_not_a_needle"
  mkdir -p "$d/docs/debt" "$d/.github/workflows" "$d/.github/scripts/profiles"
  git -C "$d" init -q .
  git -C "$d" config user.email test@example.invalid
  git -C "$d" config user.name "check-records test"
  cat >"$d/.github/workflows/unrelated.yml" <<'YAML'
name: unrelated
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      # migrated from debt.yml a while back, unrelated to the tome-of-lore gate
      - run: echo hello
YAML
  cp "$SCRIPT_DIR/check-records.sh" "$d/.github/scripts/check-records.sh"
  cp "$SCRIPT_DIR/profiles/debt.sh" "$d/.github/scripts/profiles/debt.sh"
  chmod +x "$d/.github/scripts/check-records.sh"
  write_record "$d" "0001-valid.md"
  git -C "$d" add -A
  git -C "$d" commit -qm base
  b=$(base_of "$d")
  git -C "$d" rm -q .github/workflows/unrelated.yml
  run_case "unrelated workflow mentioning a retired basename is not a needle" 0 - "$d" \
    BASE_SHA="$b"

  # Isolating fixtures. The cases above trip several rules at once, so none of them can
  # attribute a failure to the rule it is named for — a checker with its symlink rules
  # deleted still failed them via E-GONE. These commit the symlink, so the record stays
  # tracked and present and only the symlink rule can fire.
  printf -- '-- one rule at a time (mutation isolation) --\n'
  d=$(case_dir tracked_symlink_record)
  write_record "$d" "0002-kept.md"
  git -C "$d" add -A
  git -C "$d" commit -qm two
  b=$(base_of "$d")
  rm "$d/docs/debt/0001-valid.md"
  ln -s 0002-kept.md "$d/docs/debt/0001-valid.md"
  git -C "$d" add -A
  git -C "$d" commit -qm "tracked symlink over a record"
  run_case "tracked symlink at a record path" 1 E-RECORD-SYMLINK "$d" BASE_SHA="$b"
  run_case "tracked symlink seen as a disappearance" 1 E-GONE-SYMLINK "$d" BASE_SHA="$b"

  d=$(case_dir tracked_symlink_dir)
  b=$(base_of "$d")
  mkdir -p "$d/real-debt"
  cp "$d/docs/debt/0001-valid.md" "$d/real-debt/0001-valid.md"
  git -C "$d" rm -qr docs/debt
  mkdir -p "$d/docs"
  ln -s ../real-debt "$d/docs/debt"
  git -C "$d" add -A
  git -C "$d" commit -qm "tracked symlink over the directory"
  run_case "tracked symlink at the directory" 1 E-DIR-SYMLINK "$d" BASE_SHA="$b"

  d=$(case_dir missing_from_disk)
  b=$(base_of "$d")
  rm "$d/docs/debt/0001-valid.md" # still tracked in the index, gone from the checkout
  run_case "record tracked but missing from disk" 1 E-GONE "$d" BASE_SHA="$b"

  d=$(case_dir untracked_record)
  b=$(base_of "$d")
  git -C "$d" rm -q --cached docs/debt/0001-valid.md
  run_case "record untracked but still on disk" 1 E-GONE "$d" BASE_SHA="$b"

  d=$(case_dir count_floor)
  b=$(base_of "$d")
  mkdir -p "$d/real-debt"
  git -C "$d" rm -qr docs/debt
  mkdir -p "$d/docs"
  ln -s ../real-debt "$d/docs/debt"
  git -C "$d" add -A
  git -C "$d" commit -qm "empty tree behind a symlink"
  run_case "base had records, tree enumerates none" 1 E-COUNT-FLOOR "$d" BASE_SHA="$b"

  # Removing a non-record file is allowed: the disappearance rule applies to records, not
  # to everything that ever sat in the directory. Without this case, deleting the filter
  # that selects records from the base ref leaves the suite green.
  d=$(case_dir stray_removed)
  printf 'not a record\n' >"$d/docs/debt/README.md"
  git -C "$d" add -A
  git -C "$d" commit -qm "add a stray file"
  b=$(base_of "$d")
  git -C "$d" rm -q docs/debt/README.md
  run_case "non-record file removed is allowed" 0 - "$d" BASE_SHA="$b"

  # The deadlock case: a duplicate number tells the author to renumber, and renumbering
  # used to trip the erasure rule. Both directions are asserted here.
  printf -- '-- renumbering and duplicate scope --\n'
  d=$(case_dir renumber_allowed)
  write_record "$d" "0002-b.md"
  git -C "$d" add -A
  git -C "$d" commit -qm "two records"
  b=$(base_of "$d")
  git -C "$d" mv docs/debt/0002-b.md docs/debt/0003-b.md
  run_case "renumber with content unchanged" 0 - "$d" BASE_SHA="$b"

  # The renumber note is the only thing distinguishing "this was renumbered, and that is
  # fine" from silence — without it, a green exit on a renumber looks identical to a green
  # exit on nothing having happened. Bespoke rather than a run_case code assertion: the note
  # is an info line on stdout, not the `::[a-z]*::CODE: ` stderr form run_case greps for, so
  # run_case's own assertions above cannot see it and would stay green if it were deleted.
  # Reuses $d/.out from the run_case call just above rather than invoking the checker again.
  printf '  %-4s %-44s ' "" "renumber note names both paths"
  if grep -qF 'docs/debt/0002-b.md was renumbered to docs/debt/0003-b.md' "$d/.out"; then
    passed=$((passed + 1))
    printf 'ok   renumber note printed\n'
  else
    failed=$((failed + 1))
    printf 'FAIL renumber note missing or names the wrong paths\n'
  fi

  # The same renumber, with the candidate witness unable to run. The witness answers "did
  # this destination already exist at the base ref"; a fault used to read as "it did not",
  # which silently promoted an unverified candidate. Reporting E-GONE here would be worse
  # than silence -- it asserts the record is gone on the strength of a search that never
  # happened -- so the fault must replace that verdict rather than accompany it.
  d=$(case_dir renumber_scan_fault)
  write_record "$d" "0002-b.md"
  git -C "$d" add -A
  git -C "$d" commit -qm "two records"
  b=$(base_of "$d")
  git -C "$d" mv docs/debt/0002-b.md docs/debt/0003-b.md
  stub_bin="$SCRATCH/git-renumber-fault-bin"
  mkdir -p "$stub_bin"
  real_git=$(command -v git)
  cat >"$stub_bin/git" <<STUB
#!/usr/bin/env bash
if [ "\$1" = ls-tree ]; then
  for arg in "\$@"; do
    if [ "\$arg" = docs/debt/0003-b.md ]; then
      printf 'fatal: fixture-fault: simulated object store error\n' >&2
      exit 128
    fi
  done
fi
exec "$real_git" "\$@"
STUB
  chmod +x "$stub_bin/git"
  run_case "renumber candidate scan faults, not reported gone" 1 E-RENUMBER-SCAN "$d" \
    BASE_SHA="$b" PATH="$stub_bin:$PATH"
  printf '  %-4s %-44s ' "" "scan fault replaces E-GONE"
  if grep -q '::error::E-GONE: ' "$d/.err"; then
    failed=$((failed + 1))
    printf 'FAIL E-GONE also fired for a search that never ran\n'
  else
    passed=$((passed + 1))
    printf 'ok   E-GONE suppressed\n'
  fi
  d=$(case_dir renumber_with_edit)
  write_record "$d" "0002-b.md"
  git -C "$d" add -A
  git -C "$d" commit -qm "two records"
  b=$(base_of "$d")
  git -C "$d" mv docs/debt/0002-b.md docs/debt/0003-b.md
  printf '\nedited after the move\n' >>"$d/docs/debt/0003-b.md"
  run_case "renumber with content changed" 1 E-GONE "$d" BASE_SHA="$b"

  d=$(case_dir two_renumbers_one_destination)
  write_record "$d" "0002-b.md"
  git -C "$d" add -A
  git -C "$d" commit -qm "two canonical look-alikes"
  b=$(base_of "$d")
  git -C "$d" rm -q docs/debt/0001-valid.md
  git -C "$d" mv docs/debt/0002-b.md docs/debt/0003-b.md
  run_case "two records cannot share one renumber target" 1 E-GONE "$d" BASE_SHA="$b"

  d=$(case_dir dup_introduced)
  b=$(base_of "$d")
  write_record "$d" "0001-second.md"
  run_case "duplicate introduced by the change" 1 E-DUP-NUMBER "$d" BASE_SHA="$b"

  d=$(case_dir dup_pre_existing)
  write_record "$d" "0001-second.md"
  git -C "$d" add -A
  git -C "$d" commit -qm "land a duplicate"
  b=$(base_of "$d")
  run_case "duplicate already in the base ref" 0 W-DUP-PREEXISTING "$d" BASE_SHA="$b"

  # Adoption is the path every consuming repo takes, and copying three files into place is
  # exactly the sort of step that is never verified until it fails in someone else's repo.
  # Install the assets the way the skill installs them, then run the installed gate.
  printf -- '-- adoption into a fresh repo --\n'
  adoption_cases

  # The rewrite vector: keep the path, keep the headings, gut the body. Cheaper than every
  # vector above and it defeats all of them, so it needs its own cases.
  printf -- '-- rewriting a merged record --\n'
  d=$(case_dir gutted)
  b=$(base_of "$d")
  write_record "$d" "0001-valid.md" "> **Resolved by PR #99** (2026-01-01)"
  cat >>"$d/docs/debt/0001-valid.md" <<'EOF'
EOF
  sed 's/^A real concern with a body\.$/Nothing much, actually./' "$d/docs/debt/0001-valid.md" >"$d/.t" && mv "$d/.t" "$d/docs/debt/0001-valid.md"
  run_case "concern gutted, banner added" 1 E-REWRITE "$d" BASE_SHA="$b"

  d=$(case_dir appended)
  b=$(base_of "$d")
  printf '\nFurther detail found later.\n' >>"$d/docs/debt/0001-valid.md"
  run_case "appending detail is allowed" 0 - "$d" BASE_SHA="$b"

  d=$(case_dir resolve_in_place)
  b=$(base_of "$d")
  sed 's/^Open$/> **Resolved by PR #7** (2026-02-01)/' "$d/docs/debt/0001-valid.md" >"$d/.t" && mv "$d/.t" "$d/docs/debt/0001-valid.md"
  run_case "resolving in place is allowed" 0 - "$d" BASE_SHA="$b"

  # The gate's own location. Reaching the repo through a symlink used to switch
  # self-protection off silently, because git reports a physical path and the script
  # captured a logical one.
  printf -- '-- the gate can locate itself --\n'
  d=$(case_dir via_symlink)
  # The fixture only tracks the checker, so the suite has to be committed before it can be
  # removed — removal is what E-GATE-GONE is meant to catch here.
  cp "$SCRIPT_DIR/check-records-test.sh" "$d/.github/scripts/check-records-test.sh"
  git -C "$d" add -A
  git -C "$d" commit -qm "track the suite"
  b=$(base_of "$d")
  git -C "$d" rm -q .github/scripts/check-records-test.sh
  cp "$SCRIPT_DIR/check-records-test.sh" "$d/.github/scripts/check-records-test.sh"
  ln -sfn "$d" "$SCRATCH/link-to-via_symlink"
  printf '  %-4s %-44s ' "" "repo reached through a symlink"
  if (cd "$SCRATCH/link-to-via_symlink" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$b" ./.github/scripts/check-records.sh) >"$d/.o" 2>"$d/.e"; then
    failed=$((failed + 1))
    printf 'FAIL self-protection was off through the symlink\n'
  elif grep -q '::error::E-GATE-GONE: ' "$d/.e"; then
    passed=$((passed + 1))
    printf 'ok   exit=1 E-GATE-GONE\n'
  else
    failed=$((failed + 1))
    printf 'FAIL failed for another reason: %s\n' "$(sed -n 's/^::error:://p' "$d/.e" | head -1)"
  fi

  printf -- '-- degraded paths must fail, not pass --\n'
  # These three reach branches that would otherwise be unfalsifiable: a mutation sweep
  # left each of them alive because nothing exercised them, which is indistinguishable
  # from shipping a guarantee the code does not provide.
  d="$SCRATCH/not_a_repo"
  mkdir -p "$d/docs/debt" "$d/.github/scripts"
  cp "$CHECKER" "$d/.github/scripts/check-records.sh"
  mkdir -p "$d/.github/scripts/profiles"
  cp "$SCRIPT_DIR/profiles/debt.sh" "$d/.github/scripts/profiles/"
  run_case "run outside any git repository" 1 E-NOT-REPO "$d" BASE_SHA=

  # chmod 000 does not stop root, so this case would fail in a container running as root —
  # a spurious red gate for an adopter, not a defect in the checker. Skip it there and say
  # so, rather than asserting something the environment cannot produce.
  if [ "$(id -u)" -eq 0 ]; then
    printf '  skip %-44s running as root; chmod 000 does not deny access\n' "record directory unreadable"
  else
    d=$(case_dir unreadable_dir)
    b=$(base_of "$d")
    chmod 000 "$d/docs/debt"
    run_case "record directory unreadable" 1 E-ENUM "$d" BASE_SHA="$b"
    chmod 755 "$d/docs/debt"
  fi

  # grep exits 1 for "no match" and 2 or more for a fault it hit while scanning -- an
  # unreadable file, a bad encoding. check_sections and check_headings_intact used to fold
  # that fault into "no match", reporting a spurious E-SECTION-MISSING/E-HEADING-REWRITTEN
  # (or, downstream of the same collapse, staying silent) instead of naming the scan that
  # never completed. A record made unreadable in place drives both through the same grep
  # call the checker makes on the working tree, on the same skip guard as the case above.
  if [ "$(id -u)" -eq 0 ]; then
    printf '  skip %-44s running as root; chmod 000 does not deny access\n' "record unreadable (section scan)"
    printf '  skip %-44s running as root; chmod 000 does not deny access\n' "record unreadable (heading scan)"
  else
    d=$(case_dir unreadable_record)
    b=$(base_of "$d")
    chmod 000 "$d/docs/debt/0001-valid.md"
    run_case "record unreadable (section scan)" 1 E-SECTION-SCAN "$d" BASE_SHA="$b"
    run_case "record unreadable (heading scan)" 1 E-HEADING-SCAN "$d" BASE_SHA="$b"
    chmod 644 "$d/docs/debt/0001-valid.md"
  fi

  # The same fault, once per profile rather than once per record: profile_check_directory's
  # grep over the ADR index README used to fold a scan fault into "no numbered rows", so
  # W-INDEX-TABLE would silently go unreported on a scan that never completed.
  if [ "$(id -u)" -eq 0 ]; then
    printf '  skip %-44s running as root; chmod 000 does not deny access\n' "ADR README unreadable (index scan)"
  else
    d=$(adr_dir index_scan_unreadable)
    b=$(base_of "$d")
    chmod 000 "$d/docs/adr/README.md"
    run_case "ADR README unreadable (index scan)" 1 E-INDEX-SCAN "$d" BASE_SHA="$b" RECORD_PROFILES=adr
    chmod 644 "$d/docs/adr/README.md"
  fi

  d=$(case_dir corrupt_base_tree)
  b=$(base_of "$d")
  # Delete the tree objects the base commit needs, so git ls-tree fails on a ref that
  # rev-parse still resolves — a damaged or partial object store, not a bad ref.
  while IFS= read -r obj; do
    sha="$(basename "$(dirname "$obj")")$(basename "$obj")"
    if [ "$(git -C "$d" cat-file -t "$sha" 2>/dev/null)" = tree ]; then
      rm -f "$obj"
    fi
  done < <(find "$d/.git/objects" -type f)
  run_case "base tree unreadable" 1 E-BASE-TREE "$d" BASE_SHA="$b"

  d=$(case_dir outside_tree)
  b=$(base_of "$d")
  mkdir -p "$SCRATCH/loose"
  cp "$SCRIPT_DIR/check-records.sh" "$SCRATCH/loose/check-records.sh"
  mkdir -p "$SCRATCH/loose/profiles"
  cp "$SCRIPT_DIR/profiles/debt.sh" "$SCRATCH/loose/profiles/"
  chmod +x "$SCRATCH/loose/check-records.sh"
  printf '  %-4s %-44s ' "" "checker run from outside the repo"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$b" "$SCRATCH/loose/check-records.sh") \
    >"$d/.o" 2>"$d/.e"; then
    failed=$((failed + 1))
    printf 'FAIL passed with self-protection off\n'
  elif grep -q '::error::E-GATE-UNLOCATABLE: ' "$d/.e"; then
    passed=$((passed + 1))
    printf 'ok   exit=1 E-GATE-UNLOCATABLE\n'
  else
    failed=$((failed + 1))
    printf 'FAIL failed for another reason: %s\n' "$(sed -n 's/^::error:://p' "$d/.e" | head -1)"
  fi

  d=$(case_dir bad_base)
  run_case "BASE_SHA is not a commit" 1 E-BASE-REF "$d" BASE_SHA=deadbeefdeadbeefdeadbeefdeadbeefdeadbeef

  # run_case can only assert a code is present, never that another is absent. A bad ref used
  # to be retried inside every profile's check_no_disappearances, which reported the same
  # rejection again as E-BASE-TREE (plus git's raw `fatal:` line on stderr) instead of once
  # as E-BASE-REF. Bespoke, in the style of outside_tree/via_symlink below.
  d=$(case_dir bad_base_single_code)
  printf '  %-4s %-44s ' "" "invalid BASE_SHA reports exactly one code"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt \
    BASE_SHA=deadbeefdeadbeefdeadbeefdeadbeefdeadbeef ./.github/scripts/check-records.sh) \
    >"$d/.out" 2>"$d/.err"; then
    failed=$((failed + 1))
    printf 'FAIL passed with a bad BASE_SHA\n'
  elif ! grep -q '::error::E-BASE-REF: ' "$d/.err"; then
    failed=$((failed + 1))
    printf 'FAIL E-BASE-REF never fired\n'
  elif grep -q '::error::E-BASE-TREE: ' "$d/.err"; then
    failed=$((failed + 1))
    printf 'FAIL E-BASE-TREE also fired for a ref check_base_ref already rejected\n'
  elif grep -q '^fatal:' "$d/.err"; then
    failed=$((failed + 1))
    printf 'FAIL raw git stderr leaked: %s\n' "$(grep '^fatal:' "$d/.err" | head -1)"
  else
    passed=$((passed + 1))
    printf 'ok   exit=1 E-BASE-REF only\n'
  fi

  d=$(case_dir empty_base_ci)
  run_case "empty BASE_SHA in CI" 1 E-BASE-EMPTY-CI "$d" BASE_SHA= GITHUB_ACTIONS=true

  d=$(case_dir empty_base_local)
  run_case "empty BASE_SHA locally" 0 - "$d" BASE_SHA=

  d=$(case_dir no_dir)
  b=$(base_of "$d")
  git -C "$d" rm -qr docs/debt
  run_case "directory removed entirely" 1 E-GONE "$d" BASE_SHA="$b"

  d=$(case_dir subdir_invocation)
  b=$(base_of "$d")
  mkdir -p "$d/docs/sub"
  printf '  ok   %-44s ' "run from a subdirectory"
  if (cd "$d/docs/sub" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$b" ../../.github/scripts/check-records.sh) >"$d/.out" 2>"$d/.err" &&
    grep -q 'Checking 1 deferral record' "$d/.out"; then
    passed=$((passed + 1))
    printf 'exit=0 validated from docs/sub\n'
  else
    failed=$((failed + 1))
    printf '\n  FAIL run from a subdirectory did not validate records\n'
    head -3 "$d/.err" | sed 's/^/         /'
  fi

  d=$(case_dir no_records_no_base)
  git -C "$d" rm -q docs/debt/0001-valid.md
  git -C "$d" commit -qm "no records"
  run_case "genuinely empty repo, no base" 0 - "$d" BASE_SHA=

  printf -- '-- profile selection --\n'
  d=$(case_dir no_profiles)
  b=$(base_of "$d")
  run_case "RECORD_PROFILES unset" 1 E-PROFILE-NONE "$d" BASE_SHA="$b" RECORD_PROFILES=

  d=$(case_dir unknown_profile)
  b=$(base_of "$d")
  run_case "unknown profile name" 1 E-PROFILE-UNKNOWN "$d" BASE_SHA="$b" RECORD_PROFILES=nope

  # Named for what the fixture does, not for the directory's whole history: case_dir
  # commits docs/debt with a record first, so it did exist at some point — just not at
  # $b2, the base ref this case actually uses.
  d=$(case_dir dir_removed_before_base)
  b=$(base_of "$d")
  git -C "$d" rm -qr docs/debt
  git -C "$d" commit -qm "drop records"
  b2=$(base_of "$d")
  run_case "record directory absent at both refs" 1 E-PROFILE-DIR-MISSING "$d" \
    BASE_SHA="$b2" RECORD_PROFILES=debt

  # The same question asked of a base ref that cannot be read. dir_in_ref used to test only
  # whether `git ls-tree` printed anything, discarding its status, so a scan that never ran
  # was indistinguishable from a directory that was never there -- and the run reported
  # E-PROFILE-DIR-MISSING, naming the wrong cause. The directory is removed from the working
  # tree only, uncommitted: the tree check short-circuits ahead of the witness, so a fixture
  # that leaves it in place never reaches the code under test.
  d=$(case_dir dir_scan_fault)
  b=$(base_of "$d")
  rm -r "$d/docs/debt"
  stub_bin="$SCRATCH/git-dir-fault-bin"
  mkdir -p "$stub_bin"
  real_git=$(command -v git)
  cat >"$stub_bin/git" <<STUB
#!/usr/bin/env bash
# Keyed on subcommand and pathspec together: three sites in this gate issue an ls-tree, and a
# stub keyed on the subcommand alone fires at whichever runs first.
if [ "\$1" = ls-tree ]; then
  for arg in "\$@"; do
    if [ "\$arg" = docs/debt ]; then
      printf 'fatal: fixture-fault: simulated object store error\n' >&2
      exit 128
    fi
  done
fi
exec "$real_git" "\$@"
STUB
  chmod +x "$stub_bin/git"
  run_case "record dir witness faults, not reported absent" 1 E-DIR-SCAN "$d" \
    BASE_SHA="$b" RECORD_PROFILES=debt PATH="$stub_bin:$PATH"

  printf -- '-- grandfathering --\n'
  # Non-conforming at the base ref, so its structural findings are warnings and the run is
  # green. A bulleted `- target:` is the legacy shape the migrator exists to fix, and
  # E-TARGET-MISSING is blob-local, which is what makes the record non-conforming.
  d=$(case_dir legacy_shape)
  sed 's/^target: /- target: /' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  git -C "$d" commit -aqm "legacy shape"
  b=$(base_of "$d")
  run_case "legacy record downgrades to a warning" 0 W-LEGACY-SHAPE "$d" BASE_SHA="$b"

  # A banner-only edit to a legacy record: the one edit the convention permits, on a record
  # that can never reach conformance. This is the deadlock grandfathering exists to break —
  # under a "structure is checked on records the change touches" rule it would demand full
  # conformance, which immutability forbids reaching.
  d=$(case_dir grandfathered_edit)
  sed 's/^target: /- target: /' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  git -C "$d" commit -aqm "legacy shape"
  b=$(base_of "$d")
  sed 's/^Open$/> **Resolved by the follow-up change** (2026-01-01)/' \
    "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  run_case "banner-only edit to a legacy record" 0 W-LEGACY-SHAPE "$d" BASE_SHA="$b"

  # The verdict is recomputed every run, so a record migrated into conformance is
  # error-checked from the following run onward — no flag, no registry.
  d=$(case_dir migrated_then_checked)
  sed 's/^target: /- target: /' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  git -C "$d" commit -aqm "legacy shape"
  sed 's/^- target: /target: /' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  git -C "$d" commit -aqm "migrate the marker"
  b=$(base_of "$d")
  sed 's/^Open$/> **Resolved by a** (2026-01-01)\
> **Resolved by b** (2026-01-01)/' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  run_case "migrated record is error-checked next run" 1 E-BANNER-COUNT "$d" BASE_SHA="$b"

  # W-ORPHAN-TARGET resolves a path against the worktree, so it is not blob-local, not part
  # of conformance, and must report as itself on a grandfathered record rather than being
  # relabelled. The invalid status is what grandfathers the record; exit 0 proves it was
  # downgraded, and the asserted code proves the orphan warning was not.
  d=$(case_dir legacy_orphan Pending does/not/exist)
  b=$(base_of "$d")
  run_case "orphan target keeps full severity on a legacy record" 0 W-ORPHAN-TARGET "$d" \
    BASE_SHA="$b"

  # W-LEGACY-SHAPE has no call site: it is a relabelling branch in each of `err` and `warn`,
  # and every downgradable finding the cases above produce is error-level, so only the `err`
  # branch was ever reached. A grandfathered record whose review-by has passed is the `warn`
  # branch's own case. Bespoke, because run_case asserts that a code is present and both
  # branches emit the same one — what distinguishes them is the original code in parentheses.
  d=$(case_dir legacy_stale_reviewby Open docs/debt "2020-01-01")
  sed 's/^target: /- target: /' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  git -C "$d" commit -aqm "legacy shape with a passed review date"
  b=$(base_of "$d")
  printf '  %-4s %-44s ' "" "a warning downgrades on a legacy record"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES=debt BASE_SHA="$b" \
    ./.github/scripts/check-records.sh) >"$d/.out" 2>"$d/.err"; then
    if grep -q '::warning::W-LEGACY-SHAPE: .*(W-REVIEWBY-STALE)$' "$d/.err" &&
      ! grep -q '::warning::W-REVIEWBY-STALE' "$d/.err"; then
      passed=$((passed + 1))
      printf 'ok   exit=0 relabelled, not reported as itself\n'
    else
      failed=$((failed + 1))
      printf 'FAIL W-REVIEWBY-STALE was not relabelled W-LEGACY-SHAPE\n'
    fi
  else
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$(sed -n 's/^::error:://p' "$d/.err" | head -1)"
  fi

  # Determining conformance needs a temp file for the base-ref blob. A degraded path is
  # fatal here rather than silently skipping the base pass, which would grandfather nothing
  # and quietly error-check everything — or, worse, the reverse.
  #
  # Forcing that path needs a stub `mktemp` on PATH rather than an invalid TMPDIR: on macOS,
  # a bare `mktemp` consults _CS_DARWIN_USER_TEMP_DIR before TMPDIR, so an unwritable or
  # nonexistent TMPDIR is silently ignored and the real mktemp still succeeds — only on Linux
  # would that technique have forced the failure this case exists to test. A PATH-shadowed
  # mktemp that always fails forces the same E-TMPFILE path on both.
  d=$(case_dir no_tmpdir)
  b=$(base_of "$d")
  mkdir -p "$d.bin"
  cat >"$d.bin/mktemp" <<'STUB'
#!/bin/sh
echo "mktemp: stub failure (check-records-test.sh forcing E-TMPFILE)" >&2
exit 1
STUB
  chmod +x "$d.bin/mktemp"
  run_case "temp file unavailable" 1 E-TMPFILE "$d" BASE_SHA="$b" PATH="$d.bin:$PATH"

  # A profile that sets its variables but defines no status hook. Without this check the
  # engine would silently reuse the previous profile's hook, since load_profile unsets the
  # optional hooks between profiles but a required one cannot be defaulted away.
  d=$(case_dir incomplete_profile)
  b=$(base_of "$d")
  cat >"$d/.github/scripts/profiles/bare.sh" <<'SH'
RECORD_DIR="docs/debt"
RECORD_LABEL="bare"
RECORD_EXEMPT_FILES=""
REQUIRED_SECTIONS="## Status"
APPEND_ONLY_SECTIONS=""
BANNER_PREFIX='^> \*\*Resolved by'
BANNER_PATTERN='^> \*\*Resolved by .+\*\* \([0-9]{4}-[0-9]{2}-[0-9]{2}\)$'
BANNER_HINT="> **Resolved by <what>** (YYYY-MM-DD)"
BANNER_REPLACES_STATUS=yes
SH
  run_case "profile defines no status hook" 1 E-PROFILE-INCOMPLETE "$d" BASE_SHA="$b" \
    RECORD_PROFILES=bare

  printf -- '-- headings and the preamble --\n'
  # section_body skips the heading line itself, so no append-only rule has ever examined a
  # heading — and for an ADR the H1 *is* the decision statement.
  d=$(case_dir heading_rewritten)
  b=$(base_of "$d")
  sed 's/^# 0001 — test record$/# 0001 — a different claim entirely/' \
    "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  run_case "H1 reworded" 1 E-HEADING-REWRITTEN "$d" BASE_SHA="$b"

  # Records are not section-uniform, so a non-required heading is equally exposed.
  d=$(case_dir heading_nonrequired)
  printf '\n## Aside\n\nSomething extra.\n' >>"$d/docs/debt/0001-valid.md"
  git -C "$d" commit -aqm "add a section"
  b=$(base_of "$d")
  sed 's/^## Aside$/## Asides/' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  run_case "non-required heading renamed" 1 E-HEADING-REWRITTEN "$d" BASE_SHA="$b"

  # The region between the H1 and the first `## ` belongs to no section, so no append-only
  # rule has ever reached it. It is where a pre-template record keeps its metadata bullets.
  d=$(case_dir preamble_rewritten)
  {
    head -1 "$d/docs/debt/0001-valid.md"
    printf '\n- **Status:** Deferred\n'
    tail -n +2 "$d/docs/debt/0001-valid.md"
  } >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  git -C "$d" commit -aqm "add a metadata bullet"
  b=$(base_of "$d")
  grep -v '^- \*\*Status:\*\* Deferred$' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  run_case "preamble bullet deleted" 1 E-PREAMBLE-REWRITTEN "$d" BASE_SHA="$b"

  printf -- '-- renumbering under canonicalised comparison --\n'
  # Byte equality plus a number-in-the-H1 rule makes renumbering impossible in either
  # direction: keep the bytes and the H1 no longer matches the filename, fix the H1 and the
  # escape stops recognising the record. Canonicalising the H1's number to a
  # filename-independent sentinel removes the deadlock.
  d=$(case_dir renumber_h1_fixed)
  b=$(base_of "$d")
  git -C "$d" mv docs/debt/0001-valid.md docs/debt/0002-valid.md
  sed 's/^# 0001 — /# 0002 — /' "$d/docs/debt/0002-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0002-valid.md"
  run_case "renumber with the H1 corrected" 0 - "$d" BASE_SHA="$b"

  # The must-stay-red direction. The sentinel makes two records identical apart from their
  # number canonicalise identically, so without the candidate-absent-at-base condition a
  # deletion is excused by a look-alike sibling that was already there.
  d=$(case_dir lookalike_sibling)
  write_record "$d" "0002-valid.md"
  git -C "$d" add -A
  git -C "$d" commit -qm "a look-alike sibling"
  b=$(base_of "$d")
  git -C "$d" rm -q docs/debt/0001-valid.md
  run_case "deleted record with a look-alike already at base" 1 E-GONE "$d" BASE_SHA="$b"

  # An H1 whose title legitimately begins with a digit and *no* separator is not a numbered
  # prefix, so canonicalise leaves it alone and the two records stay distinguishable.
  d=$(case_dir digit_title)
  sed 's/^# 0001 — test record$/# 2026 was a good year/' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  git -C "$d" commit -aqm "a title starting with a digit"
  b=$(base_of "$d")
  git -C "$d" rm -q docs/debt/0001-valid.md
  mkdir -p "$d/docs/debt" # git removes the now-empty directory
  write_record "$d" "0002-valid.md"
  sed 's/^# 0002 — test record$/# 2027 was a good year/' "$d/docs/debt/0002-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0002-valid.md"
  git -C "$d" add -A
  run_case "digit-led title is not a numbered prefix" 1 E-GONE "$d" BASE_SHA="$b"

  # Indentation and nesting outside a marker line are content: de-indenting a sub-bullet
  # promotes a caveat to a peer decision item. This case is red for a plain reason today —
  # there is no allowance yet — and it is the regression guard for the one PR 3 adds, where a
  # whitespace rule applied file-wide instead of to marker lines would hide exactly this.
  d=$(case_dir reindented_subbullet)
  printf '  - a nested caveat\n' >>"$d/docs/debt/0001-valid.md"
  git -C "$d" commit -aqm "a nested caveat"
  b=$(base_of "$d")
  sed 's/^  - a nested caveat$/- a nested caveat/' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  run_case "re-indented sub-bullet in an append-only section" 1 E-REWRITE "$d" BASE_SHA="$b"

  # The anti-erasure rules describe a change, not a record, so a grandfathered record must not
  # soften them. Nothing else pins this: all three run in check_no_disappearances, which
  # executes before the per-record loop while the mode is still `report`, so err_full and err
  # are indistinguishable there today. This case is what turns that placement into a tested
  # property — fold the structural checks into the record loop and it goes green at exit 0
  # with W-LEGACY-SHAPE, which is exactly the regression to catch.
  d=$(case_dir legacy_rewrite)
  sed 's/^target: /- target: /' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  git -C "$d" commit -aqm "legacy shape"
  b=$(base_of "$d")
  grep -v '^A real concern with a body\.$' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  run_case "gutting a legacy record is still an error" 1 E-REWRITE "$d" BASE_SHA="$b"

  printf -- '-- the marker-only allowance --\n'
  # Migration edits a merged record, which E-REWRITE, E-HEADING-REWRITTEN and
  # E-PREAMBLE-REWRITTEN exist to forbid, so each transform migrate-records.sh performs must
  # be accepted here — and nothing wider. The allowance is one predicate in front of all
  # three rules, so both directions have to be pinned: a sweep that only neutralises rules
  # never touches a predicate inside one, and this is that predicate.
  d=$(case_dir allow_h1_migrated)
  sed 's/^# 0001 — test record$/# 1. test record/' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  git -C "$d" commit -aqm "a legacy H1"
  b=$(base_of "$d")
  sed 's/^# 1\. test record$/# 0001 — test record/' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  run_case "H1 migrated to the numbered form" 0 - "$d" BASE_SHA="$b"

  # The heading spelling and the status value in one diff, which is what a legacy record
  # actually needs. It is also what pins the `## Status` body's exclusion from the
  # comparison: with the body compared, this diff is not marker-only, and the migrator's
  # own output would be rejected by the gate on a transform no rule here examines.
  d=$(case_dir allow_status_heading_and_value)
  sed -e 's/^## Status$/## status:/' -e 's/^Open$/open/' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  git -C "$d" commit -aqm "a legacy Status heading"
  b=$(base_of "$d")
  sed -e 's/^## status:$/## Status/' -e 's/^open$/Open/' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  run_case "Status heading and value migrated together" 0 - "$d" BASE_SHA="$b"

  # The transform that is the only reason a deferral record needs migrating at all: a
  # bulleted target: fails E-TARGET-MISSING, and it sits inside ## Provenance, which is
  # append-only — so fixing it removes a line from a protected section.
  d=$(case_dir allow_target_debulleted)
  sed 's/^target: /- target: /' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  git -C "$d" commit -aqm "a bulleted target"
  b=$(base_of "$d")
  sed 's/^- target: /target: /' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  run_case "bulleted target de-bulleted in Provenance" 0 - "$d" BASE_SHA="$b"

  # The whitespace half of the same transform, which reindented_subbullet is the counterpart
  # to: leading whitespace is discarded on a marker line and nowhere else.
  d=$(case_dir allow_target_dedented)
  sed 's/^target: /  target: /' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  git -C "$d" commit -aqm "an indented target"
  b=$(base_of "$d")
  sed 's/^  target: /target: /' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  run_case "indented target moved to column one" 0 - "$d" BASE_SHA="$b"

  d=$(adr_dir allow_adr_title)
  sed 's/^# 0001 — test decision$/# 1. test decision/' "$d/docs/adr/0001-first.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/adr/0001-first.md"
  git -C "$d" commit -aqm "a legacy ADR title"
  b=$(base_of "$d")
  sed 's/^# 1\. test decision$/# 0001 — test decision/' "$d/docs/adr/0001-first.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/adr/0001-first.md"
  run_case "legacy ADR H1 migrated" 0 - "$d" BASE_SHA="$b" RECORD_PROFILES=adr

  # The other direction. A marker line's *value* is content: canonicalise discards the
  # bullet and the indent in front of `target:`, never the path after it.
  d=$(case_dir deny_target_rewritten)
  b=$(base_of "$d")
  sed 's|^target: docs/debt$|target: docs/elsewhere|' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  run_case "target value changed is not marker-only" 1 E-REWRITE "$d" BASE_SHA="$b"

  # A diff that merely *contains* a marker fix is not marker-only. The comparison runs over
  # the whole canonicalised file, so one deleted line of prose anywhere denies the whole
  # allowance rather than the section it sits in.
  d=$(case_dir deny_marker_plus_prose)
  sed 's/^target: /- target: /' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  git -C "$d" commit -aqm "a bulleted target"
  b=$(base_of "$d")
  sed -e 's/^- target: /target: /' -e '/^Found by a test\.$/d' \
    "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  run_case "marker fix plus a deleted prose line" 1 E-REWRITE "$d" BASE_SHA="$b"

  d=$(case_dir deny_marker_plus_heading)
  sed 's/^target: /- target: /' "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  git -C "$d" commit -aqm "a bulleted target"
  b=$(base_of "$d")
  sed -e 's/^- target: /target: /' -e 's/^## Concern$/## Concerns/' \
    "$d/docs/debt/0001-valid.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  run_case "marker fix plus a reworded heading" 1 E-HEADING-REWRITTEN "$d" BASE_SHA="$b"

  printf -- '-- the ADR profile --\n'
  # The five status words the ADR profile names, all in one fixture: the vocabulary is the
  # rule, and a
  # word two governing artifacts prescribe must not be an error.
  d=$(adr_dir adr_status_forms)
  write_adr "$d" "0002-proposed.md" "Proposed"
  write_adr "$d" "0003-deferred.md" "Deferred"
  write_adr "$d" "0004-rejected.md" "Rejected (2026-01-01)"
  write_adr "$d" "0005-superseded.md" "Superseded (2026-01-01)"
  git -C "$d" add -A
  git -C "$d" commit -qm "every status form"
  b=$(base_of "$d")
  run_case "every ADR status form" 0 - "$d" BASE_SHA="$b" RECORD_PROFILES=adr

  # The base commit must stay conforming — Status is blob-local, so baking the bad word
  # straight into the base ref would make 0001-first.md non-conforming there too, and
  # E-STATUS would downgrade to W-LEGACY-SHAPE instead of firing at full severity.
  d=$(adr_dir adr_status_bad)
  b=$(base_of "$d")
  write_adr "$d" "0001-first.md" "Agreed, probably"
  run_case "invalid ADR status word" 1 E-STATUS "$d" BASE_SHA="$b" RECORD_PROFILES=adr

  # An ADR banner accompanies `Accepted (date)` rather than replacing it, per
  # BANNER_REPLACES_STATUS=no — and this is the one status edit a merged ADR may take.
  d=$(adr_dir adr_banner "Accepted (2026-01-01)" \
    "> **Superseded by [0002](0002-later.md)** (2026-01-02)")
  write_adr "$d" "0002-later.md" "Accepted (2026-01-02)"
  git -C "$d" add -A
  git -C "$d" commit -qm "supersede it"
  b=$(base_of "$d")
  run_case "Accepted plus a well-formed banner" 0 - "$d" BASE_SHA="$b" RECORD_PROFILES=adr

  # The loose-prefix/strict-pattern contract: a malformed banner must reach E-BANNER-FORM
  # rather than falling through to E-STATUS. Same grandfathering hazard as adr_status_bad:
  # the base commit stays banner-free and conforming, and the malformed banner is added only
  # to the tree.
  d=$(adr_dir adr_banner_form)
  b=$(base_of "$d")
  write_adr "$d" "0001-first.md" "Accepted (2026-01-01)" "> **Superseded by 0002**"
  run_case "malformed ADR banner" 1 E-BANNER-FORM "$d" BASE_SHA="$b" RECORD_PROFILES=adr

  # The same contract on the deferral profile, which has never had a case for it: the two
  # patterns are per-profile values, so one profile's routing proves nothing about the other's.
  d=$(case_dir debt_banner_form)
  b=$(base_of "$d")
  sed 's/^Open$/> **Resolved by something** on 2026-01-01/' "$d/docs/debt/0001-valid.md" \
    >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0001-valid.md"
  run_case "malformed deferral banner" 1 E-BANNER-FORM "$d" BASE_SHA="$b"

  # Same hazard again: two banners baked into the base commit would make it non-conforming
  # there too, so the base stays clean and the second banner is added only to the tree.
  d=$(adr_dir adr_banner_count)
  b=$(base_of "$d")
  write_adr "$d" "0001-first.md" "Accepted (2026-01-01)" \
    "> **Superseded by [0002](0002-a.md)** (2026-01-02)
> **Superseded by [0003](0003-b.md)** (2026-01-03)"
  run_case "two supersession banners" 1 E-BANNER-COUNT "$d" BASE_SHA="$b" RECORD_PROFILES=adr

  # And again: the base commit carries the sibling ADR the banner will name, but no banner
  # of its own, so 0001-first.md is still conforming at base and the future date is a
  # genuine tree-only defect rather than a grandfathered one.
  d=$(adr_dir adr_banner_future)
  write_adr "$d" "0002-a.md" "Accepted (2026-01-02)"
  git -C "$d" add -A
  git -C "$d" commit -qm "second decision"
  b=$(base_of "$d")
  write_adr "$d" "0001-first.md" "Accepted (2026-01-01)" \
    "> **Superseded by [0002](0002-a.md)** (2099-01-01)"
  run_case "supersession banner dated in the future" 1 E-BANNER-FUTURE "$d" BASE_SHA="$b" \
    RECORD_PROFILES=adr

  # Dropping the index table moved supersession into the records; nothing has verified since
  # that those cross-links resolve.
  d=$(adr_dir adr_dangling "Accepted (2026-01-01)" \
    "> **Superseded by [0009](0009-nowhere.md)** (2026-01-02)")
  b=$(base_of "$d")
  run_case "supersession banner points nowhere" 1 E-SUPERSEDE-DANGLING "$d" BASE_SHA="$b" \
    RECORD_PROFILES=adr

  d=$(adr_dir adr_title)
  b=$(base_of "$d")
  sed 's/^# 0001 — /# 0007 — /' "$d/docs/adr/0001-first.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/adr/0001-first.md"
  run_case "H1 number disagrees with the filename" 1 E-TITLE-MISMATCH "$d" BASE_SHA="$b" \
    RECORD_PROFILES=adr

  # README.md is exempt because the ADR convention puts it in the record directory. Exempt
  # means "not a record", not "ignored" — and nothing else gets in.
  d=$(adr_dir adr_readme_exempt)
  b=$(base_of "$d")
  run_case "README.md in the record directory is exempt" 0 - "$d" BASE_SHA="$b" \
    RECORD_PROFILES=adr

  d=$(adr_dir adr_stray)
  b=$(base_of "$d")
  printf 'notes\n' >"$d/docs/adr/NOTES.md"
  run_case "another stray file still fails" 1 E-NOT-RECORD "$d" BASE_SHA="$b" \
    RECORD_PROFILES=adr

  # An exempt entry names one path at the top of the record directory. Matching it as a
  # basename at any depth exempted docs/adr/archive/README.md as well, which is a wider
  # allowance than the one named exception the ADR convention describes.
  d=$(adr_dir adr_nested_exempt_name)
  b=$(base_of "$d")
  mkdir -p "$d/docs/adr/archive"
  printf 'notes\n' >"$d/docs/adr/archive/README.md"
  run_case "exempt name in a subdirectory still fails" 1 E-NOT-RECORD "$d" BASE_SHA="$b" \
    RECORD_PROFILES=adr

  # W-INDEX-TABLE makes the directory-listing policy self-policing. It is a heuristic, so it
  # runs from profile_check_directory because its subject is not a record.
  d=$(adr_dir adr_index_table)
  cat >>"$d/docs/adr/README.md" <<'MD'

| ADR | Title |
|---|---|
| 0001 | test decision |
MD
  b=$(base_of "$d")
  run_case "README.md grows an index table" 0 W-INDEX-TABLE "$d" BASE_SHA="$b" \
    RECORD_PROFILES=adr

  printf '  %-4s %-44s ' "" "required ADR index is accepted"
  if (cd "$d" && env -u GITHUB_ACTIONS ADR_INDEX_POLICY=required RECORD_PROFILES=adr \
    BASE_SHA="$b" ./.github/scripts/check-records.sh) >"$d/.required.out" 2>"$d/.required.err"; then
    if grep -q 'W-INDEX-TABLE' "$d/.required.err"; then
      failed=$((failed + 1))
      printf 'FAIL emitted W-INDEX-TABLE\n'
    else
      passed=$((passed + 1))
      printf 'ok   exit=0 no index warning\n'
    fi
  else
    failed=$((failed + 1))
    printf 'FAIL checker failed: %s\n' "$(sed -n 's/^::error:://p' "$d/.required.err" | head -1)"
  fi

  # APPEND_ONLY_SECTIONS="*" protects every level-2 section the base ref had, not a fixed
  # list — ADRs are not section-uniform, and a fixed list leaves the extra sections guttable.
  d=$(adr_dir adr_extra_section)
  printf '\n## Findings\n\nSomething observed.\n' >>"$d/docs/adr/0001-first.md"
  git -C "$d" commit -aqm "a non-uniform section"
  b=$(base_of "$d")
  grep -v '^Something observed.$' "$d/docs/adr/0001-first.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/adr/0001-first.md"
  run_case "non-required ADR section gutted" 1 E-REWRITE "$d" BASE_SHA="$b" RECORD_PROFILES=adr

  # A non-blob-local rule reports at full severity on a grandfathered record. The pre-template
  # shape (no ## Status at all) grandfathers this ADR, and the dangling link must still be an
  # error — the run must not exit 0.
  d="$SCRATCH/adr_legacy_dangling"
  new_adr_repo "$d"
  cat >"$d/docs/adr/0001-legacy.md" <<'MD'
# 1. A pre-template decision

- **Status:** Deferred
- **Date:** 2026-01-01

## Context

Why this came up.

## Decision

What we decided.

## Consequences

What follows from it.
MD
  git -C "$d" add -A
  git -C "$d" commit -qm base
  b=$(base_of "$d")
  run_case "legacy ADR downgrades its own shape" 0 W-LEGACY-SHAPE "$d" BASE_SHA="$b" \
    RECORD_PROFILES=adr
  banner="> **Superseded by [0009](0009-nowhere.md)** (2026-01-02)"
  printf '\n## Status\n\nAccepted (2026-01-01)\n%s\n' "$banner" >>"$d/docs/adr/0001-legacy.md"
  run_case "dangling link on a legacy ADR is an error" 1 E-SUPERSEDE-DANGLING "$d" \
    BASE_SHA="$b" RECORD_PROFILES=adr

  # And W-INDEX-TABLE must not inherit `downgrade` from the record loop, which would leave it
  # relabelled W-LEGACY-SHAPE for any repo whose oldest record is a legacy one. Same fixture
  # shape, no banner: the only finding besides the record's own downgraded shape is the table.
  d="$SCRATCH/adr_legacy_index"
  new_adr_repo "$d"
  cat >"$d/docs/adr/0001-legacy.md" <<'MD'
# 1. A pre-template decision

- **Status:** Deferred

## Context

Why this came up.

## Decision

What we decided.

## Consequences

What follows from it.
MD
  cat >>"$d/docs/adr/README.md" <<'MD'

| ADR | Title |
|---|---|
| 0001 | a pre-template decision |
MD
  git -C "$d" add -A
  git -C "$d" commit -qm base
  b=$(base_of "$d")
  run_case "index table reports itself beside a legacy record" 0 W-INDEX-TABLE "$d" \
    BASE_SHA="$b" RECORD_PROFILES=adr

  printf -- '-- two profiles at once --\n'
  # One profile failing must fail the run while the other still reports.
  d=$(adr_dir adr_plus_debt)
  mkdir -p "$d/docs/debt"
  write_record "$d" "0001-valid.md"
  git -C "$d" add -A
  git -C "$d" commit -qm "both kinds"
  b=$(base_of "$d")
  run_case "both profiles pass" 0 - "$d" BASE_SHA="$b" RECORD_PROFILES="adr debt"
  sed 's/^Accepted (2026-01-01)$/Agreed, probably/' "$d/docs/adr/0001-first.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/adr/0001-first.md"
  run_case "one profile fails, the other passes" 1 E-STATUS "$d" BASE_SHA="$b" \
    RECORD_PROFILES="adr debt"

  # Global findings run once, before the profile loop, and a hook defined by one profile must
  # not survive into the next. run_case asserts presence, not count, so both need a bespoke
  # count.
  #
  # docs/debt/README.md is what makes the leak observable, and it is load-bearing: adr.sh's
  # directory hook reads "$RECORD_DIR/README.md", and RECORD_DIR is docs/debt during the debt
  # pass. Without a table sitting at that path the leaked call returns at its own `[ -f ]`
  # guard and emits nothing, so the count is 1 whether or not the hook leaked and the case
  # cannot fail. It also draws an E-NOT-RECORD from the debt profile, whose
  # RECORD_EXEMPT_FILES is empty — correct, and irrelevant to what is counted here.
  d=$(adr_dir global_once)
  mkdir -p "$d/docs/debt"
  write_record "$d" "0001-valid.md"
  cat >>"$d/docs/adr/README.md" <<'MD'

| ADR | Title |
|---|---|
| 0001 | test decision |
MD
  cp "$d/docs/adr/README.md" "$d/docs/debt/README.md"
  git -C "$d" add -A
  git -C "$d" commit -qm "both kinds"
  b=$(base_of "$d")
  git -C "$d" rm -q .github/workflows/records.yml
  printf '  %-4s %-44s ' "" "global and directory findings report once"
  if (cd "$d" && env -u GITHUB_ACTIONS RECORD_PROFILES="adr debt" BASE_SHA="$b" \
    ./.github/scripts/check-records.sh) >"$d/.o" 2>"$d/.e"; then
    failed=$((failed + 1))
    printf 'FAIL passed with the workflow deleted\n'
  else
    gate_hits=$(grep -c '::error::E-GATE-GONE: ' "$d/.e" || true)
    index_hits=$(grep -c '::warning::W-INDEX-TABLE: docs/adr/README.md' "$d/.e" || true)
    leaked=$(grep -c 'W-INDEX-TABLE: docs/debt' "$d/.e" || true)
    if [ "$gate_hits" = 1 ] && [ "$index_hits" = 1 ] && [ "$leaked" = 0 ]; then
      passed=$((passed + 1))
      printf 'ok   exit=1 one E-GATE-GONE, one W-INDEX-TABLE, no leak\n'
    else
      failed=$((failed + 1))
      printf 'FAIL E-GATE-GONE x%s, W-INDEX-TABLE(adr) x%s, leaked x%s (want 1, 1, 0)\n' \
        "$gate_hits" "$index_hits" "$leaked"
    fi
  fi

  printf -- '-- the migrator --\n'
  # migrate-records.sh edits merged records, so its self-check is the only thing between it
  # and the erasure the gate exists to prevent. Every case here asserts the record on disk as
  # well as the exit status: "aborted" and "aborted after writing" report the same status.
  d=$(migrator_dir migrate_dry_run)
  cp "$d/docs/debt/0001-valid.md" "$d.before"
  run_migrator "dry run reports without writing" 0 - "$d"
  printf '  %-4s %-44s ' "" "dry run leaves the record byte-identical"
  if cmp -s "$d.before" "$d/docs/debt/0001-valid.md"; then
    passed=$((passed + 1))
    printf 'ok   nothing written\n'
  else
    failed=$((failed + 1))
    printf 'FAIL the default run wrote to the record\n'
  fi

  d=$(migrator_dir migrate_write)
  b=$(base_of "$d")
  run_migrator "--write migrates a legacy record" 0 - "$d" --write
  printf '  %-4s %-44s ' "" "every transform in the table applied"
  verdict=""
  rec="$d/docs/debt/0001-valid.md"
  grep -q '^# 0001 — test record$' "$rec" || verdict="$verdict h1"
  grep -q '^## Status$' "$rec" || verdict="$verdict heading"
  grep -q '^Open$' "$rec" || verdict="$verdict status-word"
  grep -q '^target: docs/debt$' "$rec" || verdict="$verdict target"
  grep -q '^A real concern with a body\.$' "$rec" || verdict="$verdict lost-prose"
  if [ -z "$verdict" ]; then
    passed=$((passed + 1))
    printf 'ok   H1, heading, status word and target\n'
  else
    failed=$((failed + 1))
    printf 'FAIL%s\n' "$verdict"
  fi

  # The whole point of the allowance: what the migrator writes, the gate takes. Run against
  # the same base ref the record was committed at, which is what CI would compare against.
  run_case "the gate accepts what the migrator wrote" 0 - "$d" BASE_SHA="$b"

  d=$(migrator_dir migrate_dirty)
  cp "$d/docs/debt/0001-valid.md" "$d.before"
  printf 'uncommitted\n' >"$d/stray.txt"
  run_migrator "dirty worktree refused" 1 E-DIRTY "$d" --write
  printf '  %-4s %-44s ' "" "the refused run wrote nothing"
  if cmp -s "$d.before" "$d/docs/debt/0001-valid.md"; then
    passed=$((passed + 1))
    printf 'ok   record untouched\n'
  else
    failed=$((failed + 1))
    printf 'FAIL wrote despite a dirty worktree\n'
  fi

  # A hook that edits a region the gate protects. The self-check is marker_only_change, the
  # gate's own predicate, so this is the same rejection the gate would issue — reached before
  # anything is written rather than after the commit.
  d=$(migrator_dir migrate_self_check)
  cp "$d/docs/debt/0001-valid.md" "$d.before"
  cp "$SCRIPT_DIR/profiles/debt.sh" "$d/.github/scripts/profiles/rogue.sh"
  cat >>"$d/.github/scripts/profiles/rogue.sh" <<'SH'
profile_migrate_markers() {
  grep -v '^A real concern with a body\.$' "$1"
}
SH
  git -C "$d" add -A
  git -C "$d" commit -qm "a hook that rewrites prose"
  MIGRATE_PROFILES=rogue run_migrator "self-check refuses a prose edit" 1 E-SELF-CHECK "$d" \
    --write
  printf '  %-4s %-44s ' "" "the self-check ran before any write"
  if cmp -s "$d.before" "$d/docs/debt/0001-valid.md"; then
    passed=$((passed + 1))
    printf 'ok   record untouched\n'
  else
    failed=$((failed + 1))
    printf 'FAIL wrote output its own self-check rejected\n'
  fi

  # The no-invention rule, on the transform an adopting repo with legacy ADRs most needs. A
  # date already on the line is parenthesised; a bare status word has no date to take, and
  # the only other source is a separate metadata line, which lifting would be a relocation.
  d="$SCRATCH/migrate_adr_status"
  new_adr_repo "$d"
  cp "$SCRIPT_DIR/migrate-records.sh" "$d/.github/scripts/migrate-records.sh"
  chmod +x "$d/.github/scripts/migrate-records.sh"
  write_adr "$d" "0001-first.md" "accepted 2026-01-01"
  write_adr "$d" "0002-second.md" "ACCEPTED"
  git -C "$d" add -A
  git -C "$d" commit -qm base
  MIGRATE_PROFILES=adr run_migrator "ADR status dated only from its own line" 0 - "$d" --write
  printf '  %-4s %-44s ' "" "a date is parenthesised, never invented"
  verdict=""
  grep -q '^Accepted (2026-01-01)$' "$d/docs/adr/0001-first.md" || verdict="$verdict not-parenthesised"
  grep -q '^ACCEPTED$' "$d/docs/adr/0002-second.md" || verdict="$verdict bare-word-touched"
  grep -q "status 'ACCEPTED' is not a form the gate accepts" "$d.mout" ||
    verdict="$verdict not-reported"
  if [ -z "$verdict" ]; then
    passed=$((passed + 1))
    printf 'ok   dated line fixed, bare word reported\n'
  else
    failed=$((failed + 1))
    printf 'FAIL%s\n' "$verdict"
  fi

  # What migration cannot finish is named, one line per record, rather than stubbed or
  # guessed. Three shapes at once: a section the record does not have, a section with no
  # body, and a banner whose date is not derivable from the text it already carries.
  d=$(migrator_dir migrate_leftovers)
  write_record "$d" "0002-missing.md"
  sed '/^## Why deferred$/d' "$d/docs/debt/0002-missing.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0002-missing.md"
  write_record "$d" "0003-empty.md"
  sed '/^A real concern with a body\.$/d' "$d/docs/debt/0003-empty.md" >"$d/.rec"
  mv "$d/.rec" "$d/docs/debt/0003-empty.md"
  write_record "$d" "0004-banner.md" "> **Resolved by nothing at all**"
  git -C "$d" add -A
  git -C "$d" commit -qm "three shapes migration cannot finish"
  run_migrator "leftovers reported, nothing invented" 0 - "$d"
  printf '  %-4s %-44s ' "" "each unfinishable shape named in the report"
  verdict=""
  grep -q "no '## Why deferred' section" "$d.mout" || verdict="$verdict missing-section"
  grep -q "'## Concern' has no body" "$d.mout" || verdict="$verdict empty-section"
  grep -q 'the banner must read' "$d.mout" || verdict="$verdict banner"
  if [ -z "$verdict" ]; then
    passed=$((passed + 1))
    printf 'ok   missing, empty and malformed all named\n'
  else
    failed=$((failed + 1))
    printf 'FAIL%s\n' "$verdict"
  fi

  # report_leftovers' section-existence grep, the same shape as check_sections above: exit 1
  # is "no match", exit 2 or more is a scan that never completed, and folding the two used to
  # report a section as missing on a scan that faulted rather than one that actually ran. The
  # file it reads is a scratch copy this process creates and removes itself, so there is no
  # path a fixture can chmod ahead of time the way the checker cases above do. A grep stub
  # that faults only on the one pattern this call passes -- the literal '## Status' heading,
  # with -qxF -- and defers to the real grep for every other call in the same run reaches the
  # same branch deterministically, the way the suite already stubs `gh` for the tracker.
  d=$(migrator_dir migrate_section_scan_fault)
  stub_bin="$SCRATCH/grep-fault-bin"
  mkdir -p "$stub_bin"
  real_grep=$(command -v grep)
  cat >"$stub_bin/grep" <<STUB
#!/usr/bin/env bash
for arg in "\$@"; do
  if [ "\$arg" = "## Status" ]; then
    printf 'grep: fixture-fault: simulated I/O error\n' >&2
    exit 2
  fi
done
exec "$real_grep" "\$@"
STUB
  chmod +x "$stub_bin/grep"
  saved_path=$PATH
  PATH="$stub_bin:$PATH"
  run_migrator "migrator section scan faults, not silently skipped" 1 E-SECTION-SCAN "$d"
  PATH=$saved_path

  # The migrator's own profile resolution. A profile that satisfies the checker still has to
  # supply the migration hook, or the migrator would silently reuse the previous profile's.
  d=$(migrator_dir migrate_no_hook)
  sed '/^profile_migrate_markers() {$/,/^}$/d' "$SCRIPT_DIR/profiles/debt.sh" \
    >"$d/.github/scripts/profiles/hookless.sh"
  git -C "$d" add -A
  git -C "$d" commit -qm "a profile with no migration hook"
  MIGRATE_PROFILES=hookless run_migrator "profile without a migration hook" 1 \
    E-PROFILE-INCOMPLETE "$d" --write

  d=$(migrator_dir migrate_missing_dir)
  cp "$SCRIPT_DIR/profiles/debt.sh" "$d/.github/scripts/profiles/ghost.sh"
  printf 'RECORD_DIR="docs/ghost"\n' >>"$d/.github/scripts/profiles/ghost.sh"
  git -C "$d" add -A
  git -C "$d" commit -qm "a profile pointing at no directory"
  MIGRATE_PROFILES=ghost run_migrator "profile whose directory is absent" 1 \
    E-PROFILE-DIR-MISSING "$d" --write

  d=$(migrator_dir migrate_no_profiles)
  MIGRATE_PROFILES='' run_migrator "no profile named" 1 E-PROFILE-NONE "$d" --write

  printf -- '-- the suite cleans up after itself --\n'
  d="$SCRATCH/scratch_allocator"
  mkdir -p "$d"
  allocation=""
  if allocation=$(
    mktemp() {
      [ "$#" -eq 2 ] && [ "$1" = -d ] &&
        [ "$2" = "$d/check-records-test.XXXXXX" ] || return 1
      : >"$d/mktemp-called"
      mkdir "$d/allocated"
      printf '%s\n' "$d/allocated"
    }
    TMPDIR="$d" allocate_owned_scratch
  ); then
    :
  fi
  printf '  %-4s %-44s ' "" "owned scratch uses atomic allocator"
  if [ "$allocation" = "$d/allocated" ] && [ -d "$allocation" ] &&
    [ -f "$d/mktemp-called" ]; then
    passed=$((passed + 1))
    printf 'ok   mktemp -d created the returned path\n'
  else
    failed=$((failed + 1))
    printf 'FAIL allocator did not use mktemp -d\n'
  fi

  # Proven end to end by running a copy of this script with no checker beside it, which aborts
  # at the first case. Its scratch tree must survive: an aborted or failing run's fixtures are
  # the whole reason to keep them. The nested run's own default scratch is redirected under
  # ours via TMPDIR so it is cleaned up with ours rather than left in /tmp — the leak this
  # section exists to prevent. Reading its path back out of the run's own `scratch:` line is
  # deliberate: that line is the only affordance pointing an operator at a retained tree, so a
  # change that dropped it would fail here.
  #
  # Only this script is copied, and that is load-bearing: a copy with a checker beside it would
  # run the whole suite, including this case, forever. What stops it is require_assets, which
  # finds none of its four siblings and exits 2 before the first case — so this also covers the
  # preflight aborting after the scratch line rather than before it.
  d="$SCRATCH/cleanup_retains_on_abort"
  mkdir -p "$d/bin" "$d/tmp"
  cp "$SCRIPT_DIR/check-records-test.sh" "$d/bin/check-records-test.sh"
  chmod +x "$d/bin/check-records-test.sh"
  printf '  %-4s %-44s ' "" "aborted run retains its scratch tree"
  if (TMPDIR="$d/tmp" "$d/bin/check-records-test.sh") >"$d/.o" 2>"$d/.e"; then
    failed=$((failed + 1))
    printf 'FAIL a copy of the suite with no checker beside it passed\n'
  else
    nested=$(sed -n 's/^scratch: //p' "$d/.o" | head -1)
    if [ -z "$nested" ]; then
      failed=$((failed + 1))
      printf 'FAIL the aborted run never printed its scratch path\n'
    elif [ -d "$nested" ]; then
      passed=$((passed + 1))
      printf 'ok   scratch kept after an abort\n'
    else
      failed=$((failed + 1))
      printf 'FAIL scratch removed after an aborted run\n'
    fi
  fi

  # The remaining three arms. A green run's removal cannot be observed from inside that run, so
  # the decision stands in for it — and the two arms that protect a caller-supplied or empty
  # path are what keep `rm -rf` off a directory this script did not create.
  printf '  %-4s %-44s ' "" "removal decided by green run of an owned dir"
  verdict=""
  if ! should_clean_scratch 0 yes /nonexistent; then
    verdict="$verdict green-owned-not-removed"
  fi
  if should_clean_scratch 1 yes /nonexistent; then
    verdict="$verdict failed-run-removed"
  fi
  if should_clean_scratch 0 no /nonexistent; then
    verdict="$verdict caller-supplied-removed"
  fi
  if should_clean_scratch 0 yes ""; then
    verdict="$verdict empty-path-removed"
  fi
  if [ -z "$verdict" ]; then
    passed=$((passed + 1))
    printf 'ok   green+owned removes, nothing else does\n'
  else
    failed=$((failed + 1))
    printf 'FAIL%s\n' "$verdict"
  fi

  # The abort notice, by the same standing-in: the summary below has not printed yet, so this run
  # cannot observe its own notice either. The first arm is the regression — the old
  # `failed -eq 0` guard suppressed the notice on exactly this state, a run that recorded
  # failures and then died. The second covers a preflight abort, which exits 2. The last keeps
  # the notice off a run that failed cases and finished, where the summary is the report.
  printf '  %-4s %-44s ' "" "abort reported whenever the summary is missed"
  verdict=""
  if ! should_report_abort 1 no; then
    verdict="$verdict silent-abort"
  fi
  if ! should_report_abort 2 no; then
    verdict="$verdict silent-preflight-abort"
  fi
  if should_report_abort 0 yes; then
    verdict="$verdict green-run-reported"
  fi
  if should_report_abort 1 yes; then
    verdict="$verdict completed-failing-run-reported"
  fi
  if [ -z "$verdict" ]; then
    passed=$((passed + 1))
    printf 'ok   reports iff no summary reached\n'
  else
    failed=$((failed + 1))
    printf 'FAIL%s\n' "$verdict"
  fi

  summary_reached=yes
  printf '\n%d passed, %d failed\n' "$passed" "$failed"
  [ "$failed" -eq 0 ]
}

main "$@"
