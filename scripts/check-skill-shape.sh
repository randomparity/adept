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

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
status=0

report() {
	printf 'check-skill-shape: %s\n' "$1" >&2
	status=1
}

workspace="$(mktemp -d "${TMPDIR:-/tmp}/check-skill-shape.XXXXXX")"
trap 'rm -R "$workspace"' EXIT

names="$workspace/names"
find "$root/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort >"$names"

count="$(wc -l <"$names" | tr -d ' ')"
if [ "$count" -eq 0 ]; then
	printf 'check-skill-shape: no skills found under %s/skills\n' "$root" >&2
	exit 1
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
		printf 'check-skill-shape: reading %s failed (rg exit %s)\n' "$skill_file" "$name_status" >&2
		exit 1
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
	printf 'check-skill-shape: reading the reserved-name list failed (exit %s)\n' "$reserved_status" >&2
	exit 1
fi
while IFS= read -r reserved; do
	if grep -qxF -- "$reserved" "$names"; then
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
	printf 'check-skill-shape: scanning invocations failed (rg exit %s)\n' "$refs_status" >&2
	exit 1
fi
# shellcheck disable=SC2016 # the $ is a literal to strip, not an expansion
sed 's/.*`\$//;s/`//' "$workspace/raw" | sort -u >"$workspace/refs"
while IFS= read -r ref; do
	if ! grep -qxF -- "$ref" "$names"; then
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
	printf 'check-skill-shape: scanning reference links failed (rg exit %s)\n' "$links_status" >&2
	exit 1
fi
sort -u "$workspace/rawlinks" >"$workspace/links"
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
		printf 'check-skill-shape: scanning docs/cheatsheet.md failed (rg exit %s)\n' \
			"$coverage_status" >&2
		exit 1
	fi
	if [ "$coverage_status" -eq 1 ]; then
		report "$name: not referenced in docs/cheatsheet.md"
	fi
done <"$names"

if [ "$status" -eq 0 ]; then
	printf 'check-skill-shape: %s skills, all rules pass\n' "$count"
fi
exit "$status"
