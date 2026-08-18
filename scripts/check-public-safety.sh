#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ripgrep applies the contents of RIPGREP_CONFIG_PATH as arguments ahead of the
# ones below, so without this every flag this scan does not set is chosen by
# whoever set that variable -- a personal ripgreprc, a shell profile, a CI
# environment. --fixed-strings alone turns these patterns into literals that
# match nothing and this gate exits 0 on a leaking tree. Unsetting once covers
# every ripgrep this file runs, including one added later.
unset RIPGREP_CONFIG_PATH

if ! command -v rg >/dev/null 2>&1; then
	echo "public-safety: rg is required" >&2
	exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
	echo "public-safety: jq is required" >&2
	exit 2
fi

if (($# > 0)); then
	scan_paths=("$@")
else
	scan_paths=("$ROOT")
fi

denied_patterns=(
	'/Users/[[:alnum:]_][[:alnum:]_.-]+'
	'/home/[[:alnum:]_][[:alnum:]_.-]+'
	'/Volumes/[[:alnum:]_][^`)]*'
	'pdx\.drc'
	'ts\.drc'
	'192\.168\.'
	'(^|[^[:alnum:]])10\.[0-9]{1,3}\.'
	'172\.(1[6-9]|2[0-9]|3[0-1])\.'
	'[[:alnum:]-]+\.atlassian\.net'
	'Basic[[:space:]]+[A-Za-z0-9+/=]{12,}'
	'ATATT[A-Za-z0-9_=.-]{20,}'
	"ATLASSIAN[A-Z0-9_]*['\"]?[[:space:]]*[=:][[:space:]]*['\"]?[A-Za-z0-9+/]{20,}"
	'gh[pousr]_[A-Za-z0-9_]{20,}'
	'sk-[A-Za-z0-9]{20,}'
	'AKIA[0-9A-Z]{16}'
	'xox[baprs]-[A-Za-z0-9-]{20,}'
)

# ripgrep applies .gitignore, .ignore and .rgignore while walking, and it applies
# them to tracked files too. `git add -f` on an ignored path produces a file that
# is in the index -- it ships to everyone who clones this public repo -- and that
# the walk below never opens, so the gate prints nothing and exits 0. That is a
# false green on exactly the content this gate exists to catch.
#
# --no-ignore would close it by disabling ignore handling wholesale, but it also
# pulls in ignored files that are *untracked* and therefore never ship — the
# agent scratch trees (`.agent/`, `CLAUDE.local.md`) whose whole purpose is to
# hold host-specific identity out of the tracked tree. Turning those red would
# fail every local `just verify` and every commit through the pre-commit hook.
#
# Naming the tracked files instead scans what ships and nothing else: ripgrep
# searches a path given explicitly on the command line whatever the ignore rules
# say, so this covers every ignore mechanism rather than .gitignore alone. On a
# tree with nothing hidden it is the same set the walk already covers.
#
# `git ls-files` reports the index, so a tracked file deleted from the worktree
# and not yet staged names a path with nothing behind it. There is no content to
# scan there, and the status check below would otherwise turn every such tree
# into a fault, so those paths are dropped before the scan rather than after.
#
# The test is -f, not -e: the walk only ever opened regular files, and naming a
# path explicitly makes ripgrep open whatever is there. A tracked path replaced
# by a FIFO blocks the scan forever with no writer, which is a burned CI timeout
# rather than a wrong answer, but the walk-only shape never had it. -f drops a
# dangling symlink and a directory substitution in the same breath.
#
# The listing is captured to a file rather than read from a process
# substitution. `while ... done < <(git ls-files -z)` reports the loop's status
# and never git's, so a listing that emitted some paths and then died left this
# gate scanning a short set and reporting a pass -- and the `2>/dev/null` that
# call carried removed the one thing on stderr that would have said why. Both
# halves are what ADR 0005 rules out; list-shell-sources.sh captures its own
# walk for the same reason.
#
# Any non-zero status is a fault. `git ls-files` exits 128 both for a directory
# that is no repository and for a repository it could not read, so no branch
# can tell them apart, and stopping is the only reading that cannot go green
# over content it never listed. That makes "a directory handed to this gate is
# inside a git worktree" part of the contract, which is what the gate is for:
# the tracked set is the set that ships.
#
# A scan path that is not a directory is not asked. A regular file -- the shape
# skills/quest/scripts/publish-forge-review passes -- already names itself on
# the command line, so ripgrep opens it whatever the ignore rules say and there
# is nothing to enumerate; `git -C` on it could only ever fail. A path that is
# not there at all reaches ripgrep, which faults on it below.
#
# An empty listing under a zero status is a legitimate answer, not a fault.
# Unlike `git rev-parse --local-env-vars`, which always names at least GIT_DIR,
# this listing has a real empty case: a checkout subdirectory with nothing
# tracked under it, and a repository before its first `git add`. The walk still
# covers the tree in both. There is no count floor to fall back on either --
# the gate takes arbitrary scan paths, so unlike list-shell-sources.sh, which
# runs only at this repository's root and can therefore treat an empty subset
# as broken discovery, this site has no scope over which a floor would hold.
#
# What that decision does not establish, stated rather than implied: an empty
# listing means the *index* has no entries under the path, and the index is not
# what ships. A worktree whose index was removed -- the documented recovery for
# a stuck index.lock, and the residue of an interrupted operation -- answers
# empty at exit 0 while HEAD still carries the content, and the gate then falls
# back to the ignore-respecting walk that cannot see a `git add -f`'d ignored
# file. No status check reaches that: git ran and answered truthfully, so it is
# not the ADR 0005 shape. Choosing the enumeration's source is issue #150, and
# issue #147 is a second route to the same empty result. Both predate this
# change and reproduce identically on the pre-fix gate.
# The scratch file is created at the first directory scan path rather than up
# front, for the reason the git guard below gives: a regular-file scan needs no
# listing, so a temp directory it never writes to must not be able to fail it.
# The distinction is invisible here -- bare mktemp on macOS resolves through the
# per-user temp directory and ignores TMPDIR -- and live on Linux, where mktemp
# honours TMPDIR and fails when it is missing or read-only. That is the CI leg.
tracked_listing=''
# An `if` rather than `[ -n ... ] && rm`: these scripts run under `set -e`,
# where an EXIT trap's non-zero return becomes the exit status, so the
# short-circuit form would redden every clean run that never made the file. A
# failed removal still reddens, which is the existing behaviour.
trap 'if [ -n "$tracked_listing" ]; then rm -f "$tracked_listing"; fi' EXIT

scan_targets=("${scan_paths[@]}")
for scan_path in "${scan_paths[@]}"; do
	[[ -d "$scan_path" ]] || continue
	# git is required to enumerate a directory, and only a directory. The test
	# sits here rather than beside the rg and jq preflights because a
	# regular-file target is never enumerated and genuinely does not need git:
	# skills/quest/scripts/publish-forge-review scans one, discards stderr and
	# reports every non-zero status as a leaking body, so an unconditional
	# preflight would tell that operator their publication leaked content when
	# the real answer is a host missing a tool that scan never used.
	if ! command -v git >/dev/null 2>&1; then
		echo "public-safety: git is required to scan a directory" >&2
		exit 2
	fi
	if [ -z "$tracked_listing" ]; then
		tracked_listing=$(mktemp) || {
			echo "public-safety: could not create a scratch file for the tracked listing" >&2
			exit 2
		}
	fi
	listing_status=0
	git -C "$scan_path" ls-files -z >"$tracked_listing" || listing_status=$?
	if [ "$listing_status" -ne 0 ]; then
		printf 'public-safety: could not list the tracked files under %s (git ls-files exit %s)\n' \
			"$scan_path" "$listing_status" >&2
		exit 2
	fi
	while IFS= read -r -d '' tracked; do
		[[ -f "$scan_path/$tracked" ]] || continue
		scan_targets+=("$scan_path/$tracked")
	done <"$tracked_listing"
done

# Two names under /home are not people. GitHub's runner images publish
# /home/runner as the workspace root and install Homebrew to /home/linuxbrew,
# and the ubuntu image's own documentation tells you to run
# `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"` because Homebrew is
# not on PATH there. A workflow or design doc that quotes either published
# constant is not leaking anyone's home directory, and a gate that reddens on it
# teaches people to route around the gate.
#
# The exception applies only to exact submatches. A line that names
# /home/runner and a real home directory or a token still carries a non-exempt
# submatch and is reported, while a person named `runnerbee` is never exempt.
public_home_match='^/home/(runner|linuxbrew)$'

status=0
# --text: ripgrep judges a file binary on one NUL byte and skips it while
# walking a directory, so a single NUL anywhere in a file hides every secret in
# it. --encoding none: a leading \xFF\xFE makes ripgrep transcode the file as
# UTF-16, garbling ASCII so these ASCII patterns cannot match. Both are one line
# of file content to trigger, and this gate's subject is content someone may be
# trying to get past it. The trade in --encoding none -- a file genuinely stored
# as UTF-16 stops being scanned -- is accepted: no tracked file here is one, and
# a documented five-byte bypass is the worse half.
#
# ripgrep exits 2 for a scan it could not complete -- an unreadable file, a path
# it was handed that it cannot open, an argument list too long for exec -- and it
# does so even when it also found matches. Read as a boolean, that is "no match":
# the gate would print a secret to stdout and still exit 0. A bare `if` here is
# what made a plain `rm` of any tracked file turn this gate green. Every gate in
# this repo branches on the status for the same reason: 0 is a finding, 1 is
# clean, anything else is a fault that stops the run.
for pattern in "${denied_patterns[@]}"; do
	rg_status=0
	matches=$(rg --json --hidden --text --encoding none \
		--glob '!.git' --glob '!.git/**' "$pattern" "${scan_targets[@]}") ||
		rg_status=$?
	case $rg_status in
	0)
		# The walk and the explicit paths overlap on every tracked file no
		# ignore rule hides, so each match arrives twice. Structured records keep
		# arbitrary filename bytes out of the content decision and preserve the
		# exact path, line and content in the finding.
		filter_status=0
		matches=$(printf '%s\n' "$matches" |
			jq -c --arg allowed "$public_home_match" '
				select(.type == "match")
				| select(any(.data.submatches[];
					((.match.text // (.match.bytes | @base64d))
					| test($allowed) | not)))
				| .data
				| {path, line_number, lines}' |
			awk '!seen[$0]++') || filter_status=$?
		if [ "$filter_status" -ne 0 ]; then
			printf 'public-safety: jq could not filter ripgrep output (exit %s)\n' \
				"$filter_status" >&2
			exit 2
		fi
		[ -n "$matches" ] || continue
		printf '%s\n' "$matches"
		printf 'public-safety: denied pattern matched: %s\n' "$pattern" >&2
		status=1
		;;
	1) ;;
	*)
		printf 'public-safety: ripgrep could not complete the scan (exit %s); pattern: %s\n' \
			"$rg_status" "$pattern" >&2
		exit 2
		;;
	esac
done

exit "$status"
