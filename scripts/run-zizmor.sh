#!/usr/bin/env bash
set -euo pipefail

# Runs zizmor over the inputs it is given, in the strongest mode this environment
# supports, and states which mode that was and the condition that chose it before
# the scan starts.
#
# The gate exists because zizmor's own answer is invisible. Without a token it
# degrades to the offline subset announcing only ` WARN audit: zizmor: zizmor is
# running in offline mode by default` among its INFO lines -- and that WARN does
# not appear at all when ZIZMOR_OFFLINE or ZIZMOR_NO_ONLINE_AUDITS set the mode
# explicitly. Offline mode confirms a pin's shape; the audits it disables are the
# ones that confirm its provenance, so a run that skipped them and a run that
# passed them looked the same from here. See ADR 0036, and ADR 0025 for the rule
# that a degrade reports the condition it observed.
#
# Five environment variables decide zizmor's mode and this script reads all five,
# so the mode it announces is the mode zizmor chooses rather than a second opinion
# that can drift from it. Reading only the token names would announce "online" over
# a run ZIZMOR_OFFLINE had already turned offline.
#
# The two mode controls are clap booleans -- the VALUE is the instruction, not the
# variable's presence, so ZIZMOR_OFFLINE=false is a request for online mode. A
# value that is neither `true` nor `false` selects nothing: it is reported and
# ignored, and zizmor's own parser has the last word. Exiting on it instead would
# refuse in cases where zizmor runs happily, because an explicit --offline on argv
# shadows ZIZMOR_OFFLINE entirely (measured on 1.29.0: `ZIZMOR_OFFLINE=0 zizmor
# --offline` exits 0, the same value with no flag exits 2).
#
# The token's value is never read. Emptiness is all this script tests, and zizmor
# reads the value itself from the environment it inherits, so no credential passes
# through here, through this script's argv, or into its output. An exported-but-
# empty token variable is removed instead, because zizmor rejects one as a usage
# error even with --offline on argv -- that removal is what makes "an empty value
# is not a token" true rather than merely asserted.
#
# Everything above about zizmor's CLI was measured on 1.29.0, and CI installs
# zizmor unpinned. A zizmor that renames a variable makes the mode line disagree
# with the run, which is loud; one that renumbers its exit statuses makes the
# online-failure hint stop appearing, which is silent and harmless.
#
# Exit 2 on usage, otherwise zizmor's own status, re-raised unchanged.

LABEL='run-zizmor'

say() {
	printf '%s: %s\n' "$LABEL" "$*"
}

if (($# == 0)); then
	printf '%s: usage: run-zizmor.sh <input>...\n' "$LABEL" >&2
	exit 2
fi

# Returns 0 when the value selects offline, 1 when it does not -- including the
# malformed case, which warns first.
#
# The warning says "selects no mode here" rather than "ignoring it" because
# ignoring is not something this gate can promise. An explicit --offline on argv
# shadows ZIZMOR_OFFLINE, so a malformed value there really is inert; nothing
# shadows --no-online-audits, so a malformed ZIZMOR_NO_ONLINE_AUDITS still makes
# zizmor exit 2 after this line has been printed. One wording that is true of both
# beats a per-variable branch for the sake of one word.
selects_offline() { # name value
	case $2 in
	true) return 0 ;;
	false) return 1 ;;
	*)
		printf '%s: %s=%s is not a value zizmor accepts (true or false); it selects no mode here, and zizmor may still reject it\n' \
			"$LABEL" "$1" "$2" >&2
		return 1
		;;
	esac
}

mode='online'
condition=''

# ${VAR+set} rather than ${VAR:-}: an exported-but-empty mode variable is a value
# zizmor will reject, not an absent one, so it has to reach selects_offline to be
# reported.
if [[ -n ${ZIZMOR_OFFLINE+set} ]]; then
	if selects_offline ZIZMOR_OFFLINE "$ZIZMOR_OFFLINE"; then
		mode='offline'
		condition="ZIZMOR_OFFLINE=$ZIZMOR_OFFLINE"
	fi
fi

if [[ $mode == online && -n ${ZIZMOR_NO_ONLINE_AUDITS+set} ]]; then
	if selects_offline ZIZMOR_NO_ONLINE_AUDITS "$ZIZMOR_NO_ONLINE_AUDITS"; then
		mode='offline'
		condition="ZIZMOR_NO_ONLINE_AUDITS=$ZIZMOR_NO_ONLINE_AUDITS"
	fi
fi

# Spelled out three times rather than looped through indirect expansion: three
# names, and the explicit form is the one bash 3.2 cannot misread.
if [[ -n ${GH_TOKEN+set} && -z $GH_TOKEN ]]; then
	unset GH_TOKEN
fi
if [[ -n ${GITHUB_TOKEN+set} && -z $GITHUB_TOKEN ]]; then
	unset GITHUB_TOKEN
fi
if [[ -n ${ZIZMOR_GITHUB_TOKEN+set} && -z $ZIZMOR_GITHUB_TOKEN ]]; then
	unset ZIZMOR_GITHUB_TOKEN
fi

# zizmor's own order for --gh-token: [env: GH_TOKEN or GITHUB_TOKEN or
# ZIZMOR_GITHUB_TOKEN].
token_source=''
if [[ -n ${GH_TOKEN:-} ]]; then
	token_source='GH_TOKEN'
elif [[ -n ${GITHUB_TOKEN:-} ]]; then
	token_source='GITHUB_TOKEN'
elif [[ -n ${ZIZMOR_GITHUB_TOKEN:-} ]]; then
	token_source='ZIZMOR_GITHUB_TOKEN'
fi

if [[ $mode == online && -z $token_source ]]; then
	mode='offline'
	condition='no API token: GH_TOKEN, GITHUB_TOKEN and ZIZMOR_GITHUB_TOKEN are all unset or empty'
fi

if [[ $mode == online ]]; then
	# GH_HOST decides which API an online run talks to, and zizmor honours it as
	# --gh-hostname. A token exported for a GitHub Enterprise instance otherwise
	# fails with a message naming an audit rather than the host.
	if [[ -n ${GH_HOST:-} ]]; then
		say "online mode; API token from $token_source; GH_HOST=$GH_HOST"
	else
		say "online mode; API token from $token_source"
	fi
else
	say "offline mode (--offline); $condition"
	say 'pin provenance was NOT audited: a well-formed 40-character SHA that is unreachable in the repository its uses: names, or that a known advisory covers, passes this run'
fi

# Captured explicitly and re-raised. A pipe here would report the last command's
# status and hide zizmor's, and `|| true` would make a scan that could not run
# read as one that found nothing.
status=0
if [[ $mode == online ]]; then
	zizmor "$@" || status=$?
else
	zizmor --offline "$@" || status=$?
fi

# Only zizmor's tool-failure status, never "non-zero". Findings exit 14, and
# offering this there would advise switching off the audit that just caught
# something -- a documented route to a green gate over an unaudited pin. A usage
# error (2) is not offered it either: the offline subset does not fix a malformed
# variable.
#
# The wording leads with the diagnosis and scopes the remedy to a local run,
# because CI is where a token is always set and so where status 1 is most likely.
# On a runner the only way to act on "set ZIZMOR_OFFLINE=true" is to edit
# verify.yml or the Justfile, which turns the five provenance audits off for good
# -- and it would arrive on a red required check, where the pressure to make it
# green is highest. That is the same bad advice the status-14 case is excluded to
# avoid, one step removed.
if [[ $mode == online ]] && ((status == 1)); then
	say 'the online audits could not run: an API or token fault, not a reason to disable them. For a local offline run, set ZIZMOR_OFFLINE=true' >&2
fi

exit "$status"
