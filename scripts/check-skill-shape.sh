#!/usr/bin/env bash
set -euo pipefail

# Structural rules only. Rule 4 of the rewrite spec forbids any gate that
# asserts on prose, so nothing here reads a document's wording -- only whether
# the pieces that must exist do, and whether names resolve.
#
# rg gets --no-config throughout: it reads RIPGREP_CONFIG_PATH ahead of its own
# arguments, so a developer's personal ripgreprc would otherwise steer a gate's
# verdict.
#
# Bash 3.2 is the floor. macOS ships 3.2.57 and no script in this repo uses a
# bash 4 feature, so there is no mapfile and no associative array here.
# Membership is a sorted file plus a fixed whole-line grep.
#
# Every scan captures rg's status explicitly rather than trailing `|| true`.
# rg exits 1 for "no matches" and >1 for a real failure; collapsing those makes
# a scan that could not run read as a scan that found nothing.
#
# Exit 0 clean, 1 on a finding naming a skill, 2 on a fault -- the contract
# check-ripgrep-config.sh and check-public-safety.sh already state. Exit 1
# belongs to a content finding alone, so nothing that merely stopped the gate
# from running may borrow it: a gate that goes red on a status no message
# accounts for leaves the operator hunting a violation that does not exist.

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
status=0

fault() {
	printf 'check-skill-shape: %s\n' "$1" >&2
	exit 2
}

report() {
	printf 'check-skill-shape: %s\n' "$1" >&2
	status=1
}

# grep answers three ways for the same reason rg does -- 0 match, 1 no match,
# >1 the scan could not run -- and both membership loops below would otherwise
# collapse the third into the second, in opposite directions: rule 3 would read
# a failed scan as "no collision" and drop a real finding, rule 4 as "no such
# skill" and invent one. $names is set before either caller runs.
name_listed() { # name -- 0 listed, 1 not listed, faults when the scan fails
	local scan_status=0
	grep -qxF -- "$1" "$names" || scan_status=$?
	if [ "$scan_status" -gt 1 ]; then
		fault "membership scan of $names failed (grep exit $scan_status)"
	fi
	return "$scan_status"
}

workspace="$(mktemp -d "${TMPDIR:-/tmp}/check-skill-shape.XXXXXX")" ||
	fault 'could not create a scratch directory'

# Under `set -e` an EXIT trap's non-zero return becomes the shell's exit status,
# so the bare `trap 'rm -R "$workspace"' EXIT` this replaces turned a scratch
# directory it could not remove into the finding status. The removal reports
# itself on the fault status instead, and names what it left behind -- nothing
# else will, and the path is the only way to reclaim it.
#
# shellcheck disable=SC2329 # run by the EXIT trap; 0.11 stops tracing at the terminal exit
cleanup() {
	local exit_status=$?
	if rm -R -- "$workspace"; then
		exit "$exit_status"
	fi
	printf 'check-skill-shape: retained scratch path: %s\n' "$workspace" >&2
	if [ "$exit_status" -eq 0 ]; then
		exit 2
	fi
	exit "$exit_status"
}
trap cleanup EXIT

names="$workspace/names"
find "$root/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; |
	sort >"$names" || fault "could not enumerate $root/skills"

count="$(wc -l <"$names" | tr -d ' ')" || fault "could not count $names"
if [ "$count" -eq 0 ]; then
	fault "no skills found under $root/skills"
fi

# Rule 1: every skill directory has a SKILL.md.
# Rule 2: its `name:` frontmatter matches the directory name.
while IFS= read -r name; do
	skill_file="$root/skills/$name/SKILL.md"
	if [ ! -f "$skill_file" ]; then
		report "$name: no SKILL.md"
		continue
	fi
	declared=''
	name_status=0
	# -r is --replace, not recursive: capture the value and emit only it. \K is
	# avoided deliberately -- it is PCRE2-only and needs rg -P, which not every
	# rg build carries.
	declared="$(rg --no-config -m1 -N -o -r '$1' '^name: *(\S+)' "$skill_file")" || name_status=$?
	if [ "$name_status" -gt 1 ]; then
		fault "reading $skill_file failed (rg exit $name_status)"
	fi
	if [ -z "$declared" ]; then
		report "$name: SKILL.md has no name: frontmatter"
	elif [ "$declared" != "$name" ]; then
		report "$name: SKILL.md declares name: $declared"
	fi
done <"$names"

# Rule 3: no skill name collides with a harness-reserved name.
reserved_status=0
rg --no-config -v '^#|^$' "$root/scripts/reserved-skill-names.txt" |
	sort -u >"$workspace/reserved" || reserved_status=$?
if [ "$reserved_status" -gt 1 ]; then
	fault "reading the reserved-name list failed (exit $reserved_status)"
fi
while IFS= read -r reserved; do
	if name_listed "$reserved"; then
		report "$reserved: collides with a reserved harness name"
	fi
done <"$workspace/reserved"

# Rule 4: every `$invocation` resolves to a skill that exists. This is what
# makes the rename sweep safe -- a stale $name is otherwise silent until
# someone runs it.
#
# Only the backticked form is scanned. It is the convention in 244 of 293
# references, and the bare form collides with ordinary shell variables in
# fenced examples ($root, $path, $err, $c), which would make this gate cry wolf
# on every skill that documents a command. Measured against the current tree,
# the backticked rule has zero false positives.
refs_status=0
rg --no-config -o -N '`\$[a-z][a-z0-9-]*`' "$root"/skills/*/SKILL.md \
	>"$workspace/raw" || refs_status=$?
if [ "$refs_status" -gt 1 ]; then
	fault "scanning invocations failed (rg exit $refs_status)"
fi
# shellcheck disable=SC2016 # the $ is a literal to strip, not an expansion
sed 's/.*`\$//;s/`//' "$workspace/raw" | sort -u >"$workspace/refs" ||
	fault 'could not collate the invocation list'
while IFS= read -r ref; do
	if ! name_listed "$ref"; then
		report "\$$ref is invoked but no such skill exists"
	fi
done <"$workspace/refs"

# Rule 5: every link into references/ resolves to a file that exists. New
# artifact class, same failure mode as rule 4 -- a reference is consulted by
# path rather than invoked, so a stale link is silent until someone follows it.
# Paths are relative to the linking SKILL.md, which is what gets checked.
#
# --no-filename matters here: rg prefixes `path:` when given several files, and
# -N suppresses only the line number. Rule 4 above is immune because its sed
# strips everything up to the backtick; this rule compares the match directly.
links_status=0
rg --no-config -o -N --no-filename '\.\./\.\./references/[a-z0-9-]+\.md' "$root"/skills/*/SKILL.md \
	>"$workspace/rawlinks" || links_status=$?
if [ "$links_status" -gt 1 ]; then
	fault "scanning reference links failed (rg exit $links_status)"
fi
sort -u "$workspace/rawlinks" >"$workspace/links" ||
	fault 'could not collate the reference-link list'
while IFS= read -r rel; do
	[ -n "$rel" ] || continue
	# Resolve the link lexically rather than handing `..` to the kernel: only
	# skills/*/SKILL.md is scanned and the pattern is anchored to ../../, so
	# every match denotes $root/references/<file>.md. Testing a literal
	# "$root/skills/x/$rel" instead would fail on every link, because path
	# lookup walks the nonexistent "x" before it ever reaches the "..".
	if [ ! -f "$root/${rel#../../}" ]; then
		report "reference link does not resolve: $rel"
	fi
done <"$workspace/links"

# Rule 6: every skill name is referenced in docs/cheatsheet.md, as a
# backtick-wrapped token. This is what makes a skill added without
# documentation fail fast instead of going unnoticed -- the same
# inventory-vs-reference shape as rule 4, pointed at docs/cheatsheet.md
# instead of at skills/*/SKILL.md. Membership only, no wording or
# table-shape assertion.
while IFS= read -r name; do
	coverage_status=0
	rg --no-config -qF -- "\`$name\`" "$root/docs/cheatsheet.md" || coverage_status=$?
	if [ "$coverage_status" -gt 1 ]; then
		fault "scanning docs/cheatsheet.md failed (rg exit $coverage_status)"
	fi
	if [ "$coverage_status" -eq 1 ]; then
		report "$name: not referenced in docs/cheatsheet.md"
	fi
done <"$names"

if [ "$status" -eq 0 ]; then
	printf 'check-skill-shape: %s skills, all rules pass\n' "$count"
fi
exit "$status"
