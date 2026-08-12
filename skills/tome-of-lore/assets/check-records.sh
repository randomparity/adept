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
protected_shape() {
  canonicalise "$1" | awk '
    /^## / { in_status = ($0 == "## status"); print; next }
    !in_status { print }
  '
}

# The marker-only allowance. Migration edits merged records, which E-REWRITE exists to
# forbid, so rather than a bypass flag the three rules fire only when a change is not
# marker-only — and "marker-only" is `canonicalise`, the same definition migrate-records.sh
# produces its output against and checks itself with before writing.
#
# The permission is a property of the diff, which the author cannot fake: there is no
# one-time escape hatch to forget to remove, and no way to smuggle a word of prose, a
# re-indented sub-bullet or a reworded heading past it.
marker_only_change() {
  [ "$(protected_shape "$1")" = "$(protected_shape "$2")" ]
}

check_sections() {
  local file=$1 label=$2 section body grep_status
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
    body=$(section_body "$file" "$section" | tr -d '[:space:]')
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

# Tracked in the index. Checked alongside the filesystem because the two can disagree,
# and each gap is a way to lose a record: one removed from git but left on disk as an
# untracked file passes a filesystem test while being gone from the repository, and one
# deleted from the working tree passes a git test while being gone from the checkout.
# The index rather than HEAD, so a staged deletion is caught before it is committed.
tracked_in_index() {
  local path=$1
  git ls-files --error-unmatch -- "$path" >/dev/null 2>&1
}

still_a_record() {
  local path=$1
  present_as_real_file "$path" && tracked_in_index "$path"
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
# one vanished base path. A temp-file failure returns 1 and lets E-GONE speak instead.
#
# Candidates come from `records`, which collect_records builds only after reporting
# E-RECORD-SYMLINK and skipping every symlink, so no candidate can be a link. A `[ ! -L ]` test
# here would be a guard that cannot fire — a false guarantee, by the same argument date_to_int
# makes about its own missing invalid-input branch.
renumbered_elsewhere() {
  local base=$1 path=$2 blob_canon candidate tmp
  tmp=$(mktemp) || return 1
  if ! git cat-file blob "${base}:${path}" >"$tmp" 2>/dev/null; then
    rm -f "$tmp"
    return 1
  fi
  blob_canon=$(canonicalise "$tmp")
  rm -f "$tmp"
  [ -n "$records" ] || return 1

  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    [ -f "$candidate" ] || continue
    tracked_in_index "$candidate" || continue
    git cat-file -e "${base}:${candidate}" 2>/dev/null && continue
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
      return 0
    fi
  done <<<"$records"
  return 1
}

records_in_ref() {
  local ref=$1 raw
  # The checker's coded ::error:: lines are its interface; a bare `fatal:` from git is not,
  # so a bad ref's stderr is suppressed here rather than at each call site.
  raw=$(git ls-tree -r --name-only "$ref" -- "$RECORD_DIR" 2>/dev/null) || return 1
  printf '%s' "$raw" | grep -E "$RECORD_RE" || true
}

# Heading lines are the one region section_body skips outright — it matches a heading only to
# recognize where a section starts, never to emit the heading itself — so no append-only rule
# has ever examined one, and for an ADR the H1 *is* the decision statement. Every heading line
# present in the base-ref blob must still be present, verbatim, somewhere in the tree version.
check_headings_intact() {
  local tmp=$1 path=$2 heading grep_status
  # Fed by a process substitution on `done`, so err_full runs in the current shell rather than
  # a piped subshell, where the assignment to `failed` would be discarded.
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
  done < <(grep -E '^#+ ' "$tmp" || true)
}

# The lines between the H1 and the first `## ` belong to no section at all, so section_body
# never reaches them either — it is where a pre-template record keeps its metadata bullets.
check_preamble_intact() {
  local tmp=$1 path=$2 removed
  removed=$(diff <(preamble "$tmp") <(preamble "$path") | grep -c '^<' || true)
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
  local tmp=$1 path=$2 section removed
  # "*" means every level-2 heading the base ref had except ## Status. Level 2 only, matching
  # section_body's `^## ` terminator: a deeper heading is body content inside its enclosing
  # section, and enumerating one as a section of its own would produce overlapping bodies and
  # silently redefine what append-only means.
  local sections=$APPEND_ONLY_SECTIONS
  if [ "$sections" = "*" ]; then
    sections=$(grep -E '^## ' "$tmp" | grep -vxF '## Status' || true)
  fi

  while IFS= read -r section; do
    [ -n "$section" ] || continue
    removed=$(diff <(section_body "$tmp" "$section") <(section_body "$path" "$section") | grep -c '^<' || true)
    if [ "$removed" -gt 0 ]; then
      err_full "E-REWRITE: $path drops $removed line(s) from '$section' that the base ref had — a merged record is append-only there; resolve it with a banner rather than rewriting it"
    fi
  done <<<"$sections"
}

check_not_rewritten() {
  local base=$1 path=$2 blob tmp
  blob=$(git cat-file blob "${base}:${path}" 2>/dev/null) || return 0
  tmp=$(mktemp) || return 0
  printf '%s\n' "$blob" >"$tmp"

  # The one permitted class of edit to a merged record's protected regions. Checked before
  # any of the three rules rather than inside each, so all three answer to one predicate and
  # a change is either marker-only or it is not.
  if marker_only_change "$tmp" "$path"; then
    rm -f "$tmp"
    return 0
  fi

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
  local base=$1 path=$2 blob tmp saved_mode
  base_verdict=absent
  blob=$(git cat-file blob "${base}:${path}" 2>/dev/null) || return 0
  if ! tmp=$(mktemp); then
    err "E-TMPFILE: cannot create a temp file — cannot determine the base-ref shape of $path"
    return 0
  fi
  printf '%s\n' "$blob" >"$tmp"

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
  local base=$1 tree record renumbered_to="" used_renumber_targets=""
  if ! tree=$(records_in_ref "$base"); then
    err "E-BASE-TREE: could not read $RECORD_DIR at $base — cannot check for removed records"
    return 0
  fi

  while IFS= read -r record; do
    [ -n "$record" ] || continue
    if [ -L "$record" ]; then
      err "E-GONE-SYMLINK: $record was replaced by a symlink — a record is a real file, and a link is not one"
    elif present_as_real_file "$record" && tracked_in_index "$record"; then
      check_not_rewritten "$base" "$record"
    elif ! still_a_record "$record"; then
      renumbered_to=""
      if renumbered_elsewhere "$base" "$record"; then
        info "note: $record was renumbered to $renumbered_to (content unchanged)"
      else
        err "E-GONE: $record is no longer a record at that path (deleted, moved, untracked, or renamed with its content changed) — resolve records in place with a '> **Resolved by ...**' banner"
      fi
    fi
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
gate_existed_at() {
  local base=$1 rel name

  rel=$(repo_relative "$SELF_DIR")
  if [ -n "$rel" ]; then
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      git cat-file -e "${base}:${rel}/${name}" 2>/dev/null && return 0
    done < <(gate_known_basenames)
  fi

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    git grep --no-color -qF "$name" "$base" -- .github/workflows 2>/dev/null && return 0
  done < <(gate_known_basenames)
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
  local base=$1 self successor successor_path gate_path_count=0
  while IFS= read -r self; do
    [ -n "$self" ] || continue
    git cat-file -e "${base}:${self}" 2>/dev/null || continue
    gate_path_count=$((gate_path_count + 1))
    if [ -L "$self" ]; then
      err "E-GATE-SYMLINK: $self is a symlink — a gate file swapped for a link no longer contains the gate"
    elif ! still_a_record "$self"; then
      successor=$(predecessor_successor "$self") || successor=""
      successor_path=""
      [ -n "$successor" ] && successor_path=$(gate_predecessor_path "$successor")
      if [ -n "$successor_path" ] && [ -f "$successor_path" ] && [ ! -L "$successor_path" ] &&
        tracked_in_index "$successor_path"; then
        info "note: $self was renamed to $successor_path"
      else
        err "E-GATE-GONE: $self was deleted or untracked — the gate cannot be removed by the change it gates"
      fi
    fi
  done < <(gate_paths "$base" | sort -u)

  # An empty protected set means self-protection is off. That is the correct state for the
  # PR that installs the gate in a new repo, and a silent failure for one that renamed it —
  # and the two must be separated by a predicate that is not the emptiness test restated.
  if [ "$gate_path_count" -eq 0 ]; then
    if gate_existed_at "$base"; then
      err "E-GATE-EMPTY-SET: no gate file from the base ref is protected — a rename must declare its predecessors in GATE_PREDECESSORS"
    else
      info "I-GATE-BOOTSTRAP: no gate existed at $base — this is the change installing it"
    fi
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
# Emits paths only. It must not call err: callers read it through a process substitution,
# where an err would set failed=1 in a subshell and lose it — the same shape that once let a
# stray file print an error and still exit 0. The caller checks locatability itself.
gate_paths() {
  local base=$1 rel profile old key new needle
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
  while IFS= read -r profile; do
    [ -n "$profile" ] || continue
    rel=$(repo_relative "$SELF_DIR/profiles/${profile##*/}")
    [ -n "$rel" ] && printf '%s\n' "$rel"
  done < <(git ls-tree -r --name-only "$base" -- "$(repo_relative "$SELF_DIR/profiles")" 2>/dev/null || true)

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
  # `sort -u` at the end: a workflow naming more than one needle (this repo's own workflow
  # names both check-debt.sh and check-debt-test.sh in the same PR) would otherwise be
  # emitted once per match, and check_gate_files would then report the same path's finding
  # more than once.
  {
    printf '%s\n' "$(basename "$SELF_FILE")"
    while IFS= read -r old; do
      [ -n "$old" ] || continue
      key=${old%%$'\t'*}
      new=${old#*$'\t'}
      key=${key##*/}
      new=${new##*/}
      case "$key" in
      *.sh) [ "$key" = "$new" ] || printf '%s\n' "$key" ;;
      esac
    done <<<"$GATE_PREDECESSORS"
  } | while IFS= read -r needle; do
    git grep --no-color -lF "$needle" "$base" -- .github/workflows 2>/dev/null |
      sed 's/^[^:]*://' || true
  done | sort -u
}

require_repo_root() {
  local root
  if ! root=$(git rev-parse --show-toplevel 2>/dev/null); then
    err "E-NOT-REPO: not inside a git repository — run this from the repository root"
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

# Whether the directory existed at the base ref. An absent-from-both-refs directory is a
# misconfiguration; one that existed at base and is gone now is erasure, and must keep
# reporting E-GONE per record — `no_dir` deletes docs/debt wholesale and asserts exactly that.
# With no base ref, absence is not an error: `no_records_no_base` removes the only record,
# which leaves git deleting the emptied directory, and expects exit 0.
dir_in_ref() {
  local ref=$1 dir=$2
  [ -n "$ref" ] || return 0
  git rev-parse --verify --quiet "${ref}^{commit}" >/dev/null || return 0
  [ -n "$(git ls-tree -r --name-only "$ref" -- "$dir" 2>/dev/null)" ]
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

  local records="" record_count base_records="" base_count
  if [ ! -d "$RECORD_DIR" ] && ! dir_in_ref "${BASE_SHA:-}" "$RECORD_DIR"; then
    err "E-PROFILE-DIR-MISSING: profile '$name' is enabled but $RECORD_DIR exists at neither the base ref nor the tree"
    return 1
  fi

  collect_records
  record_count=$(count_lines "$records")

  # base_valid comes from main through the same dynamic scoping as `records`. A BASE_SHA
  # that failed check_base_ref is not retried here — that would report the same bad ref
  # under E-BASE-TREE instead of just E-BASE-REF, once per profile.
  if [ -n "${BASE_SHA:-}" ] && [ "$base_valid" -eq 1 ]; then
    check_no_disappearances "${BASE_SHA}"
    base_records=$(records_in_ref "${BASE_SHA}" || true)
    base_count=$(count_lines "$base_records")
    if [ "$base_count" -gt 0 ] && [ "$record_count" -eq 0 ]; then
      err "E-COUNT-FLOOR: $BASE_SHA held $base_count $RECORD_LABEL record(s) but none are readable now — refusing to report a clean run over nothing"
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
# interaction; `not_a_repo` requires E-NOT-REPO to win.
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
