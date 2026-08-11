#!/usr/bin/env bash
set -euo pipefail

# ripgrep applies RIPGREP_CONFIG_PATH's contents as arguments ahead of the ones
# passed below, so a personal ripgreprc would otherwise steer this suite's own
# assertions -- which are asserted in both directions, so a steered config makes
# one of the pair lie.
unset RIPGREP_CONFIG_PATH

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DETECTOR="$ROOT/skills/preflight/scripts/detect-host-architecture"
RESOLVER="$ROOT/skills/preflight/scripts/resolve-architecture-context"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/architecture-awareness-test.XXXXXX")"

cleanup() {
	rm -R "$FIXTURE"
}
trap cleanup EXIT

fail() {
	printf 'architecture-awareness-test: %s\n' "$1" >&2
	exit 1
}

assert_file() {
	local expected="$1" actual_file="$2" label="$3" actual
	actual="$(cat "$actual_file")"
	[[ "$actual" == "$expected" ]] ||
		fail "$label: expected '$expected', got '$actual'"
}

assert_contains() {
	local file="$1" expected="$2"
	rg -Fq -- "$expected" "$file" || fail "$file does not contain: $expected"
}

make_fake_uname() {
	local bin_dir="$1"
	mkdir -p "$bin_dir"
	cat >"$bin_dir/uname" <<'EOF'
#!/bin/bash
set -euo pipefail

case "${FAKE_UNAME_MODE:-output}" in
output) printf '%s\n' "${FAKE_UNAME_VALUE-}" ;;
fail)
	printf '%s\n' 'raw uname failure sentinel' >&2
	exit "${FAKE_UNAME_STATUS:-42}"
	;;
*) exit 99 ;;
esac
EOF
	chmod +x "$bin_dir/uname"
}

run_case() {
	local name="$1" mode="$2" value="$3" fake_status="$4"
	local expected_status="$5" expected_stdout="$6" expected_stderr="$7"
	local case_dir="$FIXTURE/$name" status=0
	local bin_dir="$case_dir/bin"
	mkdir -p "$case_dir"
	make_fake_uname "$bin_dir"

	PATH="$bin_dir" FAKE_UNAME_MODE="$mode" FAKE_UNAME_VALUE="$value" \
		FAKE_UNAME_STATUS="$fake_status" /bin/bash "$DETECTOR" \
		>"$case_dir/stdout" 2>"$case_dir/stderr" || status=$?

	[[ "$status" -eq "$expected_status" ]] ||
		fail "$name: expected exit $expected_status, got $status"
	assert_file "$expected_stdout" "$case_dir/stdout" "$name stdout"
	assert_file "$expected_stderr" "$case_dir/stderr" "$name stderr"
	printf '  ok   %s\n' "$name"
}

run_missing_uname() {
	local case_dir="$FIXTURE/missing-uname" status=0
	mkdir -p "$case_dir/bin"
	PATH="$case_dir/bin" /bin/bash "$DETECTOR" \
		>"$case_dir/stdout" 2>"$case_dir/stderr" || status=$?
	[[ "$status" -eq 3 ]] || fail "missing uname: expected exit 3, got $status"
	assert_file $'detection-failed\tuname-missing' "$case_dir/stdout" \
		'missing uname stdout'
	assert_file \
		'detect-host-architecture: uname is required; install or expose uname in PATH' \
		"$case_dir/stderr" 'missing uname stderr'
	printf '  ok   missing uname\n'
}

[[ -x "$DETECTOR" ]] || fail "missing executable detector: $DETECTOR"

run_case x86_64 output x86_64 0 0 $'ok\tx86_64' ''
run_case amd64 output amd64 0 0 $'ok\tx86_64' ''
run_case arm64 output arm64 0 0 $'ok\tarm64' ''
run_case aarch64 output aarch64 0 0 $'ok\tarm64' ''
run_case ppc64le output ppc64le 0 0 $'ok\tppc64le' ''
run_case s390x output s390x 0 0 $'ok\ts390x' ''
supported_suffix='; supported: x86_64, arm64, ppc64le, s390x'
supported_suffix+='; update the detector mapping if this host should be supported'
supported_suffix+=', or use a supported host'
run_case unsupported output riscv64 0 2 $'unsupported\triscv64' \
	"detect-host-architecture: unsupported machine riscv64$supported_suffix"
run_case empty output '' 0 2 $'unsupported\t<empty>' \
	"detect-host-architecture: unsupported machine <empty>$supported_suffix"
run_case tab output $'riscv\t64' 0 2 $'unsupported\t$\'riscv\\t64\'' \
	"detect-host-architecture: unsupported machine \$'riscv\\t64'$supported_suffix"
run_case newline output $'riscv\n64' 0 2 $'unsupported\t$\'riscv\\n64\'' \
	"detect-host-architecture: unsupported machine \$'riscv\\n64'$supported_suffix"
run_case escape output $'riscv\e64' 0 2 $'unsupported\t$\'riscv\\E64\'' \
	"detect-host-architecture: unsupported machine \$'riscv\\E64'$supported_suffix"
run_case bell output $'riscv\a64' 0 2 $'unsupported\t$\'riscv\\a64\'' \
	"detect-host-architecture: unsupported machine \$'riscv\\a64'$supported_suffix"
run_case uname-failure fail '' 42 3 $'detection-failed\tuname-exit-42' \
	'detect-host-architecture: uname -m failed with exit 42; retry after fixing uname'
run_missing_uname

assert_context() {
	local expected="$1"
	shift
	local actual
	actual="$("$RESOLVER" "$@")"
	[[ "$actual" == "$expected" ]] ||
		fail "context $*: expected '$expected', got '$actual'"
}

resolver_error_count=0
assert_resolver_error() {
	local label="$1" expected="$2" status=0 prefix
	shift 2
	((++resolver_error_count))
	prefix="$FIXTURE/resolver-error-$resolver_error_count"
	"$RESOLVER" "$@" >"$prefix.stdout" 2>"$prefix.stderr" || status=$?
	[[ "$status" -eq 64 ]] || fail "$label: expected exit 64, got $status"
	assert_file '' "$prefix.stdout" "$label stdout"
	assert_file "resolve-architecture-context: $expected" "$prefix.stderr" "$label stderr"
}

[[ -x "$RESOLVER" ]] || fail "missing executable resolver: $RESOLVER"
assert_context "$(printf '%s\n' $'HOST_ARCHITECTURE\tx86_64' \
	$'TARGET_ARCHITECTURES\tamd64' $'TARGET_ARCHITECTURES\tarm64' \
	$'ARCHITECTURE_RELATIONSHIP\tincluded')" \
	ok x86_64 declared amd64 arm64
assert_context "$(printf '%s\n' $'HOST_ARCHITECTURE\tarm64' \
	$'TARGET_ARCHITECTURES\tx86_64' $'TARGET_ARCHITECTURES\tppc64le' \
	$'ARCHITECTURE_RELATIONSHIP\tdifferent')" \
	ok arm64 declared x86_64 ppc64le
assert_context "$(printf '%s\n' $'HOST_ARCHITECTURE\tx86_64' \
	$'TARGET_ARCHITECTURES\tnone declared' \
	$'ARCHITECTURE_RELATIONSHIP\tno-target-declared')" \
	ok x86_64 none
assert_context "$(printf '%s\n' $'HOST_ARCHITECTURE\tunsupported (riscv64)' \
	$'TARGET_ARCHITECTURES\triscv64' $'ARCHITECTURE_RELATIONSHIP\thost-unresolved')" \
	unsupported riscv64 declared riscv64
assert_context "$(printf '%s\n' $'HOST_ARCHITECTURE\tdetection failed (uname-exit-42)' \
	$'TARGET_ARCHITECTURES\tx86_64' $'ARCHITECTURE_RELATIONSHIP\thost-unresolved')" \
	detection-failed uname-exit-42 declared x86_64
assert_context "$(printf '%s\n' $'HOST_ARCHITECTURE\tdetection failed (uname-missing)' \
	$'TARGET_ARCHITECTURES\tx86_64' $'TARGET_ARCHITECTURES\tarm64' \
	$'ARCHITECTURE_RELATIONSHIP\tunresolved-target-conflict')" \
	detection-failed uname-missing conflict x86_64 arm64
unsupported_none="$(printf '%s\n' $'HOST_ARCHITECTURE\tunsupported (riscv64)' \
	$'TARGET_ARCHITECTURES\tnone declared' \
	$'ARCHITECTURE_RELATIONSHIP\thost-unresolved')"
assert_context "$unsupported_none" unsupported riscv64 none
assert_context "$(printf '%s\n' $'HOST_ARCHITECTURE\tdetection failed (uname-missing)' \
	$'TARGET_ARCHITECTURES\tnone declared' \
	$'ARCHITECTURE_RELATIONSHIP\thost-unresolved')" \
	detection-failed uname-missing none

later_context="$FIXTURE/later-context"
"$RESOLVER" ok arm64 declared x86_64 ppc64le >"$later_context"
later_host=''
later_relationship=''
later_targets=()
while IFS=$'\t' read -r field value extra; do
	[[ -z "$extra" ]] || fail "later context has an extra field: $field"
	case "$field" in
	HOST_ARCHITECTURE) later_host="$value" ;;
	TARGET_ARCHITECTURES) later_targets+=("$value") ;;
	ARCHITECTURE_RELATIONSHIP) later_relationship="$value" ;;
	*) fail "later context has an unknown field: $field" ;;
	esac
done <"$later_context"
[[ "$later_host" == arm64 ]] || fail "later context lost host: $later_host"
[[ "${later_targets[*]}" == 'x86_64 ppc64le' ]] ||
	fail "later context lost targets: ${later_targets[*]}"
[[ "$later_relationship" == different ]] ||
	fail "later context lost relationship: $later_relationship"

assert_resolver_error 'host control' 'host value must be one escaped record field' \
	ok $'x86_64\nspoofed' declared x86_64
assert_resolver_error 'invalid normalized host' 'ok host must be normalized' \
	ok riscv64 declared x86_64
assert_resolver_error 'empty target' 'target declarations must not be blank' \
	ok x86_64 declared ''
assert_resolver_error 'whitespace target' 'target declarations must not be blank' \
	ok x86_64 conflict x86_64 '   '
assert_resolver_error 'insufficient arguments' \
	'usage: <ok|unsupported|detection-failed> <host-value> <conflict|none|declared> [targets...]' \
	ok x86_64
assert_resolver_error 'unknown host status' 'unknown host status: unknown' \
	unknown x86_64 none
assert_resolver_error 'unknown target state' 'unknown target state: unknown' \
	ok x86_64 unknown
assert_resolver_error 'declared without targets' \
	'declared target state requires at least one target' ok x86_64 declared
assert_resolver_error 'none with targets' 'none target state does not accept targets' \
	ok x86_64 none arm64
assert_resolver_error 'conflict with one declaration' \
	'conflict target state requires at least two declarations' ok x86_64 conflict arm64
assert_resolver_error 'target control' \
	'target declarations must be printable record fields' ok x86_64 declared $'arm\n64'

mutated_resolver="$FIXTURE/mutated-resolver"
cp "$RESOLVER" "$mutated_resolver"
sed -i.bak 's/relationship=included/relationship=different/' "$mutated_resolver"
chmod +x "$mutated_resolver"
mutated_output="$("$mutated_resolver" ok x86_64 declared amd64 arm64)"
if [[ "$mutated_output" == *$'ARCHITECTURE_RELATIONSHIP\tincluded'* ]]; then
	fail 'relationship mutation unexpectedly preserved the included result'
fi

priority_mutant="$FIXTURE/priority-mutant"
awk '
	index($0, "elif [[ \"$host_status\" != ok ]]") {
		print "elif [[ \"$target_state\" == none ]]; then"
		print "\trelationship=no-target-declared"
		getline
		getline
		getline
		print "elif [[ \"$host_status\" != ok ]]; then"
		print "\trelationship=host-unresolved"
		next
	}
	{ print }
' "$RESOLVER" >"$priority_mutant"
chmod +x "$priority_mutant"
priority_output="$("$priority_mutant" unsupported riscv64 none)"
if [[ "$priority_output" == "$unsupported_none" ]]; then
	fail 'priority 2/3 mutation unexpectedly passed the degraded-none contract'
fi

# Two blocks of SKILL.md assertions stood here: 17 phrases and Markdown table
# rows from this skill's own document, and before them a projection check that
# the same rules were mirrored into five carrier documents. Both are gone.
#
# The carriers are not in this repo -- the Claude and Codex ones are whole files
# owned by the private dotfiles repo, and the Bob ones are retired -- so that
# check could not run here at all. The skill-document assertions could have run,
# but pinning prose makes every wording improvement a test failure, and nothing
# automated in this repo asserts on prose.
#
# What remains above is the whole of what this suite should test: the detector
# and resolver behave correctly across every architecture, degraded and hostile
# input case.

printf 'architecture-awareness-test: all assertions passed\n'
