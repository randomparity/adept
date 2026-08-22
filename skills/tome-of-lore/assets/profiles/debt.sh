# shellcheck shell=bash
# Deferral records: docs/debt/NNNN-slug.md.
#
# Sourced by check-records.sh, never executed. It supplies the record-kind knowledge the
# engine deliberately lacks: which directory, which sections, what a Status means, and the
# two fields that are specific to a deferral — `target:` and `review-by:`.
#
# Newline-delimited strings rather than arrays: bash 3.2 is the macOS system shell, where
# "${arr[@]}" on an empty array is fatal under `set -u`.
#
# Every value below is read by check-records.sh after it sources this file, never within it;
# linted standalone, shellcheck cannot see that use. SC2154 is the mirror of that blindness:
# read_section_out and read_section_status are assigned by read_section in check-records.sh,
# which sources this file, so a standalone lint sees only the reads.
# shellcheck disable=SC2034

RECORD_DIR="docs/debt"

# Substituted into engine messages that name the record kind. "deferral" keeps one of them
# — the "Checking N record(s)" info line — byte-identical to the pre-refactor original;
# E-COUNT-FLOOR also substitutes it but picked up the word for the first time doing so, and
# the two final summary lines ("Records OK." / "Record check failed.") never used it.
RECORD_LABEL="deferral"

# Nothing but records may sit in docs/debt.
RECORD_EXEMPT_FILES=""

REQUIRED_SECTIONS="## Status
## Concern
## Why deferred
## Non-regression boundary
## What would resolve it
## Provenance"

# Everything a merged record may not walk back. `## Status` is absent by design: it is the
# section a resolution banner has to change.
APPEND_ONLY_SECTIONS="## Concern
## Why deferred
## Non-regression boundary
## What would resolve it
## Provenance"

# Two patterns, not one: the loose prefix finds candidate banners so they can be counted and
# judged, and a malformed banner reports E-BANNER-FORM instead of falling through to E-STATUS.
BANNER_PREFIX='^> \*\*Resolved by'
BANNER_PATTERN='^> \*\*Resolved by .+\*\* \([0-9]{4}-[0-9]{2}-[0-9]{2}\)$'
BANNER_HINT="> **Resolved by <what>** (YYYY-MM-DD)"

# A deferral banner replaces `Open`; it does not accompany it.
BANNER_REPLACES_STATUS=yes

# Called only when no well-formed banner is present, per BANNER_REPLACES_STATUS=yes. Blob-local,
# so it runs in both passes and takes no notice of which one.
profile_check_status() {
  local file=$1 label=$2 status=0
  # This was the literal shape ADR 0032 was written for: `section_body … | grep -qi '^Open'`,
  # where a faulting awk emitted nothing, grep read empty input and exited 1, and the `if`
  # read that as an honest "Status is not Open". The read is lifted out and its status
  # captured; ${PIPESTATUS[@]} would not have served, since it does not survive a command
  # substitution and most sites in the sweep were assignments.
  read_section "$file" "## Status" || status=$?
  if [ "$status" -ne 0 ]; then
    # shellcheck disable=SC2154 # assigned by read_section in check-records.sh, which sources this
    err_full "E-STATUS-SCAN: $label: could not read the Status section (awk exit $read_section_status)"
    return 0
  fi
  # In-memory, so this pipeline's status is a legitimate verdict (ADR 0005 decision 1). It
  # carries no `head`, so 141 cannot reach it — ADR 0032 decision 3.
  # shellcheck disable=SC2154 # assigned by read_section in check-records.sh, which sources this
  if printf '%s\n' "$read_section_out" | grep -qi '^Open'; then
    return 0
  fi
  err "E-STATUS: $label: Status must be 'Open' or carry a '> **Resolved by ...**' banner"
}

# Provenance names the reviewed target as one path per `target:` line, and the lookup is
# scoped to that section — a `target:` line elsewhere in the record does not satisfy it.
#
# E-TARGET-MISSING is blob-local and runs in both passes: a legacy record whose target line is
# bulleted is non-conforming at base, which is the whole reason it is worth migrating.
# W-ORPHAN-TARGET resolves a path against the worktree, so it is a tree-pass rule, and it
# reports through warn_full because it is not part of conformance and must not be relabelled on
# a grandfathered record.
#
# The reader is lifted above the loop rather than left in the `< <(…)` it used to feed (ADR
# 0032 decision 6). Inside a process substitution its fault had nowhere to go, and an awk that
# could not open the file produced no target lines at all — which this rule then reported as
# E-TARGET-MISSING, a record faulted for lacking a line nothing ever looked for.
check_targets() {
  local file=$1 label=$2 pass=$3 target found=0 status=0 targets
  read_section "$file" "## Provenance" || status=$?
  if [ "$status" -ne 0 ]; then
    err_full "E-TARGET-SCAN: $label: could not read the Provenance section (awk exit $read_section_status)"
    return 0
  fi
  # In-memory; discard per ADR 0032 decision 2. sed exits 0 having printed nothing when the
  # section carries no target line, which is E-TARGET-MISSING's honest case below.
  targets=$(printf '%s\n' "$read_section_out" | sed -n 's/^target:[[:space:]]*//p') || :

  while IFS= read -r target; do
    [ -n "$target" ] || continue
    found=1
    if [ "$pass" = tree ] && [ ! -e "$target" ]; then
      warn_full "W-ORPHAN-TARGET: $label: target '$target' no longer exists — record may be orphaned"
    fi
  done <<<"$targets"

  if [ "$found" -eq 0 ]; then
    err "E-TARGET-MISSING: $label: Provenance needs at least one 'target: <path>' line"
  fi
}

# All three rules are blob-local — the date comes from the record, not the worktree — so they run
# in either pass. An open concern needs a date that bounds its re-evaluation. W-REVIEWBY-STALE
# reports through `warn`, which keeps a passed review date from making a record non-conforming.
#
# `resolved` is check_status's verdict on this same file, handed down by the engine. Only the
# staleness rule consults it: a re-evaluation date is a question about a live concern, and a
# resolution banner has already answered it, so warning past that date names a concern that is
# discharged and nothing but deleting the line could ever clear it. The form rule above the guard
# still applies — an unparseable date is a field no reader can act on either way, and leaving it
# uncaught on the records that resolve would make the rule depend on when it was looked at.
check_review_by() {
  local file=$1 label=$2 resolved=$3 review_by today review_int today_int status=0
  # Lifted per ADR 0032 decision 1. A faulted read yielded an empty review_by, which this rule
  # reported as E-REVIEWBY-MISSING — an open deferral faulted for lacking a date on a Status
  # section that was never read.
  read_section "$file" "## Status" || status=$?
  if [ "$status" -ne 0 ]; then
    err_full "E-REVIEWBY-SCAN: $label: could not read the Status section to find review-by (awk exit $read_section_status)"
    return 0
  fi
  # In-memory; discard per ADR 0032 decision 2.
  review_by=$(printf '%s\n' "$read_section_out" | sed -n 's/^review-by:[[:space:]]*//p' | head -1) || :
  if [ -z "$review_by" ]; then
    [ "$resolved" = yes ] && return 0
    err "E-REVIEWBY-MISSING: $label: open deferral needs review-by: YYYY-MM-DD in Status"
    return 0
  fi

  # `printf` over a shell variable, which ADR 0005 decision 1 places outside the scan rule and
  # ADR 0032 decision 4 confirms does not convert: there is no could-not-run case to report.
  if ! printf '%s' "$review_by" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    err "E-REVIEWBY-FORM: $label: review-by '$review_by' is not an ISO-8601 date (YYYY-MM-DD)"
    return 0
  fi

  [ "$resolved" = yes ] && return 0

  today=$(date -u +%F)
  review_int=$(date_to_int "$review_by")
  today_int=$(date_to_int "$today")
  if [ "$review_int" -lt "$today_int" ]; then
    warn "W-REVIEWBY-STALE: $label: review-by $review_by has passed — re-evaluate or resolve it"
  fi
}

profile_check_extra() {
  local file=$1 label=$2 pass=$3 resolved=$4
  check_targets "$file" "$label" "$pass"
  check_review_by "$file" "$label" "$resolved"
}

# The status vocabulary migrate-records.sh case-corrects. A deferral record's open state is
# one bare word and its resolved state is a banner, so no status word here carries a date —
# the dated list is empty, and `split("", ...)` yields nothing to try.
MIGRATE_STATUS_DATED=""
MIGRATE_STATUS_BARE="Open"

# The marker transforms, in the order migrate-records.sh applies them. Called only by the
# migrator, which defines every function here; the checker sources this file and never runs
# it. migrate_fields is the row that matters for this kind: a bulleted `- target:` fails
# E-TARGET-MISSING and sits inside the append-only ## Provenance, which is the whole reason
# a deferral record needs migrating and the reason the marker-only allowance exists.
profile_migrate_markers() {
  local file=$1 num=$2
  migrate_h1 "$num" <"$file" | migrate_headings | migrate_status | migrate_fields
}
