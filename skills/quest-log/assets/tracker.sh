#!/usr/bin/env bash
# Tracker engine. Holds no tracker knowledge: it resolves a profile, dispatches
# to it, and lets the profile own every tracker-specific detail. Mirrors
# check-records.sh and its record-kind profiles.
set -euo pipefail

# ripgrep applies the contents of RIPGREP_CONFIG_PATH as arguments ahead of the
# ones passed below, so a personal ripgreprc would otherwise choose what this
# engine reads out of a file and out of a tracker's output. That output decides
# which writes happen, so it is not an input this may take from the environment.
unset RIPGREP_CONFIG_PATH

# The exit taxonomy every operation shares. Only EXIT_USAGE is referenced in
# this file; the rest are read by the profiles sourced below, which shellcheck
# cannot see from here — hence the per-line ignores.
EXIT_USAGE=1
# shellcheck disable=SC2034
EXIT_NOT_FOUND=2
# shellcheck disable=SC2034
EXIT_AUTH=3
# shellcheck disable=SC2034
EXIT_TRANSPORT=4
# shellcheck disable=SC2034
EXIT_PARTIAL=5

asset_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

# Structured errors are diagnostics, so they go to stderr; stdout carries
# success payloads only. A caller capturing stdout for data never receives an
# error object where it expected a result.
die() { # exit-code class message
	local code=$1 class=$2 message=$3
	jq -Rrn --arg class "$class" --arg message "$message" \
		'{error: $class, message: $message, partial: {}}' >&2
	exit "$code"
}

available_profiles() {
	local path name
	for path in "$asset_dir"/profiles/*.sh; do
		[[ -f $path ]] || continue
		name=${path##*/}
		printf '%s ' "${name%.sh}"
	done
}

# The repo's tracked AGENTS.md is the only resolution input. No environment
# variable participates: ambient per-shell state surviving into a resumed
# session would route a write to the wrong tracker silently, which the tracker
# abstraction record forbids.
resolve_tracker() {
	local root agents matches loose_status
	root=$(git rev-parse --show-toplevel 2>/dev/null) || {
		printf 'github\n'
		return 0
	}
	# The invoking repo's declaration, never --target's. --target selects an
	# object within the resolved tracker and never reaches a second one.
	agents="$root/AGENTS.md"
	[[ -f $agents ]] || {
		printf 'github\n'
		return 0
	}
	# \r? throughout: a checkout with CRLF endings would otherwise fail the
	# strict pattern, match the loose probe, and report a correct declaration
	# as malformed -- failing every operation in that clone.
	matches=$(rg -c '^issue-tracker: [a-z0-9-]+\r?$' "$agents" || true)
	matches=${matches:-0}
	if ((matches == 0)); then
		# A line that opens the declaration but fails the grammar is a typo,
		# not an absence. Treating it as absence is a wrong-tracker write.
		# rg exits 1 for "no match" and 2 or more for a fault it hit while
		# scanning -- an unreadable file, a bad encoding. A bare `if` here
		# reads a fault the same as "no declaration", silently changing which
		# tracker gets written to. Branch on the captured status instead.
		loose_status=0
		rg -q '^issue-tracker:' "$agents" || loose_status=$?
		case $loose_status in
		0)
			die "$EXIT_USAGE" usage \
				"malformed issue-tracker declaration in $agents"
			;;
		1) ;;
		*)
			die "$EXIT_USAGE" usage \
				"could not scan $agents for an issue-tracker declaration (rg exit $loose_status)"
			;;
		esac
		printf 'github\n'
		return 0
	fi
	if ((matches > 1)); then
		die "$EXIT_USAGE" usage \
			"$matches issue-tracker declarations in $agents; expected one"
	fi
	rg -o --replace '$1' '^issue-tracker: ([a-z0-9-]+)\r?$' "$agents" | tr -d '\r'
}

(($#)) || die "$EXIT_USAGE" usage 'no operation given'
operation=$1
shift

# Operations are hyphenated on the command line and underscored in function
# names; label-edit would otherwise dispatch to an illegal identifier.
operation_fn=${operation//-/_}

profile_name=
TRACKER_TARGET=
while (($#)); do
	case $1 in
	--profile)
		(($# >= 2)) || die "$EXIT_USAGE" usage '--profile needs a value'
		# The same grammar resolve_tracker pins the declaration to. The name is
		# concatenated into a path and sourced below, so an unconstrained flag
		# runs an arbitrary file in this process; checking it here rather than
		# after the loop also makes --profile '' the usage error it is instead
		# of a silent fall-through to the declaration.
		# Enumerated, not the range [a-z0-9-]: a bash bracket expression takes
		# its ranges from the locale's collation, so under en_US.UTF-8 [a-z]
		# admits accented letters while rg's ASCII-only class above does not.
		# The two routes would then accept different sets -- the divergence this
		# check exists to close. Do not "simplify" this back to a range.
		[[ $2 =~ ^[abcdefghijklmnopqrstuvwxyz0123456789-]+$ ]] ||
			die "$EXIT_USAGE" usage "profile name must match [a-z0-9-]+: $2"
		profile_name=$2
		shift 2
		;;
	--target)
		(($# >= 2)) || die "$EXIT_USAGE" usage '--target needs a value'
		TRACKER_TARGET=$2
		shift 2
		;;
	*) break ;;
	esac
done
export TRACKER_TARGET

[[ -n $profile_name ]] || profile_name=$(resolve_tracker)

# `resolve` is a pure query and prints whatever was declared. Profile existence
# is enforced at the operation boundary below, so a declaration naming an
# unimplemented tracker fails every operation with an actionable message rather
# than falling back to GitHub.
if [[ $operation == resolve ]]; then
	printf '%s\n' "$profile_name"
	exit 0
fi

profile_path="$asset_dir/profiles/$profile_name.sh"
[[ -f $profile_path ]] || die "$EXIT_USAGE" usage \
	"no profile for '$profile_name'; available: $(available_profiles)"

# shellcheck source=/dev/null
. "$profile_path"

if [[ $operation == declares ]]; then
	(($#)) || die "$EXIT_USAGE" usage 'declares needs an operation name'
	queried=${1//-/_}
	while IFS= read -r entry; do
		[[ -n $entry ]] || continue
		if [[ ${entry%%:*} == "$queried" ]]; then
			printf '%s\n' "${entry#*:}"
			exit 0
		fi
	done <<<"${PROFILE_DECLARES:-}"
	die "$EXIT_USAGE" usage \
		"profile '$profile_name' declares neither implemented nor degraded for '$1'"
fi

if ! declare -F "profile_$operation_fn" >/dev/null; then
	die "$EXIT_USAGE" usage \
		"profile '$profile_name' has no operation '$operation'"
fi

"profile_$operation_fn" "$@"
