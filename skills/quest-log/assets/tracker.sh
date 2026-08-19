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
# shellcheck disable=SC2034
EXIT_CONFLICT=6

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
#
# `git rev-parse --show-toplevel` exits 128 for "there is no repository at or
# above here" and for every refusal alike: a dubious-ownership refusal under a
# bind mount, a sudo run or a container UID mismatch, a bare repository, a
# GIT_DIR pointing at nothing, a .git git cannot read or whose pointer it cannot
# follow, a working directory git cannot read. Returning `github` on all of them
# converted a probe that could not answer into a resolution and then wrote
# against it -- the collapse ADR 0005 decision 1 forbids and the rg calls below
# already close.
#
# The status does not separate the causes, and neither does
# `--is-inside-work-tree`: measured across that whole set it answers 128 for
# every case but the bare repository, where it prints `false` at exit 0. Four
# probes do separate them, and none reads git's prose, which is git's to reword
# and, on a build with NLS, to translate:
#
#   * git resolves where it is before it looks for a repository, and it fails
#     there in two ways that differ by platform. On macOS getcwd walks the tree
#     and needs read permission on every parent, so an unreadable parent makes
#     getcwd itself fail and git reports "Unable to read current working
#     directory". On glibc getcwd answers from the kernel and succeeds, and the
#     stat git does next is what hits the unreadable parent: "failed to stat".
#     Both are "nothing was searched", so both are probed -- ask for the name,
#     then ask whether the name can be reached. Neither `pwd -P` alone nor the
#     reachability test alone covers both platforms; measured on macOS 15.6 and
#     on Ubuntu 24.04 with git 2.43.0.
#   * 128 is the status git exits with when it ran and declined, including for
#     an option it does not know. Any other status -- 127 for no git on PATH --
#     is a probe that never ran and is never evidence about a repository.
#   * `-c safe.directory='*'` suppresses the ownership check and nothing else --
#     safe.directory is honoured in protected configuration, which includes the
#     -c command scope. A retry that succeeds where the plain probe failed
#     therefore isolates the ownership refusal: the repository is there and git
#     declined it. Its root names the remedy and never resolves a tracker; a
#     repository git refuses to trust is not one to read a declaration out of.
#     The retry is a `rev-parse --show-toplevel`, which reads that repository's
#     config but runs no hook, alias, pager, editor or fsmonitor -- the vectors
#     the ownership check exists for.
#   * GIT_DIR or GIT_WORK_TREE set means git was told where the repository is.
#     A probe that failed anyway says that named repository is unusable, never
#     that none exists. This is the one place ambient state is read, and it
#     decides a fault rather than a resolution -- the header's rule intact.
#
# The remedy is reconstructed rather than relayed. verify-push.sh and
# check-records.sh leave git's own line standing because their channel is plain
# text; here stderr carries one JSON error object a caller parses, and git's
# line would corrupt it.
#
# What still reaches the fallback is git's own negative discovery answer -- no
# repository -- and the two cases it reports identically as "not a git
# repository": a .git it cannot read, and a .git whose pointer it cannot follow.
# Both leave a readable worktree whose declaration is then missed. Separating
# them from a true absence means reimplementing repository discovery, so they
# remain a silent fallback -- stated here rather than claimed closed. A bare
# repository lands here too, and correctly: it has no worktree, so no AGENTS.md
# and nothing to declare.
resolve_tracker() {
	local root agents matches loose_status count_status=0
	local root_status=0 refused_root refused_status=0 cwd
	root=$(git rev-parse --show-toplevel 2>/dev/null) || root_status=$?
	if ((root_status != 0)); then
		cwd=$(pwd -P 2>/dev/null) || cwd=
		if [[ -z $cwd || ! -d $cwd ]]; then
			die "$EXIT_USAGE" usage \
				"could not resolve the repository root: the working directory could not be read (git rev-parse --show-toplevel exit $root_status)"
		fi
		if ((root_status != 128)); then
			die "$EXIT_USAGE" usage \
				"could not resolve the repository root: the probe did not run (git rev-parse --show-toplevel exit $root_status)"
		fi
		refused_root=$(git rev-parse --show-toplevel 2>/dev/null) ||
			refused_status=$?
		if ((refused_status == 0)); then
			die "$EXIT_USAGE" usage \
				"could not resolve the repository root: git refused $refused_root as dubiously owned (git rev-parse --show-toplevel exit $root_status); remedy: git config --global --add safe.directory $refused_root"
		fi
		if [[ -n ${GIT_DIR:-} || -n ${GIT_WORK_TREE:-} ]]; then
			die "$EXIT_USAGE" usage \
				"could not resolve the repository root: GIT_DIR or GIT_WORK_TREE names a repository git could not use (git rev-parse --show-toplevel exit $root_status)"
		fi
		printf 'github\n'
		return 0
	fi
	# Exit 0 with empty output is the same unresolved root wearing a success
	# status: `$root/AGENTS.md` becomes `/AGENTS.md`, so the read below leaves
	# this repository entirely. No real rev-parse was found to answer this way,
	# so this guards a substituted or future git rather than a demonstrated path.
	[[ -n $root ]] || die "$EXIT_USAGE" usage \
		'could not resolve the repository root: git reported an empty repository root (git rev-parse --show-toplevel exit 0)'
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
	# rg exits 1 for "no match" and 2 or more for a fault it hit while scanning.
	# `|| true` folded the two together, collapsing matches to 0 and routing the
	# run into the no-declaration branch -- a wrong-tracker write decided by a
	# scan that never ran. That the loose probe below happens to catch the same
	# file's fault first is a coupling between two independently editable lines,
	# not a guarantee this line can rely on.
	matches=$(rg -c '^issue-tracker: [a-z0-9-]+\r?$' "$agents") || count_status=$?
	case $count_status in
	0 | 1) ;;
	*)
		die "$EXIT_USAGE" usage \
			"could not scan $agents for issue-tracker declarations (rg exit $count_status)"
		;;
	esac
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
