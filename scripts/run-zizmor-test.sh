#!/usr/bin/env bash
set -euo pipefail

# Fixture suite for scripts/run-zizmor.sh. zizmor is stubbed on PATH, so the suite
# needs no network, no credentials, and no zizmor installation, and it pins the
# gate's own behaviour rather than the tool's. CI installs the admitted version
# exactly, while the stub lets this suite exercise rejected observations too (ADR 0044).
#
# The stub records the argv it was handed and which token variables reached it,
# and exits with whatever status a case asks for. Two of those recordings are the
# whole point: argv proves --offline is passed on exactly the offline path, and
# the token recording proves an exported-but-empty variable was removed rather
# than forwarded to a zizmor that would reject it.
#
# Every invocation sets all five mode variables explicitly -- including to unset --
# because a developer with ZIZMOR_OFFLINE or GH_TOKEN exported would otherwise run
# a different suite than CI does. That is the same reason check-plugin-version-test
# always sets BASE_SHA.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/test-fixture-helpers.sh
. "$script_dir/test-fixture-helpers.sh"

fixture_init run-zizmor-test

gate=$script_dir/run-zizmor.sh

stub_dir=$SCRATCH/bin
mkdir -p "$stub_dir"

# Written once; each case chooses the exit status through ZIZMOR_STUB_STATUS,
# which is read at run time rather than baked in.
cat >"$stub_dir/zizmor" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --version ]]; then
	printf '%s\n' "${ZIZMOR_STUB_VERSION_OUTPUT:-zizmor 1.29.0}"
	exit "${ZIZMOR_STUB_VERSION_STATUS:-0}"
fi
printf '%s\n' "$*" >"$ZIZMOR_STUB_ARGV"
{
	printf 'GH_TOKEN=%s\n' "${GH_TOKEN+<set:$GH_TOKEN>}"
	printf 'GITHUB_TOKEN=%s\n' "${GITHUB_TOKEN+<set:$GITHUB_TOKEN>}"
	printf 'ZIZMOR_GITHUB_TOKEN=%s\n' "${ZIZMOR_GITHUB_TOKEN+<set:$ZIZMOR_GITHUB_TOKEN>}"
} >"$ZIZMOR_STUB_ENV"
exit "${ZIZMOR_STUB_STATUS:-0}"
STUB
chmod +x "$stub_dir/zizmor"

argv_file=$SCRATCH/argv
env_file=$SCRATCH/env

# run <status> [VAR=VALUE ...] -- sets RUN_OUTPUT, RUN_STATUS, RUN_ARGV, RUN_ENV.
#
# `env -u` on all five names first, then the case's own assignments, so a value
# the case does not mention is genuinely absent rather than inherited.
run() {
	local status=$1
	shift
	: >"$argv_file"
	: >"$env_file"
	RUN_STATUS=0
	RUN_OUTPUT=$(
		env -u ZIZMOR_OFFLINE -u ZIZMOR_NO_ONLINE_AUDITS \
			-u GH_TOKEN -u GITHUB_TOKEN -u ZIZMOR_GITHUB_TOKEN -u GH_HOST \
			PATH="$stub_dir:$PATH" \
			ZIZMOR_STUB_ARGV="$argv_file" \
			ZIZMOR_STUB_ENV="$env_file" \
			ZIZMOR_STUB_STATUS="$status" \
			ZIZMOR_STUB_VERSION_OUTPUT='zizmor 1.29.0' \
			ZIZMOR_STUB_VERSION_STATUS=0 \
			"$@" \
			"$gate" .github/workflows/ 2>&1
	) || RUN_STATUS=$?
	RUN_ARGV=$(cat "$argv_file")
	RUN_ENV=$(cat "$env_file")
}

assert_contains() { # label haystack needle
	case $2 in
	*"$3"*) ;;
	*) fail "$1: expected output to contain '$3', got: $2" ;;
	esac
}

assert_lacks() { # label haystack needle
	case $2 in
	*"$3"*) fail "$1: expected output NOT to contain '$3', got: $2" ;;
	esac
}

assert_status() { # label expected actual
	[[ $2 -eq $3 ]] || fail "$1: expected exit $2, got $3"
}

ok() { # message
	printf 'ok   %s\n' "$1"
}

# -- exact analyzer version admission --

run 0 GH_TOKEN=t1
assert_status 'admitted version' 0 "$RUN_STATUS"
[[ $RUN_ARGV == '.github/workflows/' ]] ||
	fail "admitted version: expected audit invocation, got '$RUN_ARGV'"
ok 'zizmor 1.29.0 is admitted and the audit runs'

for observed in 'zizmor 1.28.0' 'zizmor 1.30.0'; do
	run 0 ZIZMOR_STUB_VERSION_OUTPUT="$observed"
	assert_status "version mismatch $observed" 1 "$RUN_STATUS"
	assert_contains "version mismatch $observed" "$RUN_OUTPUT" 'expected zizmor 1.29.0'
	assert_contains "version mismatch $observed" "$RUN_OUTPUT" "observed $observed"
	[[ -z $RUN_ARGV ]] ||
		fail "version mismatch $observed: audit ran with '$RUN_ARGV'"
done
ok 'older and newer analyzer versions fail before the audit and name both versions'

malformed_version=$'zizmor 1.29.0; touch should-not-exist\nextra output'
run 0 ZIZMOR_STUB_VERSION_OUTPUT="$malformed_version"
assert_status 'malformed version' 1 "$RUN_STATUS"
assert_contains 'malformed version' "$RUN_OUTPUT" 'observed zizmor 1.29.0; touch should-not-exist'
assert_contains 'malformed version' "$RUN_OUTPUT" 'extra output'
[[ -z $RUN_ARGV ]] || fail "malformed version: audit ran with '$RUN_ARGV'"
[[ ! -e $SCRATCH/should-not-exist ]] || fail 'malformed version output was evaluated'
ok 'multiline metacharacter output is reported as inert data and fails before the audit'

run 0 ZIZMOR_STUB_VERSION_STATUS=9 ZIZMOR_STUB_VERSION_OUTPUT='version probe failed'
assert_status 'version command failure' 1 "$RUN_STATUS"
assert_contains 'version command failure' "$RUN_OUTPUT" 'expected zizmor 1.29.0'
assert_contains 'version command failure' "$RUN_OUTPUT" 'version command exited 9'
[[ -z $RUN_ARGV ]] || fail "version command failure: audit ran with '$RUN_ARGV'"
ok 'a failed version command names its status and prevents the audit'

# -- mode selection from the token variables --

# The online argv is pinned exactly, not merely checked for the absence of
# --offline. A negative assertion passes a mutant that adds --no-online-audits,
# --min-severity high, --no-exit-codes, or -o, each of which disables online
# auditing while the gate still announces "online mode" -- unaudited AND labelled
# audited, which the design calls worse than the status quo it replaces.
run 0 GH_TOKEN=t1
assert_contains 'GH_TOKEN online' "$RUN_OUTPUT" 'online mode; API token from GH_TOKEN'
[[ $RUN_ARGV == '.github/workflows/' ]] ||
	fail "GH_TOKEN online: expected argv '.github/workflows/', got '$RUN_ARGV'"
ok 'GH_TOKEN selects online and zizmor is invoked with the inputs alone'

run 0 GITHUB_TOKEN=t2
assert_contains 'GITHUB_TOKEN online' "$RUN_OUTPUT" 'API token from GITHUB_TOKEN'
ok 'GITHUB_TOKEN selects online'

run 0 ZIZMOR_GITHUB_TOKEN=t3
assert_contains 'ZIZMOR_GITHUB_TOKEN online' "$RUN_OUTPUT" 'API token from ZIZMOR_GITHUB_TOKEN'
ok 'ZIZMOR_GITHUB_TOKEN selects online'

run 0 GH_TOKEN=t1 GITHUB_TOKEN=t2 ZIZMOR_GITHUB_TOKEN=t3
assert_contains 'precedence' "$RUN_OUTPUT" 'API token from GH_TOKEN'
ok 'GH_TOKEN wins, matching zizmor own documented order'

run 0
assert_status 'no token' 0 "$RUN_STATUS"
assert_contains 'no token' "$RUN_OUTPUT" 'offline mode (--offline); no API token'
assert_contains 'no token' "$RUN_OUTPUT" 'GH_TOKEN, GITHUB_TOKEN and ZIZMOR_GITHUB_TOKEN'
assert_contains 'no token' "$RUN_ARGV" '--offline'
ok 'no token gives offline, exit 0, and names all three variables'

run 0
assert_contains 'consequence' "$RUN_OUTPUT" 'pin provenance was NOT audited'
ok 'the offline path states the consequence'

run 0 GH_TOKEN=t1
assert_lacks 'online consequence' "$RUN_OUTPUT" 'pin provenance was NOT audited'
ok 'the online path does not state the offline consequence'

# -- an empty token variable is removed, not forwarded --

run 0 GH_TOKEN=
assert_status 'empty GH_TOKEN' 0 "$RUN_STATUS"
assert_contains 'empty GH_TOKEN' "$RUN_OUTPUT" 'offline mode (--offline); no API token'
assert_contains 'empty GH_TOKEN' "$RUN_ENV" 'GH_TOKEN='
assert_lacks 'empty GH_TOKEN' "$RUN_ENV" 'GH_TOKEN=<set:>'
ok 'an exported-but-empty GH_TOKEN is removed before zizmor sees it'

run 0 GH_TOKEN= GITHUB_TOKEN=t2
assert_contains 'empty then set' "$RUN_OUTPUT" 'API token from GITHUB_TOKEN'
assert_lacks 'empty then set' "$RUN_ENV" 'GH_TOKEN=<set:>'
assert_contains 'empty then set' "$RUN_ENV" 'GITHUB_TOKEN=<set:t2>'
ok 'an empty variable is skipped and the next one selects online'

run 0 GH_TOKEN=t1
assert_contains 'token forwarded' "$RUN_ENV" 'GH_TOKEN=<set:t1>'
ok 'a real token reaches zizmor unchanged, for zizmor to read itself'

# All three names, not just GH_TOKEN. Each is separately fatal to zizmor when
# exported empty -- measured on 1.29.0, `GITHUB_TOKEN= zizmor --offline` exits 2
# with `invalid value '' for '--github-token'`, and ZIZMOR_GITHUB_TOKEN gives the
# same against --zizmor-github-token -- so a removal dropped for one of them
# turns a green tokenless gate into exit 2 after the mode line has printed.
run 0 GITHUB_TOKEN=
assert_status 'empty GITHUB_TOKEN' 0 "$RUN_STATUS"
assert_contains 'empty GITHUB_TOKEN' "$RUN_OUTPUT" 'offline mode (--offline); no API token'
assert_lacks 'empty GITHUB_TOKEN' "$RUN_ENV" 'GITHUB_TOKEN=<set:>'
ok 'an exported-but-empty GITHUB_TOKEN is removed before zizmor sees it'

run 0 ZIZMOR_GITHUB_TOKEN=
assert_status 'empty ZIZMOR_GITHUB_TOKEN' 0 "$RUN_STATUS"
assert_contains 'empty ZIZMOR_GITHUB_TOKEN' "$RUN_OUTPUT" 'offline mode (--offline); no API token'
assert_lacks 'empty ZIZMOR_GITHUB_TOKEN' "$RUN_ENV" 'ZIZMOR_GITHUB_TOKEN=<set:>'
ok 'an exported-but-empty ZIZMOR_GITHUB_TOKEN is removed before zizmor sees it'

run 0 GH_TOKEN= GITHUB_TOKEN= ZIZMOR_GITHUB_TOKEN=
assert_status 'all three empty' 0 "$RUN_STATUS"
assert_contains 'all three empty' "$RUN_OUTPUT" 'offline mode (--offline); no API token'
assert_lacks 'all three empty' "$RUN_ENV" '<set:>'
ok 'all three empty at once gives offline at exit 0, with none forwarded'

# -- the mode variables outrank a token, by value --

run 0 ZIZMOR_OFFLINE=true GH_TOKEN=t1
assert_contains 'ZIZMOR_OFFLINE=true' "$RUN_OUTPUT" 'offline mode (--offline); ZIZMOR_OFFLINE=true'
assert_contains 'ZIZMOR_OFFLINE=true' "$RUN_ARGV" '--offline'
ok 'ZIZMOR_OFFLINE=true beats a present token and is the reported condition'

run 0 ZIZMOR_NO_ONLINE_AUDITS=true GH_TOKEN=t1
assert_contains 'ZIZMOR_NO_ONLINE_AUDITS=true' "$RUN_OUTPUT" 'ZIZMOR_NO_ONLINE_AUDITS=true'
ok 'ZIZMOR_NO_ONLINE_AUDITS=true beats a present token'

# The two offline conditions compete here, and the reported one must be the
# variable rather than the missing token. Getting it backwards would tell an
# operator to export a token, which cannot change the mode while their own
# ZIZMOR_OFFLINE still wins -- a cause the observation does not carry, which is
# the failure ADR 0025 decision 2 forbids and this change exists to remove.
run 0 ZIZMOR_OFFLINE=true
assert_status 'mode var, no token' 0 "$RUN_STATUS"
assert_contains 'mode var, no token' "$RUN_OUTPUT" 'offline mode (--offline); ZIZMOR_OFFLINE=true'
assert_lacks 'mode var, no token' "$RUN_OUTPUT" 'no API token'
ok 'a mode variable is reported ahead of the missing token when both would apply'

run 0 ZIZMOR_NO_ONLINE_AUDITS=true
assert_contains 'sibling, no token' "$RUN_OUTPUT" 'offline mode (--offline); ZIZMOR_NO_ONLINE_AUDITS=true'
assert_lacks 'sibling, no token' "$RUN_OUTPUT" 'no API token'
ok 'the sibling mode variable is likewise reported ahead of the missing token'

run 0 ZIZMOR_OFFLINE=true ZIZMOR_NO_ONLINE_AUDITS=true GH_TOKEN=t1
assert_contains 'both mode vars' "$RUN_OUTPUT" 'ZIZMOR_OFFLINE=true'
assert_lacks 'both mode vars' "$RUN_OUTPUT" 'ZIZMOR_NO_ONLINE_AUDITS=true'
ok 'ZIZMOR_OFFLINE is reported first when both are set'

run 0 ZIZMOR_OFFLINE=false GH_TOKEN=t1
assert_contains 'ZIZMOR_OFFLINE=false' "$RUN_OUTPUT" 'online mode; API token from GH_TOKEN'
assert_lacks 'ZIZMOR_OFFLINE=false' "$RUN_ARGV" '--offline'
ok 'ZIZMOR_OFFLINE=false is an online request, not an offline one'

run 0 ZIZMOR_OFFLINE=false
assert_status 'false without a token' 0 "$RUN_STATUS"
assert_contains 'false without a token' "$RUN_OUTPUT" 'no API token'
ok 'ZIZMOR_OFFLINE=false without a token still reports the no-token condition'

# -- a malformed mode value warns and selects nothing --

run 0 ZIZMOR_OFFLINE=0
assert_status 'malformed, no token' 0 "$RUN_STATUS"
assert_contains 'malformed, no token' "$RUN_OUTPUT" 'ZIZMOR_OFFLINE=0 is not a value zizmor accepts (true or false); it selects no mode here'
assert_contains 'malformed, no token' "$RUN_OUTPUT" 'no API token'
ok 'a malformed ZIZMOR_OFFLINE warns, then falls through, and zizmor still runs'

run 0 ZIZMOR_OFFLINE=0 GH_TOKEN=t1
assert_contains 'malformed with token' "$RUN_OUTPUT" 'is not a value zizmor accepts'
assert_contains 'malformed with token' "$RUN_OUTPUT" 'online mode'
ok 'a malformed value selects nothing, so a token still gives online'

run 0 ZIZMOR_OFFLINE=
assert_contains 'empty mode var' "$RUN_OUTPUT" 'ZIZMOR_OFFLINE= is not a value zizmor accepts'
ok 'an exported-but-empty mode variable is reported, not treated as absent'

run 0 ZIZMOR_NO_ONLINE_AUDITS=maybe
assert_contains 'malformed sibling' "$RUN_OUTPUT" 'ZIZMOR_NO_ONLINE_AUDITS=maybe is not a value'
ok 'the sibling mode variable is validated the same way'

run 0 ZIZMOR_OFFLINE=true
assert_lacks 'valid value quiet' "$RUN_OUTPUT" 'is not a value'
ok 'a valid mode value produces no warning'

# -- GH_HOST is named on the online line --

run 0 GH_TOKEN=t1 GH_HOST=ghe.example.invalid
assert_contains 'GH_HOST named' "$RUN_OUTPUT" 'GH_HOST=ghe.example.invalid'
ok 'GH_HOST is named on the online line'

run 0 GH_TOKEN=t1
assert_lacks 'GH_HOST absent' "$RUN_OUTPUT" 'GH_HOST'
ok 'the online line omits the host clause when GH_HOST is unset'

# An exported-but-empty GH_HOST is a value zizmor uses and fails on, not an
# absent one, so the clause must print for it -- otherwise the one pointing most
# likely to confuse is the one the line stays silent about.
run 0 GH_TOKEN=t1 GH_HOST=
assert_contains 'GH_HOST empty' "$RUN_OUTPUT" 'GH_HOST='
ok 'an exported-but-empty GH_HOST is still named on the online line'

# -- the status is re-raised, and the hint fires only on tool failure --

run 1 GH_TOKEN=t1
assert_status 'tool failure' 1 "$RUN_STATUS"
assert_contains 'tool failure' "$RUN_OUTPUT" 'the audit run failed rather than reporting findings'
ok 'a tool failure is re-raised and draws the hint'

# Status 1 covers an unreachable API, a rejected token, `invalid input: <path>`
# for a missing directory, and a zizmor.yml that fails to load. The hint must
# therefore not assert which of those happened -- that is the cause-not-carried
# defect ADR 0025 decision 2 forbids, and the one this change exists to remove.
case $RUN_OUTPUT in
*'If it is an API or token fault'*) ;;
*) fail 'hint names no cause: expected the remedy to be offered conditionally' ;;
esac
ok 'the hint offers its remedy conditionally and asserts no cause'

run 14 GH_TOKEN=t1
assert_status 'findings' 14 "$RUN_STATUS"
assert_lacks 'findings' "$RUN_OUTPUT" 'the audit run failed rather than reporting findings'
ok 'findings are re-raised with no hint -- never advise disabling the audit'

run 2 GH_TOKEN=t1
assert_status 'usage error' 2 "$RUN_STATUS"
assert_lacks 'usage error' "$RUN_OUTPUT" 'the audit run failed rather than reporting findings'
ok 'a usage error is re-raised with no hint'

run 1
assert_status 'offline failure' 1 "$RUN_STATUS"
assert_lacks 'offline failure' "$RUN_OUTPUT" 'the audit run failed rather than reporting findings'
ok 'the hint never fires on the offline path'

run 0 GH_TOKEN=t1
assert_status 'clean online' 0 "$RUN_STATUS"
assert_lacks 'clean online' "$RUN_OUTPUT" 'the audit run failed rather than reporting findings'
ok 'a clean online run draws no hint'

# -- the token value never reaches the output --

run 1 GH_TOKEN=s3cret-token-value
assert_lacks 'no token leak' "$RUN_OUTPUT" 's3cret-token-value'
ok 'the token value appears nowhere in the output, even on a failure'

# -- inputs and usage --

RUN_STATUS=0
RUN_OUTPUT=$(
	env -u ZIZMOR_OFFLINE -u ZIZMOR_NO_ONLINE_AUDITS \
		-u GH_TOKEN -u GITHUB_TOKEN -u ZIZMOR_GITHUB_TOKEN \
		PATH="$stub_dir:$PATH" ZIZMOR_STUB_ARGV="$argv_file" \
		ZIZMOR_STUB_ENV="$env_file" "$gate" 2>&1
) || RUN_STATUS=$?
assert_status 'no arguments' 2 "$RUN_STATUS"
assert_contains 'no arguments' "$RUN_OUTPUT" 'usage: run-zizmor.sh'
ok 'no arguments is a usage fault at exit 2'

# A mode flag on argv beats the mode this script resolved and announced, so the
# script refuses one rather than printing a line that the run then contradicts.
for flag in --offline --no-online-audits -o --min-severity; do
	RUN_STATUS=0
	: >"$argv_file"
	RUN_OUTPUT=$(
		env -u ZIZMOR_OFFLINE -u ZIZMOR_NO_ONLINE_AUDITS \
			-u GH_TOKEN -u GITHUB_TOKEN -u ZIZMOR_GITHUB_TOKEN \
			PATH="$stub_dir:$PATH" ZIZMOR_STUB_ARGV="$argv_file" \
			ZIZMOR_STUB_ENV="$env_file" ZIZMOR_STUB_STATUS=0 \
			"$gate" "$flag" .github/workflows/ 2>&1
	) || RUN_STATUS=$?
	assert_status "flag $flag" 2 "$RUN_STATUS"
	assert_contains "flag $flag" "$RUN_OUTPUT" 'usage: run-zizmor.sh'
	[[ -z $(cat "$argv_file") ]] ||
		fail "flag $flag: zizmor was invoked despite the usage fault"
	assert_lacks "flag $flag" "$RUN_OUTPUT" 'online mode'
	assert_lacks "flag $flag" "$RUN_OUTPUT" 'offline mode'
done
ok 'a mode flag among the inputs is refused at exit 2, before any mode is announced'

RUN_STATUS=0
: >"$argv_file"
RUN_OUTPUT=$(
	env -u ZIZMOR_OFFLINE -u ZIZMOR_NO_ONLINE_AUDITS \
		-u GH_TOKEN -u GITHUB_TOKEN -u ZIZMOR_GITHUB_TOKEN \
		PATH="$stub_dir:$PATH" ZIZMOR_STUB_ARGV="$argv_file" \
		ZIZMOR_STUB_ENV="$env_file" ZIZMOR_STUB_STATUS=0 \
		"$gate" one/ two/ 2>&1
) || RUN_STATUS=$?
RUN_ARGV=$(cat "$argv_file")
[[ $RUN_ARGV == '--offline one/ two/' ]] ||
	fail "forwarding: expected '--offline one/ two/', got '$RUN_ARGV'"
ok 'every input is forwarded, in order, after the mode flag'

RUN_STATUS=0
: >"$argv_file"
RUN_OUTPUT=$(
	env -u ZIZMOR_OFFLINE -u ZIZMOR_NO_ONLINE_AUDITS \
		-u GITHUB_TOKEN -u ZIZMOR_GITHUB_TOKEN -u GH_HOST \
		PATH="$stub_dir:$PATH" ZIZMOR_STUB_ARGV="$argv_file" \
		ZIZMOR_STUB_ENV="$env_file" ZIZMOR_STUB_STATUS=0 \
		GH_TOKEN=t1 "$gate" one/ two/ 2>&1
) || RUN_STATUS=$?
RUN_ARGV=$(cat "$argv_file")
[[ $RUN_ARGV == 'one/ two/' ]] ||
	fail "online forwarding: expected 'one/ two/', got '$RUN_ARGV'"
ok 'the online path forwards the inputs with no flag of any kind'

printf 'run-zizmor-test: all cases passed\n'
