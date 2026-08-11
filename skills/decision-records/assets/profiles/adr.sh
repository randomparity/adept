# shellcheck shell=bash
# Architecture Decision Records: docs/adr/NNNN-slug.md.
#
# Sourced by check-records.sh, never executed. It supplies the record-kind knowledge the engine
# deliberately lacks: which directory, which sections, what a Status means, and the two rules
# that are specific to an ADR — the H1 carries the record's number, and a supersession banner
# names a sibling record by path rather than free text.
#
# Newline-delimited strings rather than arrays: bash 3.2 is the macOS system shell, where
# "${arr[@]}" on an empty array is fatal under `set -u`.
#
# Every value below is read by check-records.sh after it sources this file, never within it;
# linted standalone, shellcheck cannot see that use.
# shellcheck disable=SC2034

RECORD_DIR="docs/adr"

# Substituted into engine messages that name the record kind: "a record is resolved once, by one
# artifact" reads wrong for an ADR.
RECORD_LABEL="ADR"

# docs/adr/README.md lives inside the record directory, so the deferral gate's "nothing else in
# here" rule cannot carry over unchanged. Exempt means "not a record", not "invisible":
# profile_check_directory below reads it.
RECORD_EXEMPT_FILES="README.md"

REQUIRED_SECTIONS="## Status
## Context
## Decision
## Consequences
## Considered & rejected"

# Every level-2 section the base ref had, except ## Status, rather than the required list. A
# fixed list protects only uniform records, and ADRs are not uniform — a pre-template record's
# extra sections would be freely guttable.
APPEND_ONLY_SECTIONS="*"

# Two patterns, not one: the loose prefix finds candidate banners so they can be counted and
# judged, and a malformed banner reports E-BANNER-FORM instead of falling through to E-STATUS.
BANNER_PREFIX='^> \*\*Superseded by'
BANNER_PATTERN='^> \*\*Superseded by \[[0-9]{4}\]\([0-9]{4}-[a-z0-9-]+\.md\)\*\* \([0-9]{4}-[0-9]{2}-[0-9]{2}\)$'
BANNER_HINT="> **Superseded by [NNNN](NNNN-slug.md)** (YYYY-MM-DD)"

# An ADR banner accompanies `Accepted (YYYY-MM-DD)`; it does not replace it. Every merged ADR
# here carries that line, and adding a banner to the same section is the sole edit the
# convention permits — a flag-free strict status check would fail exactly that edit.
BANNER_REPLACES_STATUS=no

# `Superseded` is accepted as a status word even though the banner is how a supersession is
# recorded: the profile names five status words including it, and the deployed reviewer prompt
# repeats that list verbatim, so an author following the instructions this repo ships writes it.
profile_check_status() {
  local file=$1 label=$2 body
  body=$(section_body "$file" "## Status" | grep -v '^>' | grep . | head -1)
  case "$body" in
  Proposed | Deferred) return 0 ;;
  esac
  if printf '%s' "$body" |
    grep -qE '^(Accepted|Rejected|Superseded) \([0-9]{4}-[0-9]{2}-[0-9]{2}\)$'; then
    return 0
  fi
  err "E-STATUS: $label: Status must be Proposed, Deferred, or Accepted/Rejected/Superseded (YYYY-MM-DD)"
}

# The H1 is the decision statement and it carries the record's number, which E-HEADING-REWRITTEN
# protects from rewording and this rule ties to the filename. Blob-local — decidable from the
# bytes and the path — so it runs in both passes, which is why the hook takes the logical path
# separately from the file it reads.
check_title_number() {
  local file=$1 label=$2 name num title
  name=${label##*/}
  num=${name%%-*}
  title=$(grep -m1 '^# ' "$file" || true)
  if ! printf '%s' "$title" | grep -qE "^# ${num} "; then
    err "E-TITLE-MISMATCH: $label: title '$title' does not begin '# $num ' — the H1's number is the record's number"
  fi
}

# A deferral banner names free text, which is unverifiable; an ADR banner names a sibling record
# by path, so it can be resolved. Not blob-local — it reads the sibling set — so it is a
# tree-pass rule, and it reports through err_full because a grandfathered record must not soften
# it: the likeliest record to acquire a banner here is the one pre-template ADR.
check_supersede_link() {
  local file=$1 label=$2 link
  link=$(section_body "$file" "## Status" |
    sed -n 's/^> \*\*Superseded by \[[0-9]\{4\}\](\([^)]*\)).*/\1/p' | head -1)
  [ -n "$link" ] || return 0
  if [ ! -f "$RECORD_DIR/$link" ]; then
    err_full "E-SUPERSEDE-DANGLING: $label: supersession banner names $RECORD_DIR/$link, which is not a record here"
  fi
}

profile_check_extra() {
  local file=$1 label=$2 pass=$3
  check_title_number "$file" "$label"
  [ "$pass" = tree ] || return 0
  check_supersede_link "$file" "$label"
}

# The status vocabulary migrate-records.sh case-corrects, split the way profile_check_status
# above splits it: three words that carry a date, two that stand alone. Read by the migrator
# only — the checker never sources these for anything.
MIGRATE_STATUS_DATED="Accepted Rejected Superseded"
MIGRATE_STATUS_BARE="Proposed Deferred"

# The marker transforms, in the order migrate-records.sh applies them. Called only by the
# migrator, which defines every function here; the checker sources this file and never runs
# it. An ADR carries no `target:` or `review-by:` field, but migrate_fields stays in the
# pipeline anyway: canonicalise treats such a line as a marker wherever it appears, and the
# migrator's output has to agree with canonicalise rather than with a record kind's habits.
profile_migrate_markers() {
  local file=$1 num=$2
  migrate_h1 "$num" <"$file" | migrate_headings | migrate_status | migrate_fields
}

# Once per profile, for a rule whose subject is not a record. Heuristic — a prose list of ADRs
# is not detected — so it warns and never fails. warn_full because no record's base-ref verdict
# has any bearing on a file that is not a record. The record list the engine passes is unused
# here; the hook takes it because a directory rule may need it.
profile_check_directory() {
  local readme="$RECORD_DIR/README.md"
  [ -f "$readme" ] || return 0
  [ "${ADR_INDEX_POLICY:-directory}" = required ] && return 0
  if grep -qE '^\|[[:space:]]*\[?[0-9]{4}' "$readme"; then
    warn_full "W-INDEX-TABLE: $readme: numbered record rows duplicate the directory index"
  fi
}
