#!/usr/bin/env bash
set -euo pipefail

# The plugin manifest declares a version, and a change bumps it.
#
# `version` in .claude-plugin/plugin.json pins the plugin: Claude Code resolves
# a plugin's version from plugin.json first, the marketplace entry second and
# the git SHA only when neither is set, then skips the update when the resolved
# version matches what is installed. So the field that satisfies the validator
# is also the field that stops delivering updates the moment someone forgets to
# change it -- silently, on every machine, with nothing to notice. ADR 0022
# adopts the version and this gate together for that reason; ADR 0001, which
# rejected a version outright, is the record it revises.
#
# Three rules:
#
#   1. .claude-plugin/plugin.json declares a version.
#   2. It is MAJOR.MINOR.PATCH -- plain decimal fields, no leading zeros, no
#      prerelease suffix and no build metadata. Narrower than semver on purpose:
#      rule 3 compares three integers, and semver's prerelease ordering is a
#      parser with no consumer here.
#   3. When the tree differs from BASE_SHA at all, that version is strictly
#      greater than the base ref's.
#
# Rule 3 says "at all", not "in the shipped paths", and the simplicity is the
# argument. Any allowlist of shipped paths fails in the silent direction -- a
# directory added later is outside the list, so its changes stop demanding a
# bump and stop reaching installed copies with nothing said. Requiring a bump
# for every change costs one line per pull request, restores exactly what ADR
# 0001 had (every merge to `main` is an update), and needs no list to keep.
#
# There is no version in .codex-plugin/plugin.json or in the marketplace entry.
# plugin.json outranks the marketplace entry in the harness's own resolution
# order, so a second copy could only ever disagree with the first.
#
# BASE_SHA governs rule 3, the same env var .github/scripts/check-records.sh
# reads and the workflow already sets. Unset outside CI it validates the
# declared version alone and says so; unset inside CI it is fatal. The boundary
# is real and deliberate: `just verify` run locally checks rules 1 and 2 only,
# so a forgotten bump is caught by the required check in CI rather than before
# the push. Resolving a base ref some second way here would be a second base-ref
# mechanism competing with the one the records gate already has.
#
# Exit 0 clean, 1 on a finding, 2 on a fault -- the contract
# check-skill-shape.sh, check-ripgrep-config.sh and check-public-safety.sh
# state. Exit 1 belongs to a content finding alone, so nothing that merely
# stopped the gate from running may borrow it.
#
# Bash 3.2 is the floor: no arrays, no mapfile, no associative arrays.
#
# Tested by check-plugin-version-test.sh beside it.

status=0

fault() {
	printf 'check-plugin-version: %s\n' "$1" >&2
	exit 2
}

report() {
	printf 'check-plugin-version: %s\n' "$1" >&2
	status=1
}

note() {
	printf 'check-plugin-version: %s\n' "$1"
}

root=${1:-}
if [ -z "$root" ]; then
	root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd) ||
		fault 'could not locate the repository root'
fi

manifest="$root/.claude-plugin/plugin.json"

# Matched with bash's own `[[ =~ ]]` rather than piped into grep. grep answers
# three ways -- 0 match, 1 no match, above 1 the scan could not run -- and a
# negated `if` collapses the third into the second, which here would read a
# failed match as a malformed version. `[[ =~ ]]` has no third answer, runs no
# process, and behaves identically on bash 3.2.57 (measured, macOS) and 5.x. The
# pattern stays unquoted at the call sites: quoting it makes it a literal.
SEMVER='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

# The version a manifest declares, into `manifest_version_value`, or empty when
# it declares none. jq is already a dependency of `just plugin-check`, which
# parses the same file.
#
# It reports through a variable and a status rather than printing, and its
# callers fault. `fault` inside a command substitution would end the subshell
# and let the caller carry on with an empty value, so an unparseable manifest
# would be reported as one declaring no version -- a second, factually wrong
# finding in place of the honest one, at exit 1 rather than 2.
#
# `tostring` rather than a string test: a version written as a JSON number or
# null still has to reach rule 2, which rejects it by shape. Reading it as empty
# instead would report "declares no version" against a manifest that declares
# one badly, and send the author looking for the wrong thing.
manifest_version_value=''
manifest_version_status=0
read_manifest_version() { # path -- 0 read, 1 the file would not parse
	local path=$1 jq_status=0
	manifest_version_value=''
	manifest_version_status=0
	manifest_version_value=$(jq -r 'if has("version") then (.version | tostring) else "" end' "$path") ||
		jq_status=$?
	if [ "$jq_status" -ne 0 ]; then
		manifest_version_value=''
		manifest_version_status=$jq_status
		return 1
	fi
	return 0
}

# 0 when left > right. Both arguments are MAJOR.MINOR.PATCH by the time this
# runs -- the tree's by rule 2, the base ref's by the fault below -- so `-gt`
# never sees a non-integer and no leading zero can reach it as an octal.
version_greater() { # left right
	local left=$1 right=$2 field left_field right_field
	for field in 1 2 3; do
		left_field=$(printf '%s' "$left" | cut -d. -f"$field")
		right_field=$(printf '%s' "$right" | cut -d. -f"$field")
		if [ "$left_field" -gt "$right_field" ]; then
			return 0
		fi
		if [ "$left_field" -lt "$right_field" ]; then
			return 1
		fi
	done
	return 1
}

# Rules 1 and 2.
[ -f "$manifest" ] || fault "no plugin manifest at $manifest"
read_manifest_version "$manifest" ||
	fault "could not parse $manifest (jq exit $manifest_version_status)"
tree_version=$manifest_version_value

if [ -z "$tree_version" ]; then
	report ".claude-plugin/plugin.json declares no version"
elif ! [[ $tree_version =~ $SEMVER ]]; then
	report ".claude-plugin/plugin.json declares version '$tree_version', which is not MAJOR.MINOR.PATCH"
fi

# Rule 3 compares the declared version against the base ref's. A version rules 1
# and 2 already rejected has nothing to compare, so the rule is undecided rather
# than passing, and the finding above is what the run reports.
if [ "$status" -ne 0 ]; then
	exit "$status"
fi

base=${BASE_SHA:-}
if [ -z "$base" ]; then
	if [ -n "${GITHUB_ACTIONS:-}" ]; then
		fault 'BASE_SHA is empty in CI — the bump rule cannot run'
	fi
	note "version $tree_version declared; BASE_SHA unset, so the bump rule did not run"
	exit 0
fi

git -C "$root" rev-parse --verify --quiet "$base^{commit}" >/dev/null ||
	fault "BASE_SHA '$base' is not a commit in this repository"

# `git diff --quiet` compares the working tree against the base commit and
# implies --exit-code: 0 no differences, 1 differences, above that a fault. It
# reports tracked paths only, so a change that exists solely as an untracked
# file demands no bump -- which is the right answer, since nothing uncommitted
# reaches the plugin cache either.
diff_status=0
git -C "$root" diff --quiet "$base" -- || diff_status=$?
case $diff_status in
0)
	note "version $tree_version declared; the tree matches $base, so no bump is due"
	exit 0
	;;
1) ;;
*) fault "could not diff the tree against $base (git exit $diff_status)" ;;
esac

# Absent from the base ref and unreadable at it are different answers, and
# `git show` alone conflates them: both exit 128. ls-tree separates them --
# empty output at exit 0 is "the path is not in that tree", a non-zero exit is a
# tree it could not read.
listing_status=0
listing=$(git -C "$root" ls-tree --name-only "$base" -- .claude-plugin/plugin.json) ||
	listing_status=$?
if [ "$listing_status" -ne 0 ]; then
	fault "could not read .claude-plugin/plugin.json at $base (git ls-tree exit $listing_status)"
fi

base_version=''
parse_status=0
if [ -n "$listing" ]; then
	blob=$(mktemp "${TMPDIR:-/tmp}/check-plugin-version.XXXXXX") ||
		fault 'could not create a scratch file'
	# Every branch removes the scratch file before it faults, and the removal's
	# own status is discarded: a file left behind is worth neither displacing the
	# verdict the run earned nor a second message contradicting the first.
	if ! git -C "$root" show "$base:.claude-plugin/plugin.json" >"$blob"; then
		rm -f -- "$blob"
		fault "could not read the base ref's copy of .claude-plugin/plugin.json at $base"
	fi
	read_manifest_version "$blob" || parse_status=$manifest_version_status
	base_version=$manifest_version_value
	rm -f -- "$blob"
	if [ "$parse_status" -ne 0 ]; then
		fault "could not parse .claude-plugin/plugin.json at $base (jq exit $parse_status)"
	fi
fi

# The base ref predates the version, which is the state every ref before ADR
# 0022 is in and the state the change adopting it starts from. Nothing to
# compare against, so any version rules 1 and 2 accepted satisfies rule 3.
if [ -z "$base_version" ]; then
	note "version $tree_version declared; $base declared none, so this is the change introducing one"
	exit 0
fi

# A malformed version in history cannot be compared and cannot be fixed by the
# change under review, so it is a fault rather than a finding. It is unreachable
# once this gate runs on every merge -- rule 2 refuses to let one land.
if ! [[ $base_version =~ $SEMVER ]]; then
	fault "the version at $base is '$base_version', which is not MAJOR.MINOR.PATCH — cannot compare"
fi

if version_greater "$tree_version" "$base_version"; then
	note "version $base_version -> $tree_version for a tree that differs from $base"
	exit 0
fi

report "the tree differs from $base but the version did not increase: $base_version at the base ref, $tree_version here"
exit "$status"
