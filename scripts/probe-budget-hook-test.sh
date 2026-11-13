#!/usr/bin/env bash
set -euo pipefail

# Behaviour suite for the SendMessage probe-budget hook in .claude/settings.json.
# The hook is a one-line command, so the suite extracts that exact string and
# runs it under `sh -c` -- dash on Linux, bash in POSIX mode on macOS -- with a
# private TMPDIR, which is where the hook keeps its per-recipient budget state.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/test-fixture-helpers.sh
. "$script_dir/test-fixture-helpers.sh"

fixture_init probe-budget-hook-test

hook=$(jq -er '.hooks.PreToolUse[] | select(.matcher == "SendMessage") | .hooks[0].command' \
	"$script_dir/../.claude/settings.json") || fail 'cannot extract the SendMessage hook command'
state=$SCRATCH/adept-probe-budget

send() { # expected-status recipient message-json
	local status=0
	printf '{"tool_input":{"to":"%s","message":%s}}' "$2" "$3" |
		TMPDIR=$SCRATCH sh -c "$hook" 2>"$SCRATCH/stderr" || status=$?
	[ "$status" -eq "$1" ] ||
		fail "to=$2 message=$3: expected exit $1, got $status: $(cat "$SCRATCH/stderr")"
}

# An undeclared message spends the budget; a second one inside the window is blocked.
send 0 probed '"Status?"'
[ -f "$state/probed" ] || fail 'first undeclared message wrote no budget state'
send 2 probed '"Still there?"'

# Each declared kind passes a spent budget.
send 0 probed '"DECISION: take option B"'
send 0 probed '"ANSWER: yes, rebase onto main"'
send 0 probed '"REFRESH: main moved to abc123"'
send 0 probed '"RESEND: your report stopped mid-sentence"'

# A declared message to a fresh worker leaves its budget unspent.
send 0 fresh '"DECISION: proceed"'
[ ! -e "$state/fresh" ] || fail 'declared message spent the probe budget'
send 0 fresh '"Status?"'

# The prefix counts only at the first byte and only in its exact case.
send 2 probed '"Status?\nDECISION: proceed"'
send 2 probed '" DECISION: proceed"'
send 2 probed '"decision: proceed"'

# A RESEND: request to a fresh worker leaves its budget unspent.
send 0 resend '"RESEND: from step 6"'
[ ! -e "$state/resend" ] || fail 'RESEND: message spent the probe budget'

# An allowlisted protocol object passes a spent budget and writes no state.
send 0 probed '{"type":"shutdown_request"}'
send 0 probed '{"type":"shutdown_response","request_id":"r1","approve":true}'
send 0 probed '{"type":"plan_approval_response","request_id":"r1","approve":false}'
send 0 protocol '{"type":"shutdown_request"}'
[ ! -e "$state/protocol" ] || fail 'protocol message spent the probe budget'

# Any other non-string message counts as undeclared.
send 0 other '{"type":"status_check"}'
send 2 other '{"type":"status_check"}'
send 2 other '{"type":"SHUTDOWN_REQUEST"}'
send 0 notype '{"reason":"no type"}'
send 2 notype '{"reason":"no type"}'
send 0 array '["shutdown_request"]'
send 2 array '["shutdown_request"]'

# The lead and main recipients stay exempt and write no state.
send 0 team-lead '"Status?"'
send 0 main '"Status?"'
if [ -e "$state/team-lead" ] || [ -e "$state/main" ]; then
	fail 'exempt recipient wrote state'
fi

printf 'probe-budget-hook-test: ok\n'
