#!/usr/bin/env bash
# shellcheck disable=SC2016 # fixture arguments intentionally contain unexpanded shell syntax
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
expect 'unspaced trailing colon-discard is a finding' 1 f2b.sh \
	'#!/usr/bin/env bash' \
	'grep -q pattern file ||:'
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
