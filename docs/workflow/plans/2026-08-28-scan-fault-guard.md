# Scan-fault discard guard — implementation plan

Goal: ship the guard ADR 0047 decides — a structural check over the gate scripts that fails
any status-discard idiom lacking an inline `# scan-fault: deliberate — <reason>` pragma — and
annotate every deliberate discard the sweep finds.

Architecture: one new gate script `scripts/check-scan-fault-discards.sh` scans the
shell-source inventory (`scripts/list-shell-sources.sh --all -z`) minus test scripts, line by
line, with heredoc tracking and comment skipping; a line carrying a matched discard operator
without the pragma is a finding (exit 1), a guard fault is exit 2, clean is exit 0. Its suite
`scripts/check-scan-fault-discards-test.sh` drives it with `--files` over scratch fixtures.
The `commit-check` recipe gains the gate, so `just verify`, the pre-push hook, and CI run it.

Tech stack: bash 3.2 (macOS system bash floor), ERE via `[[ =~ ]]` with regexes in variables,
no arrays beyond the plain indexed kind, no `mapfile`/`readarray`/associative arrays.
Guardrails: `just verify` (records, lint, format-check, public-safety, shape-check,
ripgrep-config-check, plugin-check, version-check, test, actions-check, prek dry-run); `just
records` compares the `.github/scripts/` ↔ `skills/tome-of-lore/assets/` twins byte-for-byte.

## Global Constraints

- Bash 3.2 is the floor: no `mapfile`, no `readarray`, no associative arrays (CLAUDE.md).
- Shell is bash with tab indentation, `#!/usr/bin/env bash`, `set -euo pipefail` (CLAUDE.md).
- Regexes in variables: bash 3.2 mis-parses some quoted regex literals inside `[[ =~ ]]` (CLAUDE.md).
- `rg` invocations in gate scripts pass `--no-config` (CLAUDE.md).
- Every deliberate discard in the gate scripts carries the pragma `# scan-fault: deliberate — <reason>` with a non-empty reason (ADR 0047 decision 3).
- The guard follows the rule it enforces: it captures its own statuses and reports its own faults as exit 2 (ADR 0047 decision 6).
- The `.github/scripts/` ↔ `skills/tome-of-lore/assets/` twins stay byte-identical (Justfile records recipe).
- The guard's own messages never spell a matched operator literally (`|| true`, `|| :`, `|| continue`, `|| return 0`, `&& return 0`, `|| exit 0`, `&& exit 0`, `&& continue`), so they cannot match its own patterns.
- Plugin version bumps PATCH (2.13.0 → 2.13.1) per ADR 0022.
- Plans and specs name the checkout root as `$WORK`; absolute host paths are forbidden in committed files (check-public-safety.sh).

## Task 1 — Guard script `scripts/check-scan-fault-discards.sh`

Creates: `scripts/check-scan-fault-discards.sh`.

Interfaces: consumed by Task 4 (the `scan-fault-check` recipe calls it with no arguments).
Consumed by Task 2 (the suite calls it with `--files`). It consumes
`scripts/list-shell-sources.sh --all -z` (existing).

The full script:

```bash
#!/usr/bin/env bash
set -euo pipefail

# ADR 0047: a status-discard idiom in a gate script must carry an inline
# '# scan-fault: deliberate — <reason>' pragma, or the gate fails. The rule it
# enforces is ADR 0005's: a scan whose result feeds a verdict captures its own
# exit status and never collapses a fault into a verdict.
#
# The match set, per line, after heredoc and comment skipping:
#   - a trailing true- or colon-discard, a continue-discard, or a return-0 /
#     exit-0 discard on a command that is not a test and not a pure builtin;
#   - a command substitution inside a -n / -z test.
# Excluded by construction: [ ... ], [[ ... ]], (( ... )) and test commands;
# pure builtins with no pipeline and no command substitution; comment lines;
# heredoc bodies. The required capture form '|| status=$?' never matches.
#
# Exit 0 clean, 1 findings, 2 this script could not run (a source listing that
# failed, a file that could not be opened, a bad argument). This script is
# itself a scan whose result feeds a verdict, so it follows the rule it
# enforces: it captures its own statuses and reports its own faults.

usage() {
  cat <<'EOF'
usage: check-scan-fault-discards.sh [--files file...]

Scans the repository's gate scripts (the shell-source inventory minus test
scripts) for status-discard idioms without a '# scan-fault: deliberate — <reason>'
pragma. With --files, scans exactly the named files.
EOF
}

# Regexes in variables: bash 3.2 (macOS system bash) mis-parses some quoted regex
# literals inside [[ =~ ]].
heredoc_pat='<<[[:space:]]*(-?)(['"'"'"]?)([A-Za-z0-9_]+)'
comment_pat='^[[:space:]]*#'
pragma_pat='scan-fault:[[:space:]]deliberate[[:space:]]—[[:space:]]*[^[:space:]]'
test_preceding_pat='(\]|\)[[:space:]]*\))[[:space:]]*(\|\||&&)'
test_cmd_pat='^[[:space:]]*test[[:space:]]'
var_assign_pat='^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+'

# Pure builtins: their own status is never a scan verdict, and with no pipeline
# and no command substitution they cannot wrap a scanning stage.
# When a line contains a pipeline (|) or command substitution ($(), the builtin
# is not exempt because it may wrap a scanning command.
builtins='printf echo read : true false unset local export cd shift return exit break continue trap umask set eval source . declare typeset pwd type hash let wait getopts times ulimit alias bg fg jobs kill help compgen complete dirs disown enable history logout popd pushd readonly shopt suspend builtin exec caller bind fc mapfile readarray coproc'
# Discard shapes, named for the finding message. The name never spells the
# literal operator, so this script's own messages cannot match its own patterns.
trailing_shapes=(
  'trailing true-discard|\|\|[[:space:]]+true'
  'trailing colon-discard|\|\|[[:space:]]+:'
  'continue-discard|(\|\||&&)[[:space:]]+continue'
  'return-0-discard|(\|\||&&)[[:space:]]+return[[:space:]]+0'
  'exit-0-discard|(\|\||&&)[[:space:]]+exit[[:space:]]+0'
)

# The substitution-in-test shape matches both bracket styles [ ... ] and [[ ... ]]
# and test builtins, with or without double quotes around the substitution.
substitution_shapes=(
  'substitution-in-test|(\[\[?|test)[[:space:]]+-(n|z)[[:space:]]+"?\$\('
)

# First token after leading VAR=value assignments. Naive by design: a value
# containing spaces is mis-stripped, but such lines carry a pipeline or a
# substitution and are not builtin-exempt anyway.
command_word() {
  local rest=$1
  rest=${rest#"${rest%%[![:space:]]*}"}
  while [[ $rest =~ $var_assign_pat ]]; do
    rest=${rest#*"${BASH_REMATCH[0]}"}
    rest=${rest#"${rest%%[![:space:]]*}"}
  done
  printf '%s\n' "${rest%%[[:space:]]*}"
}

findings=0

scan_file() {
  local file=$1 line lineno=0 pending="" tabs="" first rest m word is_builtin line_before shape
  if ! { exec 3<"$file"; } 2>/dev/null; then
    printf 'scan-fault-guard: could not open %s\n' "$file" >&2
    exit 2
  fi
  while IFS= read -r line <&3; do
    lineno=$((lineno + 1))
    if [ -n "$pending" ]; then
      first=${pending%% *}
      if [ "$line" = "$first" ] ||
        { [ "${tabs%% *}" = 1 ] && [ "${line#"${line%%[!$'\t']*}"}" = "$first" ]; }; then
        case "$pending" in
        *' '*) pending=${pending#* } ;;
        *) pending="" ;;
        esac
        case "$tabs" in
        *' '*) tabs=${tabs#* } ;;
        *) tabs="" ;;
        esac
      fi
      continue
    fi
    [[ $line =~ $comment_pat ]] && continue
    rest=$line
    while [[ $rest =~ $heredoc_pat ]]; do
      m=${BASH_REMATCH[0]}
      pending="$pending ${BASH_REMATCH[3]}"
      if [ -n "${BASH_REMATCH[1]}" ]; then
        tabs="$tabs 1"
      else
        tabs="$tabs 0"
      fi
      rest=${rest#*"$m"}
    done
    pending=${pending# }
    tabs=${tabs# }
    [[ $line =~ $pragma_pat ]] && continue
    if [[ $line =~ $test_preceding_pat ]] || [[ $line =~ $test_cmd_pat ]]; then
      continue
    fi
    for shape in "${trailing_shapes[@]}"; do
      pat=${shape#*|}
      if [[ $line =~ $pat ]]; then
        word=$(command_word "$line")
        is_builtin=no
        case " $builtins " in
        *" $word "*) is_builtin=yes ;;
        esac
        line_before=${line%"${BASH_REMATCH[0]}"*}
        if [ "$is_builtin" = yes ] && [[ $line_before != *'|'* ]] && [[ $line != *'$('* ]]; then
          break
        fi
        printf 'scan-fault-guard: %s:%s: %s without a '\''# scan-fault: deliberate — <reason>'\'' pragma\n' \
          "$file" "$lineno" "${shape%%|*}" >&2
        findings=$((findings + 1))
        break
      fi
    done
    for shape in "${substitution_shapes[@]}"; do
      pat=${shape#*|}
      if [[ $line =~ $pat ]]; then
        printf 'scan-fault-guard: %s:%s: %s without a '\''# scan-fault: deliberate — <reason>'\'' pragma\n' \
          "$file" "$lineno" "${shape%%|*}" >&2
        findings=$((findings + 1))
        break
      fi
    done
  done
  exec 3<&-
}

if [ $# -gt 0 ] && [ "$1" = --files ]; then
  shift
  if [ $# -eq 0 ]; then
    printf 'scan-fault-guard: --files needs at least one file\n' >&2
    exit 2
  fi
  for file in "$@"; do
    scan_file "$file"
  done
  exit "$([ "$findings" -gt 0 ] && echo 1 || echo 0)"
fi

if [ $# -gt 0 ]; then
  usage >&2
  exit 2
fi

listing=$(mktemp) || {
  printf 'scan-fault-guard: could not create a scratch file\n' >&2
  exit 2
}
cleanup() {
  local status=$?
  if ! rm -f -- "$listing"; then
    printf 'scan-fault-guard: retained scratch path: %s\n' "$listing" >&2
    if ((status == 0)); then
      exit 2
    fi
  fi
  exit "$status"
}
trap cleanup EXIT
if ! ./scripts/list-shell-sources.sh --all -z >"$listing"; then
  printf 'scan-fault-guard: could not discover shell sources\n' >&2
  exit 2
fi
while IFS= read -r -d '' file; do
  case "$file" in
  tests/fixtures/* | */tests/fixtures/* | *-test.sh) continue ;;
  esac
  scan_file "$file"
done <"$listing"
exit "$([ "$findings" -gt 0 ] && echo 1 || echo 0)"
```

Verification:
- `bash -n scripts/check-scan-fault-discards.sh` — no syntax errors.
- `./scripts/check-scan-fault-discards.sh --files scripts/check-scan-fault-discards.sh` — exit 0 (the guard scans itself cleanly).
- `./scripts/check-scan-fault-discards.sh --files /nonexistent` — exit 2, message names the file.
- `./scripts/check-scan-fault-discards.sh --badflag` — exit 2, usage on stderr.

Acceptance: the script exists, parses, scans itself clean, and its fault paths exit 2.

## Task 2 — Guard suite `scripts/check-scan-fault-discards-test.sh`

Creates: `scripts/check-scan-fault-discards-test.sh`.

Interfaces: consumes Task 1's script via `--files` over scratch fixtures. Consumed by the
`test` recipe (discovers `scripts/*-test.sh`). This file is a `*-test.sh` name, so the guard
itself never scans it — its fixture heredocs may contain the idioms freely.

The suite (full script):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Suite for scripts/check-scan-fault-discards.sh (ADR 0047). Each case writes a
# scratch fixture and asserts the guard's exit status and message. The suite is
# a *-test.sh name, so the guard never scans it and its fixture heredocs may
# contain the idioms.

cd "$(dirname "${BASH_SOURCE[0]}")/.."
GUARD=${GUARD:-./scripts/check-scan-fault-discards.sh}
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/scan-fault-guard-test.XXXXXX") || exit 1
trap 'rm -rf -- "$SCRATCH"' EXIT

pass=0
fail=0

# expect <label> <expected-exit> <fixture-name> <content...>
# Writes the fixture, runs the guard with --files, asserts the exit status.
expect() {
  local label=$1 expected=$2 name=$3
  shift 3
  printf '%s\n' "$@" >"$SCRATCH/$name"
  set +e
  "$GUARD" --files "$SCRATCH/$name" >"$SCRATCH/out" 2>&1
  local status=$?
  set -e
  if [ "$status" -eq "$expected" ]; then
    pass=$((pass + 1))
    printf '  ok   %s\n' "$label"
  else
    fail=$((fail + 1))
    printf '  FAIL %s: expected exit %s, got %s\n' "$label" "$expected" "$status" >&2
    cat "$SCRATCH/out" >&2
  fi
}

# Each match shape is a finding (exit 1) naming the file and line.
expect 'trailing true-discard is a finding' 1 f1.sh \
  '#!/usr/bin/env bash' \
  'grep -q pattern file || true'
expect 'trailing colon-discard is a finding' 1 f2.sh \
  '#!/usr/bin/env bash' \
  'grep -q pattern file || :'
expect 'continue-discard is a finding' 1 f3.sh \
  '#!/usr/bin/env bash' \
  'grep -q pattern file || continue'
expect 'and-continue is a finding' 1 f4.sh \
  '#!/usr/bin/env bash' \
  'grep -q pattern file && continue'
expect 'return-0-discard is a finding' 1 f5.sh \
  '#!/usr/bin/env bash' \
  'grep -q pattern file || return 0'
expect 'and-return-0 is a finding' 1 f6.sh \
  '#!/usr/bin/env bash' \
  'grep -q pattern file && return 0'
expect 'exit-0-discard is a finding' 1 f7.sh \
  '#!/usr/bin/env bash' \
  'grep -q pattern file || exit 0'
expect 'and-exit-0 is a finding' 1 f8.sh \
  '#!/usr/bin/env bash' \
  'grep -q pattern file && exit 0'
expect 'substitution-in-test is a finding' 1 f9.sh \
  '#!/usr/bin/env bash' \
  'if [ -n "$(git ls-files)" ]; then :; fi'
expect 'substitution-in-z-test is a finding' 1 f10.sh \
  '#!/usr/bin/env bash' \
  'if [ -z "$(git rev-parse HEAD)" ]; then :; fi'
expect 'substitution-in-double-bracket-n is a finding' 1 f11.sh \
  '#!/usr/bin/env bash' \
  'if [[ -n $(git ls-files) ]]; then :; fi'
expect 'substitution-in-double-bracket-z is a finding' 1 f12.sh \
  '#!/usr/bin/env bash' \
  'if [[ -z "$(git rev-parse HEAD)" ]]; then :; fi'

# The pragma exempts the same lines.
expect 'pragma exempts true-discard' 0 p1.sh \
  '#!/usr/bin/env bash' \
  'grep -q pattern file || true # scan-fault: deliberate — in-memory input, ADR 0032 decision 4'
expect 'pragma exempts colon-discard' 0 p2.sh \
  '#!/usr/bin/env bash' \
  'grep -q pattern file || : # scan-fault: deliberate — in-memory input, ADR 0032 decision 4'
expect 'pragma exempts substitution' 0 p3.sh \
  '#!/usr/bin/env bash' \
  'if [ -n "$(git ls-files)" ]; then :; fi # scan-fault: deliberate — case-void guard'

# A pragma without a reason is not a pragma.
expect 'pragma without reason is a finding' 1 p4.sh \
  '#!/usr/bin/env bash' \
  'grep -q pattern file || true # scan-fault: deliberate'

# Exclusions: tests, builtins, the required capture form, comments, if-not.
expect 'test discard is not a finding' 0 e1.sh \
  '#!/usr/bin/env bash' \
  '[ -n "$x" ] || continue'
expect 'double-bracket test is not a finding' 0 e2.sh \
  '#!/usr/bin/env bash' \
  '[[ $x == y ]] && return 0'
expect 'arithmetic test is not a finding' 0 e3.sh \
  '#!/usr/bin/env bash' \
  '(( ${#a[@]} == 1 )) || exit 0'
expect 'test command is not a finding' 0 e4.sh \
  '#!/usr/bin/env bash' \
  'test -n "$x" || continue'
expect 'required capture form is not a finding' 0 e5.sh \
  '#!/usr/bin/env bash' \
  'status=0' \
  'git ls-files -- "$p" || status=$?'
expect 'read builtin is not a finding' 0 e6.sh \
  '#!/usr/bin/env bash' \
  'IFS= read -r line <&3 || :'
expect 'printf builtin is not a finding' 0 e7.sh \
  '#!/usr/bin/env bash' \
  'printf "x" >&2 || :'
expect 'comment line is not a finding' 0 e8.sh \
  '#!/usr/bin/env bash' \
  '# grep -q pattern file || true'
expect 'if-not shape is not a finding (residual)' 0 e9.sh \
  '#!/usr/bin/env bash' \
  'if ! grep -q pattern file; then return 0; fi'
expect 'return-1 propagation is not a finding' 0 e10.sh \
  '#!/usr/bin/env bash' \
  'load_profile x || return 1'

# Heredoc bodies are content, not code; the opener line is still checked.
expect 'heredoc body is not a finding' 0 h1.sh \
  '#!/usr/bin/env bash' \
  'cat >"$f" <<'"'"'STUB'"'"'' \
  'grep -q pattern file || true' \
  'STUB'
expect 'heredoc opener with discard is a finding' 1 h2.sh \
  '#!/usr/bin/env bash' \
  'cat >"$f" <<'"'"'STUB'"'"' || true'
expect 'heredoc example in comment does not open phantom heredoc' 1 h3.sh \
  '#!/usr/bin/env bash' \
  '# cat <<EOF' \
  'grep -q pattern file || true'

# Fault paths: unreadable file and bad argument exit 2.
set +e
"$GUARD" --files "$SCRATCH/no-such-file.sh" >"$SCRATCH/out" 2>&1
status=$?
set -e
if [ "$status" -eq 2 ] && grep -q 'could not open' "$SCRATCH/out"; then
  pass=$((pass + 1))
  printf '  ok   unreadable file exits 2 with a message\n'
else
  fail=$((fail + 1))
  printf '  FAIL unreadable file: expected exit 2 naming the file, got %s\n' "$status" >&2
  cat "$SCRATCH/out" >&2
fi
set +e
"$GUARD" --badflag >"$SCRATCH/out" 2>&1
status=$?
set -e
if [ "$status" -eq 2 ] && grep -q 'usage' "$SCRATCH/out"; then
  pass=$((pass + 1))
  printf '  ok   bad argument exits 2 with usage\n'
else
  fail=$((fail + 1))
  printf '  FAIL bad argument: expected exit 2 with usage, got %s\n' "$status" >&2
  cat "$SCRATCH/out" >&2
fi

printf 'scan-fault-guard-test: %s passed, %s failed\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
```

Verification:
- `just test scan-fault-discards` — all cases pass.
- `bash -n scripts/check-scan-fault-discards-test.sh` — no syntax errors.

Acceptance: every match shape, exclusion, pragma rule, and fault path has a case that bites;
the suite passes.

## Task 3 — Sweep: annotate every deliberate discard

Modifies (each site gains the pragma on its line; the `.github/scripts/` and
`skills/tome-of-lore/assets/` twins receive identical lines):

- `.github/scripts/check-records.sh` (and twin): lines 369, 395, 645, 728, 764, 801 get
  `# scan-fault: deliberate — in-memory input, ADR 0032 decision 4`; line 1317 gets
  `# scan-fault: deliberate — process-substitution listing; status has no channel (documented above)`; line 1530 gets
  `# scan-fault: deliberate — no base ref means nothing to have existed (fail-open, documented above)`; line 1642 gets
  `# scan-fault: deliberate — pure parameter expansion, not a scan`; line 1666 gets
  `# scan-fault: deliberate — one profile's failure must not hide another's findings`.
- `.github/scripts/migrate-records.sh` (and twin): lines 247, 257, 296, 317, 371, 423 get
  the in-memory pragma.
- `.github/scripts/profiles/adr.sh` (and twin): lines 71, 130 get the in-memory pragma.
- `.github/scripts/profiles/debt.sh` (and twin): lines 98, 134 get the in-memory pragma.
- `scripts/list-shell-sources.sh`: lines 192, 193 get
  `# scan-fault: deliberate — path-pattern test, not a scan`.
- `skills/quest-log/assets/profiles/github.sh`: line 68 gets
  `# scan-fault: deliberate — cleanup; the trap reports retention`; line 348 gets the
  in-memory pragma.
- `skills/quest-log/assets/cleared-dependencies.sh`: lines 257, 263, 270 get
  `# scan-fault: deliberate — best-effort restore; the primary error is already reported`; line 300 gets
  `# scan-fault: deliberate — in-memory jq predicate, ADR 0032 decision 4`.
- `skills/attunement/scripts/detect-host-architecture`: line 71 gets
  `# scan-fault: deliberate — probe; absence is ordinary`.
- `skills/bounty/scripts/create-verified-issue.sh`: line 140 gets the in-memory pragma.

Method: run the guard against the inventory (`./scripts/check-scan-fault-discards.sh`), read
each finding, verify the site is a deliberate exception from ADR 0047's Context classes, and
add the pragma. A site that is not a deliberate exception is a defect: fix it (capture the
status) rather than annotating it.

Verification: `./scripts/check-scan-fault-discards.sh` exits 0; `just records` passes
(twins byte-identical).

Acceptance: the guard is clean on the inventory; every deliberate discard carries a pragma
with a reason; no site was annotated that is not a deliberate exception.

## Task 4 — Wiring and version

Modifies: `Justfile`, `.claude-plugin/plugin.json`.

- `Justfile`: add after `public-safety`:

```
scan-fault-check:
  ./scripts/check-scan-fault-discards.sh
```

  and change `commit-check: lint format-check public-safety` to
  `commit-check: lint format-check public-safety scan-fault-check`.
- `.claude-plugin/plugin.json`: `"version": "2.13.0"` → `"2.13.1"`.

Verification: `just commit-check` passes; `just verify` passes (full suite, including the
new suite under `test` and the new gate under `commit-check`); `just version-check` passes.

Acceptance: the gate runs on every commit, push, and CI leg; the version is bumped.

## Self-review against the spec

- Guard exists and runs on every commit → Task 4 (commit-check wiring).
- Match set, exclusions, pragma grammar, heredoc tracking, exit statuses → Task 2 cases
  (one per shape, per exclusion, per fault path; heredoc body and opener cases).
- Sweep annotates every deliberate discard → Task 3, verified by the guard's own exit 0 and
  `just records`.
- The guard follows the rule → Task 1's self-scan verification; the guard's own source
  carries no unannotated discard.
- Verification: `just verify` → Task 4.
- ADR 0047's residuals are pinned by Task 2's e9 (if-not) and e10 (return-1) cases — the
  suite asserts the excluded shapes stay excluded, so a future change to the match set is a
  deliberate, tested change.