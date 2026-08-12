#!/usr/bin/env bash
# Bring a merged record's markers into the current form, mechanically.
#
# Run locally, never in CI. Dry-run by default; --write applies. It requires a clean
# worktree, touches only files under the active profile's RECORD_DIR, and never commits —
# the result is meant to land as one reviewable commit that a human wrote the message for.
#
# Every transform is **line-local**. It rewrites markers and the case around text without
# moving text between lines or regions, and without introducing text the line did not carry:
#
#   # 1. Title, # ADR N: Title    ->  # 0001 — Title   (number from the filename)
#   ## Status:, ## status         ->  ## Status
#   accepted (2026-07-19)         ->  Accepted (2026-07-19)          (case only)
#   accepted 2026-07-19           ->  Accepted (2026-07-19)          (case and parentheses)
#   - target: path, "  review-by:" ->  target: path, review-by:      (at column one)
#
# It will not invent content. A bare ACCEPTED with no date is reported, not dated: the date
# is not on the line, and the only other source is a separate metadata line, which lifting
# would be a relocation. A missing or empty section is reported for human authoring, never
# stubbed — a placeholder trades a warning for an E-SECTION-EMPTY error. A malformed
# resolution banner is reported rather than guessed, because the canonical form needs a date
# that is not derivable from the text.
#
# It will not relocate content either. A pre-template record that keeps its status as a
# metadata bullet above the first heading keeps it: turning that into a section moves a line
# from outside every section into a new one. Such a record has its title fixed and nothing
# else, and stays grandfathered afterwards.
#
# Provenance is the commit, not a label in the record. A `migrated:` line would be new
# content, would make the non-marker comparison differ, and would fire E-REWRITE — a tool
# promising markers-only cannot add content to announce itself. The summary prints the
# `Migrated-markers:` trailer lines to put on the commit instead.
#
# One of the six gate assets an adopting repo copies. It never runs in CI, but
# check-records-test.sh — which the workflow runs first — resolves it beside itself because the
# self-check cases exercise the checker's allowance function.

set -euo pipefail

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

# The gate itself, sourced rather than copied. `canonicalise` is the single definition of
# what counts as a marker and `marker_only_change` is the predicate the gate will judge this
# output by; re-implementing either here would produce a self-check that passes against its
# own idea of a marker and a gate that rejects the result anyway.
# SC1091 is disabled rather than resolved: following the source needs `shellcheck -x`, and
# the guardrail this repo and the adoption instructions both name runs plain `shellcheck`.
# shellcheck source=check-records.sh disable=SC1091
. "$SELF_DIR/check-records.sh"

WRITE=no
migrate_failed=0
records_seen=0
records_rewritten=0
records_left=0
migrated_list=""
left_this_record=0

usage() {
  info "usage: migrate-records.sh [--write]"
  info ""
  info "Rewrites legacy markers in the records of every profile named in RECORD_PROFILES."
  info "Prints what it would change and what it leaves for a human; --write applies it."
}

abort() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

report_failure() {
  printf 'error: %s\n' "$1" >&2
  migrate_failed=1
}

leftover() {
  info "  left for a human: $1"
  left_this_record=1
}

# A clean worktree is not tidiness. The gate compares the tree against the base ref, and the
# self-check below compares this output against the file on disk; those are the same
# comparison only while nothing else in the worktree has moved. It is also what keeps the
# migration reviewable as a commit of its own.
require_clean_worktree() {
  local dirty
  dirty=$(git status --porcelain) || abort "E-NOT-REPO: cannot read the working tree state"
  if [ -n "$dirty" ]; then
    abort "E-DIRTY: the worktree has uncommitted changes — commit or stash them first, so this migration lands as its own reviewable commit"
  fi
}

# load_profile is the engine's, so the profile is resolved and validated exactly as the gate
# resolves it. Only the migration hook is extra, and it is unset first for the same reason
# the engine unsets its own optional hooks: one profile's hook must not serve the next name
# in RECORD_PROFILES.
load_migrate_profile() {
  local name=$1
  unset -f profile_migrate_markers
  load_profile "$name" || return 1
  if [ "$(type -t profile_migrate_markers)" != function ]; then
    report_failure "E-PROFILE-INCOMPLETE: profile '$name' defines no profile_migrate_markers hook"
    return 1
  fi
}

# The first `# ` line, whose number becomes the filename's and whose separator becomes the em
# dash every conforming record uses. The prefix pattern is canonicalise's, with the `adr`
# letters case-folded: a shape canonicalise does not recognise as a numbered prefix must not
# be rewritten here either, or the self-check would reject this tool's own output.
#
# An H1 carrying no number at all is left alone. Prepending one would introduce text the line
# did not carry, and canonicalise sees that difference — the rule is a mechanism, not a
# promise.
migrate_h1() {
  LC_ALL=C awk -v num="$1" '
    /^# / && !seen {
      seen = 1
      rest = substr($0, 3)
      if (sub(/^([Aa][Dd][Rr] )?[0-9]+[[:space:]]*(\.|:|-|—)[[:space:]]*/, "", rest)) {
        print "# " num " — " rest
        next
      }
    }
    { print }
  '
}

# A heading whose text matches a required section case-insensitively, with a trailing colon
# and any spacing around the hashes ignored, is spelled the way the profile spells it. The
# probe is normalised exactly as canonicalise normalises a heading, so every heading this
# rewrites is one canonicalise already considers unchanged.
#
# REQUIRED_SECTIONS is profile-supplied and newline-delimited, with no fixed line count (the
# ADR profile carries five entries, the debt profile six), so it cannot pass through a single
# -v assignment: a multi-line -v value is a GNU-awk-only extension that BSD/one-true awk
# (macOS) rejects outright. It is fed through a process-substitution file instead and read a
# line at a time with getline, which scales to any number of entries.
migrate_headings() {
  LC_ALL=C awk -v wantedfile=<(printf '%s\n' "$REQUIRED_SECTIONS") '
    BEGIN {
      while ((getline line < wantedfile) > 0) if (line != "") key[tolower(line)] = line
      close(wantedfile)
    }
    /^#/ {
      match($0, /^#+/)
      hashes = substr($0, 1, RLENGTH)
      rest = substr($0, RLENGTH + 1)
      sub(/^[[:space:]]*/, "", rest)
      sub(/[[:space:]]*:?[[:space:]]*$/, "", rest)
      probe = hashes " " tolower(rest)
      if (probe in key) { print key[probe]; next }
    }
    { print }
  '
}

# The status value: the first line of the `## Status` body that is neither blank nor a
# banner. A word from the profile's bare vocabulary is case-corrected; a word from its dated
# vocabulary is case-corrected and its date parenthesised, but only when a date is already on
# the line. Anything else is passed through untouched for report_status_leftover to name.
#
# The date pattern is spelled out digit by digit rather than with an interval: the macOS
# system awk this file promises to run under does not support {n} in every version shipped.
migrate_status() {
  LC_ALL=C awk -v dated="$MIGRATE_STATUS_DATED" -v bare="$MIGRATE_STATUS_BARE" '
    function canonical_status(line,   i, probe, rest, w) {
      probe = tolower(line)
      for (i = 1; i <= nb; i++) if (probe == tolower(B[i])) return B[i]
      for (i = 1; i <= nd; i++) {
        w = tolower(D[i])
        if (substr(probe, 1, length(w)) != w) continue
        rest = substr(line, length(w) + 1)
        sub(/^[[:space:]]+/, "", rest)
        sub(/^\(/, "", rest)
        sub(/\)$/, "", rest)
        if (rest ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return D[i] " (" rest ")"
      }
      return line
    }
    BEGIN { nd = split(dated, D, " "); nb = split(bare, B, " ") }
    /^## / { in_status = ($0 == "## Status"); print; next }
    in_status && !done && $0 !~ /^>/ && $0 ~ /[^[:space:]]/ {
      done = 1
      print canonical_status($0)
      next
    }
    { print }
  '
}

# The indent and one bullet marker in front of a `target:` or `review-by:` line, and nowhere
# else. The pattern is canonicalise's, verbatim: a rule applied file-wide instead would make
# any re-indentation compare equal, which is both a hole in the gate and a bug this
# function's own self-check could no longer see.
migrate_fields() {
  LC_ALL=C awk '
    /^[[:space:]]*(- )?(target|review-by):/ { sub(/^[[:space:]]*(- )?/, "") }
    { print }
  '
}

# The status value the profile's own check reads: banners excluded, first non-blank line.
status_line_of() {
  section_body "$1" "## Status" | grep -v '^>' | grep . | head -1
}

status_is_canonical() {
  local line=$1 word
  # Word-splitting a space-separated list is how a bash-3.2 script iterates one.
  # shellcheck disable=SC2086
  for word in $MIGRATE_STATUS_BARE; do
    if [ "$line" = "$word" ]; then return 0; fi
  done
  # shellcheck disable=SC2086
  for word in $MIGRATE_STATUS_DATED; do
    if printf '%s' "$line" | grep -qE "^${word} \([0-9]{4}-[0-9]{2}-[0-9]{2}\)$"; then
      return 0
    fi
  done
  return 1
}

# Routed the way check_status routes it, so the report names one thing per record rather
# than a malformed banner plus whatever the line beneath it happens to be. A well-formed
# banner on a kind that replaces the status with it leaves no status word to judge.
report_status_leftover() {
  local file=$1 label=$2 status banner
  banner=$(section_body "$file" "## Status" | grep "$BANNER_PREFIX" || true)
  if [ -n "$banner" ]; then
    if ! printf '%s' "$banner" | grep -qE "$BANNER_PATTERN"; then
      leftover "$label: the banner must read '$BANNER_HINT', and its date is not derivable from the text"
      return 0
    fi
    if [ "$BANNER_REPLACES_STATUS" = yes ]; then
      return 0
    fi
  fi
  status=$(status_line_of "$file")
  if [ -n "$status" ] && ! status_is_canonical "$status"; then
    leftover "$label: status '$status' is not a form the gate accepts, and no date can be taken from that line"
  fi
}

# What migration cannot finish. A missing or empty section needs prose, and a placeholder
# would trade a warning for an E-SECTION-EMPTY error, so it is named rather than stubbed.
report_leftovers() {
  local file=$1 label=$2 section body grep_status
  while IFS= read -r section; do
    [ -n "$section" ] || continue
    # grep exits 1 for "no match" and 2 or more for a fault it hit while
    # scanning -- an unreadable file, a bad encoding. Negating a bare `if`
    # reads a fault the same as "missing", a false leftover report on a scan
    # that never actually completed. Branch on the captured status instead.
    grep_status=0
    grep -qxF "$section" "$file" || grep_status=$?
    case $grep_status in
    0) ;;
    1)
      leftover "$label: no '$section' section — write one; the migrator does not author content, and it does not move a metadata line into a section either"
      continue
      ;;
    *)
      report_failure "E-SECTION-SCAN: $file: could not scan for section '$section' (grep exit $grep_status)"
      continue
      ;;
    esac
    body=$(section_body "$file" "$section" | tr -d '[:space:]')
    if [ -z "$body" ]; then
      leftover "$label: '$section' has no body — a heading with no content is not a record"
    fi
  done <<<"$REQUIRED_SECTIONS"

  report_status_leftover "$file" "$label"
}

show_rewrites() {
  local before=$1 after=$2 line
  while IFS= read -r line; do
    info "    $line"
  done < <(diff "$before" "$after" | grep -E '^[<>] ' || true)
}

# One record: transform, self-check, report, and write only if asked.
#
# The self-check is marker_only_change — the gate's own allowance, not a separate notion of
# what a safe edit is. It answers the only question worth asking before writing: will the
# gate reject this? Scoped, as the gate is, to the regions the gate protects, which excludes
# the `## Status` body — comparing that would abort on this tool's own status transform, a
# change no rule here examines.
migrate_record() {
  local path=$1 num tmp changed
  num=${path##*/}
  num=${num%%-*}
  records_seen=$((records_seen + 1))
  left_this_record=0

  tmp=$(mktemp) || abort "E-TMPFILE: cannot create a temp file"
  profile_migrate_markers "$path" "$num" >"$tmp"

  if ! marker_only_change "$path" "$tmp"; then
    rm -f "$tmp"
    report_failure "E-SELF-CHECK: $path: the transform changed a region the gate protects — refusing to write"
    return 0
  fi

  changed=$(diff "$path" "$tmp" | grep -c '^<' || true)
  info "$path: $changed marker line(s) rewritten"
  show_rewrites "$path" "$tmp"
  if [ "$changed" -gt 0 ]; then
    records_rewritten=$((records_rewritten + 1))
    migrated_list="${migrated_list}${path}
"
    if [ "$WRITE" = yes ]; then
      cat "$tmp" >"$path"
    fi
  fi

  report_leftovers "$tmp" "$path"
  rm -f "$tmp"
  records_left=$((records_left + left_this_record))
}

migrate_profile() {
  local name=$1 record
  load_migrate_profile "$name" || return 1
  if [ ! -d "$RECORD_DIR" ]; then
    report_failure "E-PROFILE-DIR-MISSING: profile '$name' is enabled but $RECORD_DIR does not exist"
    return 1
  fi

  info ""
  info "-- $RECORD_DIR --"
  # Regular files at the top level only, filtered by the same record pattern the gate uses,
  # so a symlink or a stray file is never rewritten. Read through a process substitution:
  # a pipe would put every counter above in a subshell that is then discarded.
  while IFS= read -r record; do
    [ -n "$record" ] || continue
    migrate_record "$record"
  done < <(find "$RECORD_DIR" -mindepth 1 -maxdepth 1 -type f | sort | grep -E "$RECORD_RE" || true)
}

summarise() {
  local rec
  info ""
  info "$records_seen record(s) examined, $records_rewritten rewritten, $records_left with something left for a human."
  if [ "$WRITE" != yes ]; then
    info "Dry run — nothing written. Re-run with --write to apply."
    return 0
  fi
  [ -n "$migrated_list" ] || return 0
  info ""
  info "Commit the result on its own, with one trailer per record touched:"
  while IFS= read -r rec; do
    [ -n "$rec" ] || continue
    info "Migrated-markers: $rec"
  done <<<"$migrated_list"
}

parse_args() {
  local arg
  for arg in "$@"; do
    case "$arg" in
    --write) WRITE=yes ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) abort "E-USAGE: unknown argument '$arg' — usage: migrate-records.sh [--write]" ;;
    esac
  done
}

migrate_main() {
  local root name
  parse_args "$@"

  root=$(git rev-parse --show-toplevel 2>/dev/null) || abort "E-NOT-REPO: not inside a git repository — run this from the repository root"
  cd "$root"
  require_clean_worktree

  if [ -z "${RECORD_PROFILES:-}" ]; then
    abort "E-PROFILE-NONE: RECORD_PROFILES is empty or unset — name at least one profile"
  fi
  # shellcheck disable=SC2086
  for name in ${RECORD_PROFILES}; do
    migrate_profile "$name" || migrate_failed=1
  done

  summarise
  [ "$migrate_failed" -eq 0 ]
}

migrate_main "$@"
