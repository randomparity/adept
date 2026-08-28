#!/usr/bin/env bash
# Validate records under a profile-selected directory.
#
# This engine is record-kind-agnostic: it knows nothing about docs/debt/ or docs/adr/ on
# its own. A profile (see profiles/, selected by RECORD_PROFILES) supplies that knowledge —
# which directory holds the records, their required sections, and their status rules — and
# the engine enforces the properties every record kind shares, the ones prose cannot
# enforce:
#
#   1. every record carries the fields that make it auditable, with content
#      under each of them, and
#   2. no record stops being a record — not by deletion, not by rename, not by moving
#      into a subdirectory, and not by being replaced with a symlink.
#
# Records are immutable in the same sense as an ADR: resolution is a banner added to
# the record, never a deletion. Every disappearance is therefore an error.
#
# A checker that silently passes is worse than no checker, so every degraded path here
# is fatal rather than skipped: a bad base ref, an unreadable tree, the wrong working
# directory, a symlinked record or container, or a base ref that held records when the
# tree now holds none. The one deliberate exception is an unset BASE_SHA outside CI,
# which downgrades to record validation only and says so — and which is itself fatal
# inside CI.
#
# What it cannot do: this gate lives inside the tree it gates. It detects its own
# *deletion* (see gate_paths and GATE_PREDECESSORS), but a PR may still edit this file, and
# a PR that removes the workflow removes the job rather than failing it. Only repository
# settings that require the status check plus human review close that boundary.
#
# Dates are compared as integers with the dashes stripped, so no `date -d` and no locale
# collation is involved. There are no arrays and no associative arrays either: bash 3.2 is
# the macOS system shell, where `"${arr[@]}"` on an empty array is fatal under `set -u`,
# so every list travels as newline-delimited text.
#
# Tested by check-records-test.sh beside it — every rule below has a case there, and the
# suite's acceptance criterion is that neutralising any single rule turns it red.
#
# Layout-independent: the paths it protects are derived, not hardcoded, so it behaves the
# same whether it sits in .github/scripts/ (a repo that adopted it) or in the publishing
# repo's skill assets.

set -euo pipefail

# Captured before the cd to the repository root, so a relative invocation still resolves.
SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
SELF_FILE="$SELF_DIR/$(basename "${BASH_SOURCE[0]}")"

failed=0

# Emit mode routes every finding. `report` prints and fails the run. `collect` prints nothing
# and records a verdict instead — the base-ref conformance pass keeps the verdict and discards
# the findings. `downgrade` relabels a finding as W-LEGACY-SHAPE, keeping the original code in
# parentheses, for a record that was already non-conforming at the base ref.
#
# A mode global rather than a subshell: running the pass in a subshell is exactly the bug this
# file carries comments about, because the assignment to `failed` would land in a discarded
# subshell while the message still printed.
EMIT_MODE=report
collect_verdict=0

err() {
  case "$EMIT_MODE" in
  collect) collect_verdict=1 ;;
  downgrade) printf '::warning::W-LEGACY-SHAPE: %s (%s)\n' "${1#*: }" "${1%%:*}" >&2 ;;
  *)
    printf '::error::%s\n' "$1" >&2
    failed=1
    ;;
  esac
}

# Only err-level findings decide the base-ref verdict: a warning never makes a record
# non-conforming, or a deferral record whose review-by date passed would become permanently
# grandfathered as a side effect.
warn() {
  case "$EMIT_MODE" in
  collect) : ;;
  downgrade) printf '::warning::W-LEGACY-SHAPE: %s (%s)\n' "${1#*: }" "${1%%:*}" >&2 ;;
  *) printf '::warning::%s\n' "$1" >&2 ;;
  esac
}

# Not downgradable. `downgrade` applies only to the blob-local structural rules conformance is
# defined over: the anti-erasure rules describe a change rather than a record, and
# E-SUPERSEDE-DANGLING, W-INDEX-TABLE and W-ORPHAN-TARGET are not blob-local. Without this,
# adding a supersession banner to this repo's one grandfathered ADR would downgrade its dangling
# cross-link to a warning and exit 0 — on precisely the scenario grandfathering exists for.
#
# Not downgradable is not the same as always printed: `collect` still suppresses these, or the
# base pass would emit findings it is specified to discard.
err_full() {
  if [ "$EMIT_MODE" != collect ]; then
    printf '::error::%s\n' "$1" >&2
    failed=1
  fi
}

# warn_full exists because two of the three non-blob-local rules are warning-level and `warn` is
# otherwise in the downgrade path: without it, a grandfathered record's orphaned target is
# relabelled W-LEGACY-SHAPE and "always at full severity" is false.
warn_full() {
  if [ "$EMIT_MODE" != collect ]; then
    printf '::warning::%s\n' "$1" >&2
  fi
}

info() {
  printf '%s\n' "$1"
}

# There is no default profile list. A checker that reports success over zero records is
# worse than no checker, which is the same reason E-COUNT-FLOOR and E-BASE-EMPTY-CI exist.
PROFILE_DIR="$SELF_DIR/profiles"

load_profile() {
  local name=$1
  local file="$PROFILE_DIR/$name.sh"
  if [ ! -f "$file" ]; then
    err "E-PROFILE-UNKNOWN: no profile named '$name' at $file"
    return 1
  fi

  # Optional hooks are unset before each source and defaulted after it, so a hook defined by
  # one profile cannot leak into the next name in RECORD_PROFILES. With RECORD_PROFILES="adr
  # debt", adr's profile_check_directory would otherwise run a second time during debt's pass
  # and report W-INDEX-TABLE against docs/adr/README.md under the deferral label.
  unset -f profile_check_status profile_check_extra profile_check_directory

  # shellcheck source=/dev/null
  . "$file"

  # profile_check_status cannot be defaulted: a no-op default would mean a profile that forgot
  # it silently validates no status at all, which is the silent pass this checker exists to
  # refuse.
  if [ "$(type -t profile_check_status)" != function ]; then
    err "E-PROFILE-INCOMPLETE: profile '$name' defines no profile_check_status hook"
    return 1
  fi
  # profile_check_extra is called as (file, label, pass, resolved) — the last being
  # check_status's verdict on the same file in the same pass. A profile that wants only the
  # first three may declare only those; positional arguments make the extra one free to ignore.
  if [ "$(type -t profile_check_extra)" != function ]; then
    profile_check_extra() { :; }
  fi
  if [ "$(type -t profile_check_directory)" != function ]; then
    profile_check_directory() { :; }
  fi

  RECORD_RE="^${RECORD_DIR}/[0-9]{4}-[^/]+\.md$"
}

# Dates as integers: 2026-07-25 -> 20260725. Both call sites regex-validate their input
# first, and the single-banner rule guarantees one value, so there is no invalid-input
# branch here — a guard that cannot fire would be a false guarantee, not a safety net.
date_to_int() {
  printf '%s' "${1//-/}"
}

# Body text under a heading, up to the next heading. Used to prove a section has
# content, and to scope field lookups to the section that is supposed to carry them.
section_body() {
  local file=$1 heading=$2
  awk -v want="$heading" '
    $0 == want { inside = 1; next }
    /^## / { inside = 0 }
    inside { print }
  ' "$file"
}

# section_body with its awk's own exit status kept: 0 the body is in read_section_out, 2 the
# read could not run. There is no 1 — an absent or empty section yields empty output at status
# 0, which is an ordinary verdict E-SECTION-EMPTY already owns, unlike path_exists_at where
# absence is a third distinct answer.
#
# The body comes back in a global rather than on stdout because a caller that ran this in `$( )`
# could not see the status: PIPESTATUS does not survive a command substitution either, so
# `var=$(section_body … | grep …)` had no way to tell an awk that could not open the file from a
# grep that honestly matched nothing. That is the defect ADR 0032 closes, and returning the body
# by value is what makes the status reachable.
#
# awk's real status is left in read_section_status for the caller's diagnostic, the way
# path_exists_at leaves its own: this reader's 2 is a sentinel, and reporting it would name a
# status awk never returned.
read_section_out=""
read_section_status=0
read_section() {
  local file=$1 heading=$2 status=0
  read_section_out=""
  read_section_status=0
  read_section_out=$(section_body "$file" "$heading") || status=$?
  if [ "$status" -ne 0 ]; then
    read_section_status=$status
    return 2
  fi
  return 0
}

# The single definition of what counts as a marker. Line-local, and it discards nothing: every
# word of prose, all indentation and nesting outside marker lines, every heading's text and the
# preamble survive into the output, so a comparison over the result is still order-sensitive and
# still sees content changes.
#
# Specified as patterns rather than as a property because "compare everything else exactly" is
# not buildable cold — two implementers would write two different permitted-change sets.
#
# awk rather than sed: case-folding a heading needs tolower(), and BSD sed has no \L. The
# separator alternation is spelled out rather than bracketed because ` — ` is the H1 separator
# every conforming record here uses, and a multibyte em dash inside a character class degrades
# to its three individual UTF-8 bytes under a C-locale runner.
#
# The H1's number becomes a fixed sentinel, not the record's own number. Substituting the number
# back in would reinstate the renumbering deadlock, because the two sides of a renumbering
# comparison have different filenames by definition.
canonicalise() {
  LC_ALL=C awk '
    /^[[:space:]]*(- )?(target|review-by):/ {
      sub(/^[[:space:]]*(- )?/, "")
      print
      next
    }
    /^#/ {
      match($0, /^#+/)
      hashes = substr($0, 1, RLENGTH)
      rest = tolower(substr($0, RLENGTH + 1))
      sub(/^[[:space:]]*/, "", rest)
      sub(/:[[:space:]]*$/, "", rest)
      if (hashes == "#") {
        sub(/^(adr )?[0-9]+[[:space:]]*(\.|:|-|—)[[:space:]]*/, "<n> ", rest)
      }
      print hashes " " rest
      next
    }
    { print }
  ' "$1"
}

# The lines between the H1 and the first `## ` heading. They belong to no section, so
# section_body never sees them and no append-only rule has ever reached them.
preamble() {
  awk '/^## / { exit } NR > 1 { print }' "$1"
}

# One file reduced to exactly what the three anti-rewrite rules below examine: the whole
# canonicalised file minus the `## Status` body. Order-sensitive, and everything outside
# canonicalise's marker table — every word of prose, all indentation and nesting outside
# marker lines, every heading's text and the preamble — survives into it byte-for-byte.
#
# The `## Status` body is dropped because no rule reads it: check_sections_append_only
# excludes it by name, check_headings_intact compares heading lines, and
# check_preamble_intact stops at the first `## `. Dropping a region nothing examines cannot
# weaken any of them, and it is what makes the migrator's self-check answerable — the
# migrator rewrites a status value, which the gate does not care about, so a comparison that
# included it would refuse the one transform the gate has no opinion on.
#
# The heading line itself stays: `## Status` is a heading, and a heading is protected.
# canonicalise has already lowercased it, so `## Status:` and `## status` both arrive here
# as `## status` and the same test recognises either spelling.
#
# `canonicalise` is an awk reading the file, and it used to be the first stage of a pipeline
# whose status went nowhere. When that read faulted, this emitted nothing, marker_only_change
# compared two empty shapes as equal, and check_not_rewritten returned before any anti-erasure
# rule ran — a merged record with a protected section deleted reported E-REWRITE on a working
# toolchain and `Records OK.` on a faulting one. The read is lifted out and its status captured;
# the awk that remains filters a shell variable, which ADR 0005 decision 1 would exempt -- see
# the note at the filter itself for why it is captured anyway.
#
# The shape comes back in a global for read_section's reason: a caller running this in `$( )`
# could not see the status. Comparing captured strings is safe here in a way it is not at the
# `diff` sites — `$( )` strips trailing newlines from both sides identically, so equality is
# unchanged from the pipeline this replaces.
protected_shape_out=""
protected_shape_status=0
protected_shape() {
  local file=$1 canon status=0
  protected_shape_out=""
  protected_shape_status=0
  canon=$(canonicalise "$file") || status=$?
  if [ "$status" -ne 0 ]; then
    protected_shape_status=$status
    return 2
  fi
  # Captured despite reading a variable: an empty result here is a false *pass*, since two empty
  # shapes compare equal. Discarding it would move the fail-open one stage right, not remove it.
  status=0
  protected_shape_out=$(printf '%s\n' "$canon" | awk '
    /^## / { in_status = ($0 == "## status"); print; next }
    !in_status { print }
  ') || status=$?
  if [ "$status" -ne 0 ]; then
    protected_shape_status=$status
    return 2
  fi
  return 0
}

# The marker-only allowance. Migration edits merged records, which E-REWRITE exists to
# forbid, so rather than a bypass flag the three rules fire only when a change is not
# marker-only — and "marker-only" is `canonicalise`, the same definition migrate-records.sh
# produces its output against and checks itself with before writing.
#
# The permission is a property of the diff, which the author cannot fake: there is no
# one-time escape hatch to forget to remove, and no way to smuggle a word of prose, a
# re-indented sub-bullet or a reworded heading past it.
#
# Three-valued per ADR 0005 decision 3, because protected_shape can now fault: 0 marker-only,
# 1 not marker-only, 2 the comparison could not be made. Never call it under `if !` or in an
# `&&`/`||` chain that branches on it — both collapse 1 and 2 and reinstate the silent pass.
marker_only_status=0
marker_only_change() {
  local a=$1 b=$2 shape_a status=0
  marker_only_status=0
  protected_shape "$a" || status=$?
  if [ "$status" -ne 0 ]; then
    marker_only_status=$protected_shape_status
    return 2
  fi
  shape_a=$protected_shape_out

  status=0
  protected_shape "$b" || status=$?
  if [ "$status" -ne 0 ]; then
    marker_only_status=$protected_shape_status
    return 2
  fi

  [ "$shape_a" = "$protected_shape_out" ]
}

check_sections() {
  local file=$1 label=$2 section body grep_status body_status
  while IFS= read -r section; do
    [ -n "$section" ] || continue
    # grep exits 1 for "no match" and 2 or more for a fault it hit while
    # scanning -- an unreadable file, a bad encoding. Negating a bare `if`
    # reads a fault the same as "missing", a false E-SECTION-MISSING on a scan
    # that never actually completed. Branch on the captured status instead.
    grep_status=0
    grep -qxF "$section" "$file" || grep_status=$?
    case $grep_status in
    0) ;;
    1)
      err "E-SECTION-MISSING: $label: missing required section '$section'"
      continue
      ;;
    *)
      err "E-SECTION-SCAN: $label: could not scan $file for section '$section' (grep exit $grep_status)"
      continue
      ;;
    esac
    # `section_body … | tr -d` folded an awk that could not open the file into an empty body,
    # reporting E-SECTION-EMPTY against a section it never read. The read is lifted out and its
    # status captured; the `tr` that remains reads a shell variable, which ADR 0005 decision 1
    # places outside the scan rule.
    # err_full, not err: a scan fault describes the scan, not the record, so it must not be
    # downgraded to W-LEGACY-SHAPE for a record that was already non-conforming at the base ref
    # (ADR 0005). This read faults in both passes when it faults at all -- unlike the grep
    # above, which reads the working-tree file while the base pass reads a readable temp copy --
    # so `err` would leave the gate at exit 0 over a section it never read.
    body_status=0
    read_section "$file" "$section" || body_status=$?
    if [ "$body_status" -ne 0 ]; then
      err_full "E-SECTION-BODY-SCAN: $label: could not read the body of section '$section' in $file (awk exit $read_section_status)"
      continue
    fi
    # In-memory, and the discard is written out per ADR 0032 decision 2. Unlike protected_shape
    # this one fails toward a false error rather than a false pass, so it is not captured.
    body=$(printf '%s' "$read_section_out" | tr -d '[:space:]') || :
    if [ -z "$body" ]; then
      err "E-SECTION-EMPTY: $label: section '$section' is empty — a heading with no content is not a record"
    fi
  done <<<"$REQUIRED_SECTIONS"
}

# Whether the record check_status last judged carries a well-formed banner. The engine hands it
# to profile_check_extra rather than letting a profile re-derive it: a second banner parser could
# disagree with this one, and the two would disagree silently. Reset at the top of every
# check_status call, so the base pass's verdict cannot leak into the tree pass's.
record_resolved=no

# A record is resolved when Status carries exactly one banner naming what resolved it and
# when, open when the profile's own status rule accepts it. Anything else is unreadable
# state: a reader cannot tell whether the concern still stands, so it fails rather than warns.
#
# Two patterns: the loose BANNER_PREFIX finds candidates so they can be counted, the strict
# BANNER_PATTERN judges them. With only the strict one a malformed banner matches nothing,
# counts zero, and misroutes to E-STATUS.
check_status() {
  local file=$1 label=$2 pass=$3
  local status_block banner banner_count banner_date today banner_int today_int
  record_resolved=no
  status_block=$(section_body "$file" "## Status")

  banner=$(printf '%s\n' "$status_block" | grep "$BANNER_PREFIX" || true)
  if [ -n "$banner" ]; then
    banner_count=$(printf '%s\n' "$banner" | grep -c .)
    if [ "$banner_count" -ne 1 ]; then
      err "E-BANNER-COUNT: $label: $banner_count resolution banners — a record is resolved once, by one artifact"
      return 0
    fi
    if ! printf '%s' "$banner" | grep -qE "$BANNER_PATTERN"; then
      err "E-BANNER-FORM: $label: resolution banner must read '$BANNER_HINT'"
      return 0
    fi
    # Set on form, not on date: E-BANNER-FUTURE below judges whether the date is believable,
    # not whether the record claims resolution. A record that claims it with an impossible date
    # is already failing, so the state a profile reads stays the simple one — banner present and
    # well-formed.
    record_resolved=yes
    banner_date=$(printf '%s' "$banner" | sed -E 's/.*\(([0-9]{4}-[0-9]{2}-[0-9]{2})\)$/\1/')
    today=$(date -u +%F)
    banner_int=$(date_to_int "$banner_date")
    today_int=$(date_to_int "$today")
    if [ "$banner_int" -gt "$today_int" ]; then
      err "E-BANNER-FUTURE: $label: resolution banner is dated in the future ($banner_date)"
    fi
    [ "$BANNER_REPLACES_STATUS" = yes ] && return 0
  fi

  profile_check_status "$file" "$label" "$pass"
}

# No associative array: bash 3.2 (macOS system bash) has none, and the header promises
# parity with it. sort | uniq -d is portable and says the same thing.
numbers_of() {
  local list=$1 file base
  [ -n "$list" ] || return 0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    base=${file##*/}
    printf '%s\n' "${base%%-*}"
  done <<<"$list"
}

check_unique_numbers() {
  local list=$1 base_list=${2:-} dups num pre_existing
  [ -n "$list" ] || return 0
  dups=$(numbers_of "$list" | sort | uniq -d)
  [ -n "$dups" ] || return 0
  pre_existing=$(numbers_of "$base_list" | sort | uniq -d)

  while IFS= read -r num; do
    [ -n "$num" ] || continue
    if printf '%s\n' "$pre_existing" | grep -qxF "$num"; then
      # Already duplicated before this change. Failing here would red every later PR for
      # a collision it did not introduce, and the remedy — renumbering — would then have
      # to fight the erasure rule. Warn, and let the PR that fixes it fix it.
      warn "W-DUP-PREEXISTING: record number $num was already duplicated in the base ref — renumber it in a dedicated change"
    else
      err "E-DUP-NUMBER: record number $num is used by more than one record — renumber before merging"
    fi
  done <<<"$dups"
}

# A path that was a record in the base ref must still be a real regular file at the same
# path. `-f` follows symlinks, so the caller tests `-L` first and reports that separately:
# a symlinked record is a distinct failure from a missing one, and keeping the two
# distinguishable is what lets a test attribute each to its own rule.
present_as_real_file() {
  local path=$1
  [ -f "$path" ]
}

# Tracked in the index: 0 tracked, 1 not tracked, 2 the query could not run. Checked alongside
# the filesystem because the two can disagree, and each gap is a way to lose a record: one
# removed from git but left on disk as an untracked file passes a filesystem test while being
# gone from the repository, and one deleted from the working tree passes a git test while being
# gone from the checkout. The index rather than HEAD, so a staged deletion is caught before it
# is committed.
#
# `git ls-files --error-unmatch` exits 1 for an untracked or absent path and 128 for a real
# fault, so unlike `git cat-file` it separates the two on its own and needs no second witness
# (ADR 0005 decision 2). Discarding that status made every caller read a damaged index as an
# untracked path, which is the passing half of each caller's question.
#
# git's status is left in tracked_in_index_status for the callers' diagnostics, for the reason
# path_exists_at leaves its own there: this predicate's 2 is a sentinel, and reporting it would
# name a status git never returned.
tracked_in_index_status=0
tracked_in_index() {
  local path=$1 status=0
  tracked_in_index_status=0
  git ls-files --error-unmatch -- "$path" >/dev/null 2>&1 || status=$?
  case $status in
  0) return 0 ;;
  1) return 1 ;;
  esac
  tracked_in_index_status=$status
  return 2
}

# Three-valued like tracked_in_index, which it delegates its second half to. The filesystem test
# stays two-valued: `[ -f ]` reports no reason, so only the index query contributes a fault.
still_a_record() {
  local path=$1 status=0
  present_as_real_file "$path" || return 1
  tracked_in_index "$path" || status=$?
  return "$status"
}

# A record whose path is gone may have been renumbered rather than erased. Accept it when its
# base-ref content is present at some other record path — the record exists, is tracked, and is
# findable, so nothing was lost. Renumbering is the remedy the duplicate-number rule prescribes,
# and it must not collide with the erasure rule.
#
# Two conditions, both load-bearing. The comparison is canonicalised, so an author may fix the
# H1's number to match the new filename; byte comparison plus a title-number rule forbids that
# in both directions. And the candidate must be **absent from the base ref**: the sentinel makes
# two records identical apart from their number canonicalise identically, so without it a
# deletion is excused by a look-alike sibling that was already a record — nothing renumbered, a
# record gone, exit 0. A genuine renumber lands at a path that did not exist.
#
# Assigns `renumbered_to` and reserves that destination in `used_renumber_targets`. Both come
# from check_no_disappearances through bash's dynamic scoping, so a candidate can excuse only
# one vanished base path. A temp-file failure returns 1 and lets E-GONE speak instead: the record
# is gone from its path either way, and that much the gate did establish — unlike an unreadable
# base copy, a faulted candidate witness, or a candidate the index could not be read for, all
# three of which return 2 and replace E-GONE with the fault.
#
# Candidates come from `records`, which collect_records builds only after reporting
# E-RECORD-SYMLINK and skipping every symlink, so no candidate can be a link. A `[ ! -L ]` test
# here would be a guard that cannot fire — a false guarantee, by the same argument date_to_int
# makes about its own missing invalid-input branch.
# What could not be scanned, for the caller's diagnostic. The three origins reach the caller
# through one status, so without this the message could name only the vanished record — which is
# the one file that was read successfully — and the status alone is unattributable, since the
# three come from three different git commands. Phrased as the thing that could not be read
# rather than as a bare path, the way gate_witness_path already is.
renumber_fault_path=""
renumbered_elsewhere() {
  local base=$1 path=$2 blob_canon candidate tmp cand_status blob_status=0 fault_status=0 fault_path=""
  renumber_fault_path=""
  tmp=$(mktemp) || return 1
  read_base_blob "$base" "$path" "$tmp" || blob_status=$?
  case $blob_status in
  0) ;;
  1)
    rm -f "$tmp"
    return 1
    ;;
  # Whether the record moved is exactly what an unreadable base copy leaves undetermined, so
  # returning 1 reported E-GONE off a search that never ran. The status travels in
  # path_exists_status because that is the variable the caller's diagnostic reads; this fault,
  # a candidate witness's, and a candidate index query's all reach the caller through it —
  # which is why renumber_fault_path names what each one was reading, the way gate_witness_path
  # does for the gate-existence witness.
  *)
    rm -f "$tmp"
    path_exists_status=$base_blob_status
    renumber_fault_path="the base-ref copy of $path"
    return 2
    ;;
  esac
  blob_canon=$(canonicalise "$tmp")
  rm -f "$tmp"
  [ -n "$records" ] || return 1

  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    [ -f "$candidate" ] || continue
    # An untracked candidate is not a destination. `tracked_in_index ... || continue` used to
    # drop a faulted one the same way, so a damaged index removed the real destination from the
    # search and the record below then reported E-GONE.
    cand_status=0
    tracked_in_index "$candidate" || cand_status=$?
    case $cand_status in
    0) ;;
    1) continue ;;
    *)
      fault_status=$tracked_in_index_status
      fault_path="the index entry for $candidate"
      continue
      ;;
    esac
    # A candidate that already existed at the base ref is not a renumber destination. The
    # witness can also fail to run, which used to read the same as "did not exist" and so
    # let a faulted scan promote a candidate silently.
    cand_status=0
    path_exists_at "$base" "$candidate" || cand_status=$?
    case $cand_status in
    0) continue ;;
    1) ;;
    *)
      fault_status=$path_exists_status
      fault_path="$candidate at the base ref"
      continue
      ;;
    esac
    if printf '%s\n' "$used_renumber_targets" | grep -qxF "$candidate"; then
      continue
    fi
    if [ "$blob_canon" = "$(canonicalise "$candidate")" ]; then
      renumbered_to=$candidate
      if [ -n "$used_renumber_targets" ]; then
        used_renumber_targets="$used_renumber_targets
$candidate"
      else
        used_renumber_targets=$candidate
      fi
      if [ "$fault_status" -ne 0 ]; then
        path_exists_status=$fault_status
        renumber_fault_path=$fault_path
        return 3
      fi
      return 0
    fi
  done <<<"$records"
  # A positive match returns above, so a fault only decides the answer once every candidate
  # has been tried without one: a witness that genuinely found the copy is not made
  # unreliable by an unrelated candidate's scan failing.
  if [ "$fault_status" -ne 0 ]; then
    path_exists_status=$fault_status
    renumber_fault_path=$fault_path
    return 2
  fi
  return 1
}

# The record listing at a ref, in records_in_ref_out, with git's real status in
# records_in_ref_status: 0 the listing is in the global, 2 the read could not run.
#
# The listing comes back in a global rather than on stdout for read_section's reason, and this
# function is where that reason was learned twice. Returning the payload on stdout forces every
# caller into `$( )`, which runs the function in a subshell — so the assignment to
# records_in_ref_status landed in a discarded child and the caller read the file-scope 0,
# printing "git exit 0" inside a message saying the read failed. `path_exists_at`'s pattern
# works only because it writes nothing to stdout and so is never called in `$( )`.
records_in_ref_out=""
records_in_ref_status=0
records_in_ref() {
  local ref=$1 raw status=0
  records_in_ref_out=""
  records_in_ref_status=0
  # The checker's coded ::error:: lines are its interface; a bare `fatal:` from git is not,
  # so a bad ref's stderr is suppressed here rather than at each call site.
  raw=$(git ls-tree -r --name-only "$ref" -- "$RECORD_DIR" 2>/dev/null) || status=$?
  if [ "$status" -ne 0 ]; then
    records_in_ref_status=$status
    return 2
  fi
  # `printf` over a shell variable, which ADR 0005 decision 1 places outside the scan rule and
  # ADR 0032 decision 4 confirms does not convert: grep's exit 1 here means the ref simply held
  # no records. The discard is written out per decision 2.
  records_in_ref_out=$(printf '%s' "$raw" | grep -E "$RECORD_RE") || :
  return 0
}

# Heading lines are the one region section_body skips outright — it matches a heading only to
# recognize where a section starts, never to emit the heading itself — so no append-only rule
# has ever examined one, and for an ADR the H1 *is* the decision statement. Every heading line
# present in the base-ref blob must still be present, verbatim, somewhere in the tree version.
check_headings_intact() {
  local tmp=$1 path=$2 heading grep_status list_status=0 headings
  # The listing runs before the loop rather than inside a process substitution on `done`: with
  # `|| true` there, a grep that faulted produced an empty list, the loop ran zero times, and
  # the whole heading-intactness rule passed over content it never scanned.
  headings=$(grep -E '^#+ ' "$tmp") || list_status=$?
  case $list_status in
  # 1 is "the base ref's version had no headings at all", which is a legitimate answer.
  0 | 1) ;;
  *)
    err_full "E-HEADING-LIST-SCAN: $path: could not list the base ref's headings (grep exit $list_status)"
    return 0
    ;;
  esac
  # Fed by a herestring, so err_full runs in the current shell rather than a piped subshell,
  # where the assignment to `failed` would be discarded.
  while IFS= read -r heading; do
    [ -n "$heading" ] || continue
    # grep exits 1 for "no match" and 2 or more for a fault it hit while
    # scanning -- an unreadable file, a bad encoding. Negating a bare `if`
    # reads a fault the same as "gone", a false E-HEADING-REWRITTEN on a scan
    # that never actually completed. Branch on the captured status instead.
    grep_status=0
    grep -qxF "$heading" "$path" || grep_status=$?
    case $grep_status in
    0) ;;
    1) err_full "E-HEADING-REWRITTEN: $path: heading '$heading' is gone from the base ref's version — a heading is the record's claim, not prose" ;;
    *) err_full "E-HEADING-SCAN: $path: could not scan for heading '$heading' (grep exit $grep_status)" ;;
    esac
  done <<<"$headings"
}

# The lines between the H1 and the first `## ` belong to no section at all, so section_body
# never reaches them either — it is where a pre-template record keeps its metadata bullets.
#
# Both sides go to temp files rather than into `diff <(preamble …)`. A reader inside a process
# substitution has no way to report — ADR 0005 — and an awk that could not open the file used to
# yield an empty side, which diff then read as every line removed or none, depending on which
# side faulted. Temp files rather than captured strings because `$( )` strips trailing newlines
# and diff counts them; ADR 0032 records why the printf repairs do not work.
check_preamble_intact() {
  local tmp=$1 path=$2 removed base_pre tree_pre read_status=0 diff_out diff_status=0
  base_pre=$(mktemp) || {
    err_full "E-TMPFILE: $path: cannot create a temp file to compare the preamble"
    return 0
  }
  tree_pre=$(mktemp) || {
    rm -f "$base_pre"
    err_full "E-TMPFILE: $path: cannot create a temp file to compare the preamble"
    return 0
  }

  preamble "$tmp" >"$base_pre" || read_status=$?
  if [ "$read_status" -eq 0 ]; then
    preamble "$path" >"$tree_pre" || read_status=$?
  fi
  if [ "$read_status" -ne 0 ]; then
    rm -f "$base_pre" "$tree_pre"
    err_full "E-PREAMBLE-DIFF-SCAN: $path: could not read the preamble of it or of the base ref's copy, so the rule did not run (awk exit $read_status)"
    return 0
  fi

  # diff exits 0 for identical, 1 for differing, 2 or more for trouble. Only the third is a
  # fault, which is why this is the one captured status compared against 2 rather than switched
  # three ways.
  diff_out=$(diff "$base_pre" "$tree_pre") || diff_status=$?
  rm -f "$base_pre" "$tree_pre"
  if [ "$diff_status" -ge 2 ]; then
    err_full "E-PREAMBLE-DIFF-SCAN: $path: could not compare the preamble against the base ref's copy (diff exit $diff_status)"
    return 0
  fi

  # In-memory, so ADR 0005 decision 1 exempts it and ADR 0032 decision 2 requires the discard be
  # written here rather than left to the caller's ambient `set -e` suppression. grep -c prints 0
  # and exits 1 when nothing matched, which is the ordinary "nothing was removed" answer.
  removed=$(printf '%s\n' "$diff_out" | grep -c '^<') || :
  if [ "$removed" -gt 0 ]; then
    err_full "E-PREAMBLE-REWRITTEN: $path drops $removed line(s) between the title and the first section that the base ref had"
  fi
}

# The erasure that needs no git surgery: keep the path, keep the headings, and rewrite the
# body. Every vector above assumes the file moves, which is the conspicuous way; one
# `cat >` over the path defeats all of them.
#
# The substantive sections are append-only once merged: what the concern was, why it was
# deferred, the boundary, what resolves it, where it came from. `## Status` is deliberately
# excluded, because it is the one section a merged record is meant to change — resolving a
# record replaces `Open` with a banner, and an append-only rule over the whole file would
# forbid exactly the edit the format permits.
check_sections_append_only() {
  local tmp=$1 path=$2 section removed list_status=0 all_sections
  local base_sec tree_sec read_status diff_out diff_status
  # "*" means every level-2 heading the base ref had except ## Status. Level 2 only, matching
  # section_body's `^## ` terminator: a deeper heading is body content inside its enclosing
  # section, and enumerating one as a section of its own would produce overlapping bodies and
  # silently redefine what append-only means.
  local sections=$APPEND_ONLY_SECTIONS
  if [ "$sections" = "*" ]; then
    # Split from the filter below: only this grep reads a file and can fault on one. The
    # `grep -vxF` that follows reads what this produced, so ADR 0005 decision 1 exempts it and
    # ADR 0032 decision 4 confirms it does not convert -- its exit 1 just means every section
    # was `## Status`.
    all_sections=$(grep -E '^## ' "$tmp") || list_status=$?
    case $list_status in
    0 | 1) ;;
    *)
      err_full "E-SECTION-LIST-SCAN: $path: could not list the base ref's sections (grep exit $list_status)"
      return 0
      ;;
    esac
    sections=$(printf '%s\n' "$all_sections" | grep -vxF '## Status') || :
  fi

  while IFS= read -r section; do
    [ -n "$section" ] || continue
    # Same shape as check_preamble_intact, and temp files for the same two reasons: a reader in
    # a process substitution cannot report, and diff counts the trailing newlines string capture
    # would drop. Both files are removed on every path out of the iteration.
    base_sec=$(mktemp) || {
      err_full "E-TMPFILE: $path: cannot create a temp file to compare '$section'"
      continue
    }
    tree_sec=$(mktemp) || {
      rm -f "$base_sec"
      err_full "E-TMPFILE: $path: cannot create a temp file to compare '$section'"
      continue
    }

    read_status=0
    section_body "$tmp" "$section" >"$base_sec" || read_status=$?
    if [ "$read_status" -eq 0 ]; then
      section_body "$path" "$section" >"$tree_sec" || read_status=$?
    fi
    if [ "$read_status" -ne 0 ]; then
      rm -f "$base_sec" "$tree_sec"
      err_full "E-APPEND-DIFF-SCAN: $path: could not read '$section' from it or from the base ref's copy, so the rule did not run for that section (awk exit $read_status)"
      continue
    fi

    diff_status=0
    diff_out=$(diff "$base_sec" "$tree_sec") || diff_status=$?
    rm -f "$base_sec" "$tree_sec"
    if [ "$diff_status" -ge 2 ]; then
      err_full "E-APPEND-DIFF-SCAN: $path: could not compare '$section' against the base ref's copy (diff exit $diff_status)"
      continue
    fi

    removed=$(printf '%s\n' "$diff_out" | grep -c '^<') || :
    if [ "$removed" -gt 0 ]; then
      err_full "E-REWRITE: $path drops $removed line(s) from '$section' that the base ref had — a merged record is append-only there; resolve it with a banner rather than rewriting it"
    fi
  done <<<"$sections"
}

check_not_rewritten() {
  local base=$1 path=$2 tmp blob_status=0 marker_status
  # Returning 0 here exempted the record from all three rules below with no diagnostic at all,
  # so a run over an unusable temp directory reported every record as unrewritten. Its own code
  # rather than evaluate_base_conformance's E-TMPFILE: that one also fires over every record,
  # so a reader — and the suite, which asserts on the code — cannot tell from an E-TMPFILE alone
  # whether the anti-erasure rules ran. err_full for the same reason the branch below uses it:
  # these three rules describe a change, not a record, and are never downgradable.
  if ! tmp=$(mktemp); then
    err_full "E-REWRITE-TMPFILE: $path: cannot create a temp file, so the append-only rules did not run"
    return 0
  fi
  read_base_blob "$base" "$path" "$tmp" || blob_status=$?
  case $blob_status in
  0) ;;
  # Absent at the base ref: there is nothing for the three rules below to compare against, and
  # they are each defined against a base-ref copy. The sole caller iterates the base ref's own
  # record listing, so this branch is not reached in practice — it is here because the answer
  # belongs to the predicate, not because a base record can vanish between two git queries.
  1)
    rm -f "$tmp"
    return 0
    ;;
  # Present but unreadable. Returning 0 here exempted the record from check_sections_append_only,
  # check_headings_intact and check_preamble_intact — every anti-erasure rule off at once,
  # granted by a read that never completed, on a run that then exited 0.
  *)
    rm -f "$tmp"
    err_full "E-BASE-BLOB-SCAN: $path: could not read the base ref's copy at $base, so the append-only rules did not run (exit $base_blob_status)"
    return 0
    ;;
  esac

  # The one permitted class of edit to a merged record's protected regions. Checked before
  # any of the three rules rather than inside each, so all three answer to one predicate and
  # a change is either marker-only or it is not.
  marker_status=0
  marker_only_change "$tmp" "$path" || marker_status=$?
  case $marker_status in
  0)
    rm -f "$tmp"
    return 0
    ;;
  1) ;;
  # Neither shape could be built, so "is this change marker-only" has no answer. Reporting is
  # the whole point: the `if marker_only_change` this replaces read a faulted read as "yes,
  # marker-only" and turned all three anti-erasure rules off at once, silently.
  *)
    rm -f "$tmp"
    err_full "E-MARKER-SHAPE-SCAN: $path: could not canonicalise it or the base ref's copy, so the append-only rules did not run (awk exit $marker_only_status)"
    return 0
    ;;
  esac

  check_sections_append_only "$tmp" "$path"
  check_headings_intact "$tmp" "$path"
  check_preamble_intact "$tmp" "$path"

  rm -f "$tmp"
}

# The base-ref verdict for one record, in `collect` mode: the blob-local structural rules are
# evaluated against the base ref's bytes and only the verdict is kept.
#
# Conformance is a property of the base ref, not of whether the change touched the record.
# Deriving it from the diff would deadlock: adding a supersession banner to a pre-template ADR
# would demand full conformance, which immutability forbids reaching, so the gate would refuse
# the one edit the convention permits. It is also ungameable in the direction that matters,
# since a grandfathered record has to exist in a ref the change cannot edit.
#
# Blob-local means decidable from one file's bytes and its path. That restriction is what makes
# this implementable: the pass needs no sibling list, no second directory listing, and no
# cross-record state at the base ref.
#
# Sets the global `base_verdict` rather than printing it. Called in a command substitution, the
# err calls below would set collect_verdict in a discarded subshell and every record would read
# as conforming.
base_verdict=absent

evaluate_base_conformance() {
  local base=$1 path=$2 tmp saved_mode blob_status=0
  base_verdict=absent
  if ! tmp=$(mktemp); then
    err "E-TMPFILE: cannot create a temp file — cannot determine the base-ref shape of $path"
    return 0
  fi
  read_base_blob "$base" "$path" "$tmp" || blob_status=$?
  case $blob_status in
  0) ;;
  # Absent at the base ref, which is what `absent` means: the record is new, so it is neither
  # grandfathered nor non-conforming and the tree pass judges it at full severity.
  1)
    rm -f "$tmp"
    return 0
    ;;
  # Present but unreadable, which used to reach the same `absent` verdict — a record that could
  # not be read at the base ref was reported as one that was not there. base_verdict stays
  # `absent` here too, so the tree pass still runs at full severity: a read that never completed
  # cannot establish the grandfathering a `nonconforming` verdict would grant.
  *)
    rm -f "$tmp"
    err_full "E-BASE-SHAPE-SCAN: $path: could not read the base ref's copy at $base, so its base-ref shape is undetermined (exit $base_blob_status)"
    return 0
    ;;
  esac

  saved_mode=$EMIT_MODE
  EMIT_MODE=collect
  collect_verdict=0
  check_sections "$tmp" "$path"
  check_status "$tmp" "$path" base
  profile_check_extra "$tmp" "$path" base "$record_resolved"
  EMIT_MODE=$saved_mode
  rm -f "$tmp"

  if [ "$collect_verdict" -ne 0 ]; then
    base_verdict=nonconforming
  else
    base_verdict=conforming
  fi
}

check_no_disappearances() {
  local base=$1 tree record renumbered_to="" used_renumber_targets="" renum_status still_status
  local tree_status=0
  records_in_ref "$base" || tree_status=$?
  if [ "$tree_status" -ne 0 ]; then
    err "E-BASE-TREE: could not read $RECORD_DIR at $base — cannot check for removed records (git exit $records_in_ref_status)"
    return 0
  fi
  tree=$records_in_ref_out

  while IFS= read -r record; do
    [ -n "$record" ] || continue
    if [ -L "$record" ]; then
      err "E-GONE-SYMLINK: $record was replaced by a symlink — a record is a real file, and a link is not one"
      continue
    fi
    # One predicate, evaluated once. The two branches used to spell it out separately —
    # `present_as_real_file && tracked_in_index` against `! still_a_record` — which is the shape
    # that collapses a three-valued answer, since neither can express the third case.
    still_status=0
    still_a_record "$record" || still_status=$?
    case $still_status in
    0) check_not_rewritten "$base" "$record" ;;
    1)
      renumbered_to=""
      renum_status=0
      renumbered_elsewhere "$base" "$record" || renum_status=$?
      case $renum_status in
      0) info "note: $record was renumbered to $renumbered_to (content unchanged)" ;;
      3)
        warn_full "W-RENUMBER-SCAN: $record: found renumber destination $renumbered_to after an incomplete search (could not read $renumber_fault_path, exit $path_exists_status)"
        info "note: $record was renumbered to $renumbered_to (content unchanged)"
        ;;
      1) err "E-GONE: $record is no longer a record at that path (deleted, moved, untracked, or renamed with its content changed) — resolve records in place with a '> **Resolved by ...**' banner" ;;
      # Reported instead of E-GONE, never alongside it: whether the record moved is exactly what
      # could not be established — by a candidate witness that did not run, by a candidate the
      # index could not be read for, or by the record's own base-ref copy being unreadable,
      # which aborts before any candidate is tried. The record stays the subject, because it is
      # the record the verdict is about; renumber_fault_path names what could not be read, which
      # is rarely that same file and is read by a different git command in each of the three.
      *) err_full "E-RENUMBER-SCAN: $record: could not determine whether it was renumbered at $base (could not read $renumber_fault_path, exit $path_exists_status)" ;;
      esac
      ;;
    # Neither branch above is safe on a record whose index entry could not be read: the first
    # would run the append-only rules over a record the gate cannot say is still in the
    # repository, and the second reported E-GONE for one sitting untouched in the tree.
    *) err_full "E-TRACKED-SCAN: $record: could not read the index entry for it, so the append-only rules did not run (git exit $tracked_in_index_status)" ;;
    esac
  done <<<"$tree"
}

# Old<TAB>new, one mapping per line, populated by the PR that renames a gate file and pruned by
# the PR that follows. An entry with no slash is a sibling basename resolved against SELF_DIR,
# which keeps a same-directory rename layout-independent — an adopter's scripts live at
# .github/scripts/, so a repo-path mapping would be wrong for them. An entry with a slash is a
# repo-relative path, which is the only way to express a rename that moved directories: the old
# path is not under the new SELF_DIR at all. A path-form entry is inert everywhere else, since
# check_gate_files only consults the mapping for a path the base ref actually has.
#
# A stale entry is inert for *exemption*, but the registry is not otherwise inert and must not
# be emptied. gate_known_basenames draws the gate-existence witness set from both sides of
# every entry, so the entries here are what let this gate recognise the name it had at a base
# ref that predates a rename. Empty the list and an undeclared rename of the script stops
# being E-GATE-EMPTY-SET and becomes I-GATE-BOOTSTRAP at exit 0 — a false green on the exact
# vector that rule exists to catch, reproduced by renamed_gate, renamed_no_workflow,
# renamed_moved_dir and renamed_gate_workflow_collision, all four of which go red if this
# string is emptied.
#
# The registry's non-regression boundary forbids making that shape more reachable: both
# witnesses depend on the gate having been named something this registry knows, and a prune
# removes the only name it knows besides the running script's own. Prune an individual entry
# only with the suite green afterwards.
#
# A predecessor is by definition present at the base ref and absent from the tree, which is the
# E-GATE-GONE condition — so a bare list would trade one red for another. Exemption is granted
# only where the named successor exists as a tracked, non-symlink regular file. That proves a
# file exists there, not that it is the gate; it narrows the door rather than verifying the
# redirection.
GATE_PREDECESSORS="check-debt.sh	check-records.sh
check-debt-test.sh	check-records-test.sh
shared/skills/debt-tracking/assets/check-records.sh	shared/skills/tome-of-lore/assets/check-records.sh
shared/skills/debt-tracking/assets/check-records-test.sh	shared/skills/tome-of-lore/assets/check-records-test.sh
shared/skills/debt-tracking/assets/profiles/debt.sh	shared/skills/tome-of-lore/assets/profiles/debt.sh
shared/skills/debt-tracking/assets/debt.yml	shared/skills/tome-of-lore/assets/records.yml
.github/workflows/debt.yml	.github/workflows/records.yml"

# The repo-relative path an entry names: itself when it carries a slash, or a SELF_DIR sibling
# when it does not.
gate_predecessor_path() {
  local entry=$1
  case "$entry" in
  */*) printf '%s' "$entry" ;;
  *) repo_relative "$SELF_DIR/$entry" ;;
  esac
}

predecessor_successor() {
  local old=$1 line key
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    key=${line%%$'\t'*}
    case "$key" in
    */*) [ "$key" = "$old" ] || continue ;;
    *) [ "$key" = "${old##*/}" ] || continue ;;
    esac
    printf '%s' "${line#*$'\t'}"
    return 0
  done <<<"$GATE_PREDECESSORS"
  return 1
}

# Basenames this gate might have appeared under at the base ref: the current one, plus
# both sides of every GATE_PREDECESSORS mapping. A closed set rather than a check-*.sh
# glob: an adopter's own unrelated .github/scripts/check-lint.sh, or a workflow invoking
# ./ci/check-format.sh, matches the glob for free and would misreport E-GATE-EMPTY-SET on
# an adoption PR that never touched this gate at all — a diagnosis unrelated to what
# happened is worse than none. The set stays closed even across an undeclared rename: the
# name that needs recognizing is whatever this gate was called *before* it, which is
# exactly what GATE_PREDECESSORS exists to record, so the witnesses below trust the same
# registry check_gate_files does rather than a second, looser notion of "looks like a gate".
gate_known_basenames() {
  local line key new
  printf '%s\n' "$(basename "$SELF_FILE")"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    key=${line%%$'\t'*}
    new=${line#*$'\t'}
    key=${key##*/}
    new=${new##*/}
    # Scripts only. A witness is handed to `git grep -F` over the base ref's workflows, and a
    # workflow or template filename is generic enough to appear in an unrelated repo's
    # workflows — `records.yml` is the very name the adoption table tells adopters to create,
    # so a `uses:` reference or a paths filter naming it would witness a gate that was never
    # there. That turns an adoption PR's I-GATE-BOOTSTRAP into E-GATE-EMPTY-SET: the false red
    # the closed set exists to prevent, through names looser than the check-*.sh glob this
    # function's comment already rejects. Exemption still consults the full mapping; only the
    # existence witness is narrowed.
    case "$key" in *.sh) printf '%s\n' "$key" ;; esac
    case "$new" in *.sh) printf '%s\n' "$new" ;; esac
  done <<<"$GATE_PREDECESSORS"
}

# Evidence the gate existed at the base ref, independent of the current filenames. Two
# witnesses: a known basename sitting in SELF_DIR at the base ref, and a base-ref workflow
# naming one. The workflow witness matters on its own even when the SELF_DIR one could in
# principle cover the same history: a gate that moved directories as well as names (the
# repo-root-to-.github/scripts/ layouts both exist among adopters) leaves no known name
# under the *current* SELF_DIR at the base ref, but the base-ref workflow still names the
# script wherever it lived. Conversely, a repo that drives the checker from something other
# than GitHub Actions has no workflow to grep (gate_paths blesses that layout explicitly),
# so without the SELF_DIR witness an undeclared rename there has no witness at all and is
# misreported as a bootstrap — exactly the silent pass this rule exists to prevent.
#
# Every witness runs against the base ref, where the old name necessarily still is, so a
# bare undeclared rename is fatal rather than mistaken for adoption. `repo_relative`'s
# result is checked non-empty before use: unguarded, an empty result makes the git argument
# "${base}:/name", and depending on git's tree lookup an absolute-looking path can still
# resolve — checked explicitly rather than relied on to fail closed.
# Four outcomes: 0 a witness found the gate after a complete search, 1 no witness did, 2 no
# witness answered because a scan faulted, 3 a witness found the gate after an earlier fault.
# Neither witness used to capture its status, so a scan fault was indistinguishable from every
# witness genuinely finding nothing — and the caller reported that as I-GATE-BOOTSTRAP, an
# exit-0 informational line, instead of the fatal E-GATE-EMPTY-SET an undeclared rename owes.
# The path whose witness faulted, for the caller's diagnostic: a scan fault a reader cannot
# locate is barely better than a silent one. Set on every gate_existed_at entry, and read only
# by its caller, which runs after it.
gate_witness_path=""
gate_existed_at() {
  local base=$1 rel name status fault_status=0

  gate_witness_path=""
  rel=$(repo_relative "$SELF_DIR")
  if [ -n "$rel" ]; then
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      status=0
      path_exists_at "$base" "${rel}/${name}" || status=$?
      case $status in
      0)
        if [ "$fault_status" -ne 0 ]; then
          path_exists_status=$fault_status
          return 3
        fi
        return 0
        ;;
      1) ;;
      *)
        fault_status=$path_exists_status
        gate_witness_path="${rel}/${name}"
        ;;
      esac
    done < <(gate_known_basenames)
  fi

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    # git grep exits 1 for "no match" and 128 for a bad ref, so 2 or more is a real fault
    # here, unlike git cat-file -e where 128 is also the ordinary absent answer.
    status=0
    git grep --no-color -qF "$name" "$base" -- .github/workflows 2>/dev/null || status=$?
    case $status in
    0)
      if [ "$fault_status" -ne 0 ]; then
        path_exists_status=$fault_status
        return 3
      fi
      return 0
      ;;
    1) ;;
    *)
      fault_status=$status
      gate_witness_path=".github/workflows (searching for $name)"
      ;;
    esac
  done < <(gate_known_basenames)

  # A positive witness returns above, so it outranks a fault on any other witness: evidence
  # the gate existed is not weakened by an unrelated probe failing. Return 3 rather than 0 in
  # that case so the caller can report the incomplete search without changing its verdict.
  if [ "$fault_status" -ne 0 ]; then
    path_exists_status=$fault_status
    return 2
  fi
  return 1
}

# The gate defends its own files against deletion. It cannot defend against being edited,
# nor against the workflow being removed (that stops the job rather than failing it) — only
# a required status check and a human reviewer close those.
#
# Split out of check_no_disappearances so it runs once from main rather than once per
# profile — a repo with more than one profile would otherwise print every gate finding once
# per profile in RECORD_PROFILES.
check_gate_files() {
  local base=$1 paths paths_status=0 self successor successor_path gate_path_count=0
  local self_status still_status succ_status
  paths=$(gate_paths "$base") || paths_status=$?
  if [ "$paths_status" -ne 0 ]; then
    err_full "E-GATE-PATHS-SCAN: $base: could not search the base ref's workflows for gate paths (git exit $paths_status)"
    return
  fi
  while IFS= read -r self; do
    [ -n "$self" ] || continue
    self_status=0
    path_exists_at "$base" "$self" || self_status=$?
    case $self_status in
    0) ;;
    1) continue ;;
    *)
      # Counted but not examined. Skipping the body keeps E-GATE-GONE off a path whose
      # base-ref presence is unknown; counting it keeps the empty-set branch below from
      # reporting I-GATE-BOOTSTRAP — "no gate existed here" — off a witness that never ran.
      err_full "E-GATE-SCAN: $self: could not check the gate file at $base (git exit $path_exists_status)"
      gate_path_count=$((gate_path_count + 1))
      continue
      ;;
    esac
    gate_path_count=$((gate_path_count + 1))
    if [ -L "$self" ]; then
      err "E-GATE-SYMLINK: $self is a symlink — a gate file swapped for a link no longer contains the gate"
      continue
    fi
    still_status=0
    still_a_record "$self" || still_status=$?
    case $still_status in
    0) continue ;;
    1) ;;
    # E-GATE-GONE accuses the change of removing a gate file. An index the gate could not read
    # cannot support that accusation about a file that is sitting right there.
    *)
      err_full "E-GATE-TRACKED-SCAN: $self: could not read the index entry for the gate file (git exit $tracked_in_index_status)"
      continue
      ;;
    esac

    successor=$(predecessor_successor "$self") || successor=""
    successor_path=""
    [ -n "$successor" ] && successor_path=$(gate_predecessor_path "$successor")
    # The exemption turns on the successor really being tracked, so the whole test is folded
    # into one three-valued status: no declared successor and an untracked one are both the
    # ordinary negative, and only an index query that could not run is the third case.
    succ_status=1
    if [ -n "$successor_path" ] && [ -f "$successor_path" ] && [ ! -L "$successor_path" ]; then
      succ_status=0
      tracked_in_index "$successor_path" || succ_status=$?
    fi
    case $succ_status in
    0) info "note: $self was renamed to $successor_path" ;;
    1) err "E-GATE-GONE: $self was deleted or untracked — the gate cannot be removed by the change it gates" ;;
    *) err_full "E-GATE-SUCCESSOR-SCAN: $successor_path: could not read the index entry for $self's declared successor, so the rename is unverified (git exit $tracked_in_index_status)" ;;
    esac
  done < <(printf '%s\n' "$paths" | sort -u)

  # An empty protected set means self-protection is off. That is the correct state for the
  # PR that installs the gate in a new repo, and a silent failure for one that renamed it —
  # and the two must be separated by a predicate that is not the emptiness test restated.
  if [ "$gate_path_count" -eq 0 ]; then
    local existed_status=0
    gate_existed_at "$base" || existed_status=$?
    case $existed_status in
    0) err "E-GATE-EMPTY-SET: no gate file from the base ref is protected — a rename must declare its predecessors in GATE_PREDECESSORS" ;;
    3)
      warn_full "W-GATE-WITNESS-SCAN: $gate_witness_path: a later witness established that a gate existed at $base after this read failed (git exit $path_exists_status)"
      err "E-GATE-EMPTY-SET: no gate file from the base ref is protected — a rename must declare its predecessors in GATE_PREDECESSORS"
      ;;
    1) info "I-GATE-BOOTSTRAP: no gate existed at $base — this is the change installing it" ;;
    *) err_full "E-GATE-WITNESS-SCAN: $gate_witness_path: could not determine whether a gate existed at $base (git exit $path_exists_status)" ;;
    esac
  fi
}

# Repo-relative form of an absolute path, or nothing when the path is outside the repo.
# Pure parameter expansion: `realpath --relative-to` is GNU-only and absent on macOS.
repo_relative() {
  local abs=$1
  case "$abs" in
  "$PWD"/*) printf '%s' "${abs#"$PWD"/}" ;;
  *) : ;; # caller decides: for the gate's own files this is fatal, see gate_paths
  esac
}

# The gate's own files: this script, its suite beside it, and any workflow that invoked it
# **in the base ref**. Derived rather than hardcoded so the same checker protects itself
# whether it lives in .github/scripts/ or in the publishing repo's skill assets.
#
# The workflow set comes from the base ref deliberately. Deriving it from the working tree
# would let the change under review remove a workflow from its own protected set simply by
# stopping it from mentioning the checker — swapping it for a symlink to an inert file does
# exactly that. A repo driving the checker from something other than GitHub Actions yields
# no workflow here, which is not an error; that file is just not protected.
# Emits paths only. It must not call err: callers capture its output and status separately,
# because an err inside that subshell would set failed=1 only in the discarded process. The
# caller reports a non-zero status before it reads any paths.
gate_paths() {
  local base=$1 rel profile old key new needle profiles_rel matches grep_status needles
  rel=$(repo_relative "$SELF_FILE")
  [ -n "$rel" ] && printf '%s\n' "$rel"

  # Emitted whether or not it currently exists: gating on its presence would mean the
  # suite is protected only while it is there, which detects nothing. Whether it was ever
  # part of the gate is decided against the base ref by the caller.
  rel=$(repo_relative "$SELF_DIR/check-records-test.sh")
  [ -n "$rel" ] && printf '%s\n' "$rel"

  # Predecessor paths of the gate's own files. A rename drops the old name, which is
  # present at the base ref and absent from the tree — exactly E-GATE-GONE — so the old
  # name must be checked too, not just the current one, for check_gate_files to have a
  # chance to exempt it via GATE_PREDECESSORS.
  #
  # A workflow predecessor is excluded here, unlike a script one: this loop emits an entry
  # unconditionally, and an entry naming a workflow path is not scoped to SELF_DIR the way a
  # script sibling is — .github/workflows/debt.yml is the literal filename the adoption
  # table has told every adopter to create, so listing it here would check for that exact
  # path in every repo this gate runs in, base ref or not. A workflow predecessor is found
  # instead through the needle search below, which only matches a base ref that actually
  # names this script or a script predecessor — the same discovery a rename that predates
  # any declared mapping already relies on.
  while IFS= read -r old; do
    [ -n "$old" ] || continue
    key=${old%%$'\t'*}
    case "$key" in
    .github/workflows/*) continue ;;
    esac
    rel=$(gate_predecessor_path "$key")
    [ -n "$rel" ] && printf '%s\n' "$rel"
  done <<<"$GATE_PREDECESSORS"

  # Profiles are part of the gate. Derived from the base ref's listing rather than from the
  # enabled profile names: by-name derivation would let one change drop a profile from the
  # list *and* delete its file with nothing firing, because the deleted file was never in
  # the set.
  # The pathspec is guarded rather than interpolated inline: empty is what repo_relative
  # returns when this script sits outside the repo, and `git ls-tree -- ''` is a fatal
  # pathspec error rather than an empty listing, so the `|| true` below would have swallowed
  # it and left every profile silently unprotected. A directory merely absent from the ref
  # exits 0 with no output, so that case never needed the guard.
  #
  # The `|| true` stays. gate_paths runs inside a process substitution, where err's
  # assignment to `failed` lands in a discarded subshell -- it emits paths only, and its
  # callers report. A damaged object store is therefore an accepted residual here rather than
  # an oversight; giving this one function a fault channel means a private sentinel protocol
  # between it and its caller, which ADR 0005 weighed and rejected.
  profiles_rel=$(repo_relative "$SELF_DIR/profiles")
  if [ -n "$profiles_rel" ]; then
    while IFS= read -r profile; do
      [ -n "$profile" ] || continue
      rel=$(repo_relative "$SELF_DIR/profiles/${profile##*/}")
      [ -n "$rel" ] && printf '%s\n' "$rel"
    done < <(git ls-tree -r --name-only "$base" -- "$profiles_rel" 2>/dev/null || true)
  fi

  # The workflow template, when it ships beside the scripts. It is part of the gate in the
  # publishing layout, and an adopting repo simply has no such sibling.
  rel=$(repo_relative "$SELF_DIR/records.yml")
  [ -n "$rel" ] && printf '%s\n' "$rel"

  # Any workflow at the base ref that names either the current script or a retired script
  # basename. Searching only the current basename would drop this repo's own workflow from
  # the protected set for the duration of the PR that performs the rename, since the base
  # ref's workflow still names the old script.
  #
  # A key's basename is a needle only when the mapping itself retired it — its own basename
  # differs from its own successor's basename — and only when it is a script name (`.sh`).
  # The comparison is intra-entry, not against the currently running script: comparing
  # against `basename "$SELF_FILE"` instead would make three of this repo's own path-form
  # entries (whose rename moved only the directory, not the name) look "retired" to every
  # *other* repo that runs this same shipped script under a different current name, and
  # `check-records.sh` — still this repo's current script, not retired at all — would then
  # content-match any unrelated workflow that merely runs the gate. The `.sh` filter excludes
  # `.yml` basenames for the same reason `gate_known_basenames` does: `debt.yml`/`records.yml`
  # are generic enough to appear in an unrelated repo's workflow for reasons that have nothing
  # to do with this gate.
  #
  # The caller sorts the complete result: a workflow naming more than one needle (this repo's
  # own workflow names both check-debt.sh and check-debt-test.sh in the same PR) would otherwise
  # be emitted once per match, and check_gate_files would report the same finding more than once.
  needles=${SELF_FILE##*/}
  while IFS= read -r old; do
    [ -n "$old" ] || continue
    key=${old%%$'\t'*}
    new=${old#*$'\t'}
    key=${key##*/}
    new=${new##*/}
    case "$key" in
    *.sh) [ "$key" = "$new" ] || needles="$needles
$key" ;;
    esac
  done <<<"$GATE_PREDECESSORS"

  while IFS= read -r needle; do
    grep_status=0
    matches=$(git grep --no-color -lF "$needle" "$base" -- .github/workflows 2>/dev/null) ||
      grep_status=$?
    case $grep_status in
    0)
      while IFS= read -r rel; do
        printf '%s\n' "${rel#*:}"
      done <<<"$matches"
      ;;
    1) ;;
    *) return "$grep_status" ;;
    esac
  done <<<"$needles"
}

# `git rev-parse --show-toplevel` exits non-zero for more than "you are not inside a git
# repository": dubious ownership under a bind mount or a container UID mismatch, an unreadable
# or damaged .git, an unreadable parent directory. E-NOT-REPO named the first of those and
# `2>/dev/null` threw away git's own line — which for dubious ownership carries the exact
# `git config --global --add safe.directory <path>` remedy, the only line that gets the
# operator moving. Report what the probe established instead, as ADR 0005 decision 1 asks: the
# command that ran and the status it returned, with git's line left standing in front of it.
require_repo_root() {
  local root root_status=0
  root=$(git rev-parse --show-toplevel) || root_status=$?
  if [ "$root_status" -ne 0 ]; then
    err "E-ROOT-UNRESOLVED: could not resolve the repository root (git rev-parse --show-toplevel exit $root_status)"
    return 1
  fi
  cd "$root"
}

# A file the profile permits in the record directory without being a record — docs/adr/README.md
# for the ADR profile. Exempt means "not a record", not "invisible": profile rules may still
# read it.
#
# An entry names one path at the top of the record directory, not a basename at any depth.
# Reducing the candidate to its basename first exempted docs/adr/archive/README.md too, which
# is a wider stray-file allowance than "docs/adr/README.md is the one named exception" states.
# The sole caller passes a RECORD_DIR-prefixed path, so the entry is resolved against it.
is_exempt_file() {
  local path=$1 exempt
  [ -n "$RECORD_EXEMPT_FILES" ] || return 1
  while IFS= read -r exempt; do
    [ -n "$exempt" ] || continue
    [ "$path" = "$RECORD_DIR/$exempt" ] && return 0
  done <<<"$RECORD_EXEMPT_FILES"
  return 1
}

# Enumerate everything under the directory that is not a directory, so symlinks and
# stray non-markdown files are seen rather than filtered out of existence.
#
# Assigns the newline-delimited record list to `records` rather than printing it: called
# in a command substitution its err calls would set failed=1 in a subshell and lose it,
# which is how a stray file once printed an error and still exited 0.
collect_records() {
  local found path
  if [ -L "$RECORD_DIR" ]; then
    err "E-DIR-SYMLINK: $RECORD_DIR is a symlink — the record directory must be a real directory"
    return 0
  fi
  [ -d "$RECORD_DIR" ] || return 0

  if ! found=$(find "$RECORD_DIR" -mindepth 1 ! -type d -print | sort); then
    err "E-ENUM: could not enumerate $RECORD_DIR"
    return 0
  fi

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if [ -L "$path" ]; then
      err "E-RECORD-SYMLINK: $path is a symlink — a record must be a real file"
      continue
    fi
    if printf '%s' "$path" | grep -qE "$RECORD_RE"; then
      if [ -n "$records" ]; then
        records="$records
$path"
      else
        records=$path
      fi
    else
      if is_exempt_file "$path"; then
        continue
      fi
      err "E-NOT-RECORD: $path is under $RECORD_DIR but is not a record — records are NNNN-slug.md at the top level"
    fi
  done <<<"$found"
}

count_lines() {
  [ -n "$1" ] || {
    printf '0'
    return 0
  }
  printf '%s\n' "$1" | grep -c .
}

# Existence at a ref, with a scan fault distinguishable from an absence: 0 present, 1 absent,
# 2 the scan could not run. `git cat-file -e` cannot answer this — it exits 128 both for a path
# absent from a valid ref and for a bad ref, so its normal absent case is already the fault code.
# `git ls-tree` exits 0 with empty output for an absent path and non-zero only for a real fault.
#
# The predicate's own 2 is a sentinel, so git's real status is left in path_exists_status for
# the caller's diagnostic: reporting "git exit 2" would name a status git never returned.
#
# stderr is suppressed for the reason records_in_ref gives: a bare `fatal:` from git is not this
# gate's interface, its coded ::error:: lines are.
path_exists_status=0
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

# The base ref's copy of one record, written to `dest`. Three-valued like path_exists_at, which
# it delegates the first half to: 0 the copy is in `dest`, 1 the path is absent from the base
# ref, 2 the read could not run.
#
# The split is the whole point. `git cat-file blob` exits 128 both for a path absent from a valid
# ref and for a bad or damaged one, so on its own it cannot say which happened — and absence is
# the ordinary case, since a record the change adds has no base copy at all. Every caller below
# therefore used to read an unreadable blob as an absent one and skip its rule. Presence is
# witnessed with `git ls-tree` first (ADR 0005 decision 2) and a read that fails for a path git
# has just listed is a fault, not an absence.
#
# The failing status is left in base_blob_status for the caller's diagnostic, for the reason
# path_exists_at leaves its own there: this predicate's 2 is a sentinel, and reporting it would
# name a status nothing returned. The callers' messages say `exit N` rather than `git exit N`,
# because a redirection that fails on a full temp directory yields bash's status, not git's.
base_blob_status=0
read_base_blob() {
  local base=$1 path=$2 dest=$3 status=0
  base_blob_status=0
  path_exists_at "$base" "$path" || status=$?
  case $status in
  0) ;;
  1) return 1 ;;
  *)
    base_blob_status=$path_exists_status
    return 2
    ;;
  esac

  status=0
  git cat-file blob "${base}:${path}" >"$dest" 2>/dev/null || status=$?
  if [ "$status" -ne 0 ]; then
    base_blob_status=$status
    return 2
  fi
  return 0
}

# Whether the directory existed at the base ref. An absent-from-both-refs directory is a
# misconfiguration; one that existed at base and is gone now is erasure, and must keep
# reporting E-GONE per record — `no_dir` deletes docs/debt wholesale and asserts exactly that.
# With no base ref, absence is not an error: `no_records_no_base` removes the only record,
# which leaves git deleting the emptied directory, and expects exit 0.
#
# Three-valued like path_exists_at, which it delegates to. The two guards below stay fail-open
# on purpose: with no base ref, or one that is not a commit, there is nothing to have existed.
dir_in_ref() {
  local ref=$1 dir=$2 status=0
  [ -n "$ref" ] || return 0
  git rev-parse --verify --quiet "${ref}^{commit}" >/dev/null || return 0
  path_exists_at "$ref" "$dir" || status=$?
  return "$status"
}

# Base-ref validity, split out of check_no_disappearances so it reports once rather than
# once per profile.
check_base_ref() {
  local base=$1
  if ! git rev-parse --verify --quiet "${base}^{commit}" >/dev/null; then
    err "E-BASE-REF: BASE_SHA '$base' is not a commit in this repository — cannot check for removed records"
    return 1
  fi
}

# One profile's records, end to end. `records` is declared here and read by collect_records
# and renumbered_elsewhere through bash's dynamic scoping, exactly as it was in main.
run_profile() {
  local name=$1
  load_profile "$name" || return 1

  local records="" record_count base_records="" base_count dir_status=0 list_status
  # `if ! dir_in_ref` would collapse "absent at base" and "could not tell" into one branch,
  # which is the defect this rule was converted to remove. Branch on the captured status.
  if [ ! -d "$RECORD_DIR" ]; then
    dir_in_ref "${BASE_SHA:-}" "$RECORD_DIR" || dir_status=$?
    case $dir_status in
    0) ;;
    1)
      err "E-PROFILE-DIR-MISSING: profile '$name' is enabled but $RECORD_DIR exists at neither the base ref nor the tree"
      return 1
      ;;
    *)
      # Returning rather than continuing: E-COUNT-FLOOR below compares against a base record
      # count that would be zero for the same unreadable-ref reason, so carrying on would
      # disarm the one rule that catches a clean run over nothing.
      err_full "E-DIR-SCAN: $RECORD_DIR: could not check the record directory at ${BASE_SHA:-} (git exit $path_exists_status)"
      return 1
      ;;
    esac
  fi

  collect_records
  record_count=$(count_lines "$records")

  # base_valid comes from main through the same dynamic scoping as `records`. A BASE_SHA
  # that failed check_base_ref is not retried here — that would report the same bad ref
  # under E-BASE-TREE instead of just E-BASE-REF, once per profile.
  if [ -n "${BASE_SHA:-}" ] && [ "$base_valid" -eq 1 ]; then
    check_no_disappearances "${BASE_SHA}"
    # `|| true` here discarded the fault records_in_ref raises when its `git ls-tree` faults on
    # the base ref. The list came back empty, base_count was 0, and E-COUNT-FLOOR — the rule
    # that exists to refuse a clean run over nothing — was disarmed by a read that never
    # completed. ADR 0005 named this site and assigned it to #63.
    list_status=0
    records_in_ref "${BASE_SHA}" || list_status=$?
    base_records=$records_in_ref_out
    if [ "$list_status" -ne 0 ]; then
      err_full "E-BASE-LIST-SCAN: $BASE_SHA: could not list the $RECORD_LABEL records at the base ref, so E-COUNT-FLOOR did not run (git exit $records_in_ref_status)"
    else
      base_count=$(count_lines "$base_records")
      if [ "$base_count" -gt 0 ] && [ "$record_count" -eq 0 ]; then
        err "E-COUNT-FLOOR: $BASE_SHA held $base_count $RECORD_LABEL record(s) but none are readable now — refusing to report a clean run over nothing"
      fi
    fi
  fi

  info "Checking $record_count $RECORD_LABEL record(s) in $RECORD_DIR."

  # Mode discipline: `report` is the default, evaluate_base_conformance sets and restores
  # `collect` itself, and `downgrade` is set per record and cleared after each one. A loop that
  # leaked `downgrade` past its last record would silently downgrade profile_check_directory's
  # findings too.
  local record
  if [ -n "$records" ]; then
    while IFS= read -r record; do
      [ -n "$record" ] || continue
      base_verdict=absent
      if [ -n "${BASE_SHA:-}" ] && [ "$base_valid" -eq 1 ]; then
        evaluate_base_conformance "${BASE_SHA}" "$record"
      fi
      if [ "$base_verdict" = nonconforming ]; then
        EMIT_MODE=downgrade
      fi
      check_sections "$record" "$record"
      check_status "$record" "$record" tree
      profile_check_extra "$record" "$record" tree "$record_resolved"
      EMIT_MODE=report
    done <<<"$records"
  fi

  check_unique_numbers "$records" "$base_records"

  # Once per profile, after the record list is built, and always at full severity: its subject
  # is a file that is not a record, so no record's verdict has any bearing on it.
  profile_check_directory "$records"
}

# Repository and gate checks run exactly once. Run inside the profile loop they would report
# every global failure once per profile.
#
# The order is load-bearing: `outside_tree` copies the engine (with its profiles sibling)
# outside this repository and still asserts E-GATE-UNLOCATABLE, which it reaches only
# because the gate check runs before profile resolution, not because of any unknown-profile
# interaction; `not_a_repo` requires E-ROOT-UNRESOLVED to win.
#
# Without a base ref there is nothing to compare against, so the base-ref and gate phases do
# not apply — exactly as today, where they live inside a function that only runs when BASE_SHA
# is set. E-GATE-UNLOCATABLE still fires, since locating this script needs no base ref.
main() {
  require_repo_root || return 1

  if [ -z "$(repo_relative "$SELF_FILE")" ]; then
    err "E-GATE-UNLOCATABLE: cannot locate $SELF_FILE inside this repository — self-protection is off"
  fi

  local base_valid=0
  if [ -n "${BASE_SHA:-}" ]; then
    if check_base_ref "${BASE_SHA}"; then
      base_valid=1
      check_gate_files "${BASE_SHA}"
    fi
  elif [ -n "${GITHUB_ACTIONS:-}" ]; then
    err "E-BASE-EMPTY-CI: BASE_SHA is empty in CI — the removed-record check cannot run"
  else
    info "BASE_SHA unset — validating records only; set it to run the full gate."
  fi

  local profiles=${RECORD_PROFILES:-} name
  if [ -z "$profiles" ]; then
    err "E-PROFILE-NONE: RECORD_PROFILES is empty or unset — name at least one profile"
  else
    # Word-splitting a space-separated list is how a bash-3.2 script iterates one without
    # an array.
    # shellcheck disable=SC2086
    for name in $profiles; do
      run_profile "$name" || true
    done
  fi

  if [ "$failed" -ne 0 ]; then
    info "Record check failed."
    return 1
  fi
  info "Records OK."
}

# Executed, this file is the gate. Sourced, it is the library migrate-records.sh takes
# `canonicalise`, `protected_shape`, `marker_only_change`, `load_profile` and `section_body`
# from — so the migrator checks itself with the identical predicate the gate will judge its
# output by, rather than a second implementation that agrees with itself and disagrees here.
#
# A guard that wrongly decided "sourced" would make the gate exit 0 having checked nothing,
# which is the silent pass this file exists to refuse. It is pinned by every case in the
# suite that expects a non-zero exit, of which there are more than sixty.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
