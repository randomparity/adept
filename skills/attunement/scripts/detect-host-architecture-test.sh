#!/usr/bin/env bash
set -euo pipefail

# Behaviour suite for the one-sided records appended by
# skills/attunement/scripts/detect-host-architecture: HOST_SHELL,
# HOST_USERLAND, and HOST_TOOL_STEERING after the status line.
#
# The architecture payload itself -- every status across degraded and hostile
# input cases -- is covered by tests/fixtures/attunement/architecture-
# awareness-test.sh, which also pins the fail-open markers these records emit
# when the observation tools are missing entirely. What this suite adds is
# what only a live, fully provisioned invocation can answer: that the invoking
# shell is observed as the invoking shell (and never from $SHELL), that
# steering variable NAMES are captured while their VALUES never reach stdout,
# and that a clean environment records `none`.
#
# ripgrep reads RIPGREP_CONFIG_PATH ahead of its own arguments; this suite
# asserts on that variable's presence in detector output, so a personal
# ripgreprc must not steer the assertions themselves.
unset RIPGREP_CONFIG_PATH

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=SCRIPTDIR/../../../scripts/test-fixture-helpers.sh
. "$ROOT/scripts/test-fixture-helpers.sh"

fixture_init detect-host-architecture-test

DETECTOR="$ROOT/skills/attunement/scripts/detect-host-architecture"

[[ -x "$DETECTOR" ]] || fail "missing executable detector: $DETECTOR"

# Regexes in variables: bash 3.2 (the floor) mis-parses some quoted regex
# literals written inline in [[ =~ ]].
status_re=$'^(ok|unsupported|detection-failed)\t'
bash_shell_re=$'^HOST_SHELL\tbash [0-9]'
zsh_shell_re='^zsh [0-9]'
userland_re=$'^HOST_USERLAND\t(gnu|bsd|unknown)$'
steering_re=$'^HOST_TOOL_STEERING\t(none|[A-Z][A-Z0-9_]*( [A-Z][A-Z0-9_]*)*)$'

read_record() { # file key -- prints the VALUE of KEY<TAB>VALUE, fails if absent
	local file="$1" key="$2" line
	while IFS= read -r line; do
		case $line in
		"$key"$'\t'*)
			printf '%s\n' "${line#"$key"$'\t'}"
			return 0
			;;
		esac
	done <"$file"
	fail "no $key record in $file"
}

make_fake_uname() { # directory value
	mkdir -p "$1/bin"
	cat >"$1/bin/uname" <<EOF
#!/bin/sh
printf '%s\n' '$2'
EOF
	chmod +x "$1/bin/uname"
}

# The status line stays first and the three records follow in order; reading
# them sequentially is what asserts that order.
read_payload() { # file -- sets payload_status payload_shell payload_userland payload_steering
	payload_status=''
	payload_shell=''
	payload_userland=''
	payload_steering=''
	{
		IFS= read -r payload_status
		IFS= read -r payload_shell
		IFS= read -r payload_userland
		IFS= read -r payload_steering
	} <"$1"
}

# --- Live host: contract shape ------------------------------------------

live="$SCRATCH/live"
/bin/bash "$DETECTOR" >"$live" 2>"$live.stderr"
read_payload "$live"
[[ "$payload_status" =~ $status_re ]] ||
	fail "live status line off-contract: $payload_status"
[[ ! -s "$live.stderr" ]] || fail "live run wrote to stderr on a supported host"
[[ "$payload_shell" =~ $bash_shell_re ]] ||
	fail "the invoking bash should be recorded with its version, got: $payload_shell"
[[ "$payload_userland" =~ $userland_re ]] ||
	fail "HOST_USERLAND off-contract: $payload_userland"
[[ "$payload_steering" =~ $steering_re ]] ||
	fail "HOST_TOOL_STEERING off-contract: $payload_steering"
printf '  ok   live payload shape\n'

# --- Clean environment: no steering variables means `none` ---------------

clean="$SCRATCH/clean"
env -i PATH="$PATH" /bin/bash "$DETECTOR" >"$clean" 2>/dev/null
clean_steering="$(read_record "$clean" HOST_TOOL_STEERING)"
[[ "$clean_steering" == none ]] ||
	fail "a scrubbed environment must record none, got: $clean_steering"
printf '  ok   clean environment records none\n'

# --- Steering captures names, never values -------------------------------

leak="$SCRATCH/leak"
secret_rc="$SCRATCH/private/ripgreprc"
secret_token='hushhush-not-a-real-token'
env -i PATH="$PATH" LC_ALL=C LANG=C.UTF-8 \
	RIPGREP_CONFIG_PATH="$secret_rc" GH_TOKEN="$secret_token" GH_HOST=git.example \
	/bin/bash "$DETECTOR" >"$leak" 2>/dev/null
leak_steering="$(read_record "$leak" HOST_TOOL_STEERING)"
for name in RIPGREP_CONFIG_PATH GH_TOKEN GH_HOST LC_ALL LANG; do
	case " $leak_steering " in
	*" $name "*) ;;
	*) fail "set steering variable not recorded: $name (got: $leak_steering)" ;;
	esac
done
leak_body="$(cat "$leak")"
[[ "$leak_body" != *"$secret_rc"* ]] ||
	fail 'HOST_TOOL_STEERING leaked RIPGREP_CONFIG_PATHs value'
[[ "$leak_body" != *"$secret_token"* ]] ||
	fail 'HOST_TOOL_STEERING leaked GH_TOKENs value'
[[ "$leak_body" != *"git.example"* ]] ||
	fail 'HOST_TOOL_STEERING leaked GH_HOSTs value'
printf '  ok   steering records names only\n'

# --- Fail-open: observation tools missing, architecture fine -------------

# Only uname is on PATH, so ps and sed are unreachable: both observable
# records must sit at their explicit markers while the status contract is
# untouched -- exit 0 and ok.
stripped="$SCRATCH/stripped"
make_fake_uname "$stripped" x86_64
status=0
PATH="$stripped/bin" /bin/bash "$DETECTOR" >"$stripped/out" 2>"$stripped/err" || status=$?
[[ "$status" -eq 0 ]] || fail "stripped PATH: expected exit 0, got $status"
read_payload "$stripped/out"
[[ "$payload_status" == $'ok\tx86_64' ]] ||
	fail "stripped PATH changed the status line: $payload_status"
[[ "$payload_shell" == $'HOST_SHELL\tunknown' ]] ||
	fail "stripped PATH must leave HOST_SHELL at its marker: $payload_shell"
[[ "$payload_userland" == $'HOST_USERLAND\tunknown' ]] ||
	fail "stripped PATH must leave HOST_USERLAND at its marker: $payload_userland"
[[ "$payload_steering" =~ $steering_re ]] ||
	fail "stripped PATH steering off-contract: $payload_steering"
printf '  ok   stripped PATH fails open\n'

# --- Fail-open holds on every exit path: unsupported still records --------

unsupported_case="$SCRATCH/unsupported-case"
make_fake_uname "$unsupported_case" riscv64
status=0
PATH="$unsupported_case/bin" /bin/bash "$DETECTOR" >"$unsupported_case/out" \
	2>/dev/null || status=$?
[[ "$status" -eq 2 ]] || fail "unsupported case: expected exit 2, got $status"
read_payload "$unsupported_case/out"
[[ "$payload_status" == $'unsupported\triscv64' ]] ||
	fail "unsupported case lost its status line: $payload_status"
[[ "$payload_shell" == $'HOST_SHELL\tunknown' ]] ||
	fail "unsupported case lost HOST_SHELL: $payload_shell"
[[ "$payload_userland" == $'HOST_USERLAND\tunknown' ]] ||
	fail "unsupported case lost HOST_USERLAND: $payload_userland"
[[ "$payload_steering" =~ $steering_re ]] ||
	fail "unsupported case steering off-contract: $payload_steering"
printf '  ok   unsupported exit still records\n'

# --- HOST_SHELL follows the shell that invoked the detector --------------

# A trailing command keeps zsh from exec-optimizing the detector into its own
# process slot -- without it the detector's parent is this suite's bash and
# the assertion would pass or fail on zsh's tail-call optimization rather
# than on the family observation. Skipped where zsh is absent; the
# bash-parent case above already covers the direct invocation.
if command -v zsh >/dev/null 2>&1; then
	zsh_case="$SCRATCH/zsh-case"
	zsh -c '"$1" >"$2.out"; :' zsh "$DETECTOR" "$zsh_case" 2>/dev/null
	zsh_shell="$(read_record "$zsh_case.out" HOST_SHELL)"
	[[ "$zsh_shell" =~ $zsh_shell_re ]] ||
		fail "a zsh parent should be recorded as zsh with a version, got: $zsh_shell"
	printf '  ok   zsh parent observed as zsh\n'
else
	printf '  skip zsh parent (no zsh on PATH)\n'
fi

printf 'detect-host-architecture-test: pass\n'
