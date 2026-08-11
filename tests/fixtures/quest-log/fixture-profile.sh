# shellcheck shell=bash
# Stub profile, used only by the contract suite.
#
# It exists so the declared-degraded mechanism has a profile that actually
# declares a degradation. profiles/github.sh implements every operation, so
# without this the gate would ship untested and a profile that simply forgot an
# operation would be indistinguishable from one that legitimately degrades.
#
# It lives here rather than in profiles/ because profile_view answers with a
# fabricated issue that a caller cannot tell from a real read. A testdata/
# directory is filtered out of the installed payload, so the engine can only
# reach this file when tracker-test.sh stages it into the asset tree it
# assembles.
#
# Read by tracker.sh after it sources this file; shellcheck cannot see that use.
# shellcheck disable=SC2034

PROFILE_DECLARES="view:implemented
label_history:degraded=unknown"

profile_view() {
	printf '%s' '{"id":"1","ref":"#1","url":"","title":"","body":"","labels":[],'
	printf '%s\n' '"state":"open","done":false,"parent":null,"updated":null}'
}

profile_label_history() {
	printf 'unknown\n'
}
