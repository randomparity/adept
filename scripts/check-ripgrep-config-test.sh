#!/usr/bin/env bash
set -euo pipefail

# Fixture suites for scripts/check-ripgrep-config.sh. Each fixture is a git
# repository holding a copy of scripts/list-shell-sources.sh — the gate's only
# discovery input — plus the shell sources under test, so the fixtures exercise
# the same tracked-file walk the repository uses without depending on this
# repository's own contents.
#
# The suite inherits git-fixture isolation: a caller's GIT_DIR or
# GIT_INDEX_FILE would otherwise reach the fixture's `git ls-files` and make
# discovery report this repository instead.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/test-fixture-helpers.sh
. "$script_dir/test-fixture-helpers.sh"

clear_git_env
fixture_init ripgrep-config-test

gate=$script_dir/check-ripgrep-config.sh
lister=$script_dir/list-shell-sources.sh

new_fixture() { # name
	local root=$SCRATCH/$1
	mkdir -p "$root/scripts"
	cp "$lister" "$root/scripts/list-shell-sources.sh"
	chmod +x "$root/scripts/list-shell-sources.sh"
	git init -q -b main "$root"
	git -C "$root" config user.name 'Fixture Developer'
	git -C "$root" config user.email fixture@example.invalid
	printf '%s\n' "$root"
}

write_source() { # root relative-path body
	local root=$1 path=$2 body=$3
	mkdir -p "$(dirname "$root/$path")"
	printf '%s\n' "$body" >"$root/$path"
	chmod +x "$root/$path"
}

track() { # root
	git -C "$1" add -A
}

assert_passes() { # name root
	local name=$1 root=$2 output
	if ! output=$("$gate" "$root" 2>&1); then
		fail "$name: expected pass, got: $output"
	fi
}

assert_fails() { # name root expected-fragment
	local name=$1 root=$2 expected=$3 output status=0
	output=$("$gate" "$root" 2>&1) || status=$?
	[[ $status -eq 1 ]] || fail "$name: expected exit 1, got $status: $output"
	[[ $output == *"$expected"* ]] ||
		fail "$name: expected '$expected' in: $output"
}

# `unset RIPGREP_CONFIG_PATH` alone at column 0 covers every ripgrep the file
# runs, including calls added later.
unset_root=$(new_fixture unset)
write_source "$unset_root" scripts/scan.sh '#!/usr/bin/env bash
set -euo pipefail

unset RIPGREP_CONFIG_PATH

rg -n pattern .
rg --files-with-matches other .'
track "$unset_root"
assert_passes 'file-scope unset' "$unset_root"

# --no-config on every invocation is the other accepted form.
noconfig_root=$(new_fixture noconfig)
write_source "$noconfig_root" scripts/scan.sh '#!/usr/bin/env bash
set -euo pipefail

rg --no-config -n pattern .
if rg --no-config -q other .; then
	printf "found\n"
fi'
track "$noconfig_root"
assert_passes 'per-call --no-config' "$noconfig_root"

# The finding this gate exists for: a scan whose flags a personal ripgreprc
# still chooses. Removing the guard from the verify chain is what this reddens.
bare_root=$(new_fixture bare)
write_source "$bare_root" scripts/scan.sh '#!/usr/bin/env bash
set -euo pipefail

rg -n pattern .'
track "$bare_root"
assert_fails 'unneutralised invocation' "$bare_root" \
	'scripts/scan.sh:4: runs rg without unset RIPGREP_CONFIG_PATH or --no-config'

# Neutralising one source says nothing about the next one; the gate answers per
# file, not per repository.
mixed_root=$(new_fixture mixed)
write_source "$mixed_root" scripts/clean.sh '#!/usr/bin/env bash
unset RIPGREP_CONFIG_PATH
rg -n pattern .'
write_source "$mixed_root" scripts/exposed.sh '#!/usr/bin/env bash
rg -n pattern .'
track "$mixed_root"
assert_fails 'one neutralised source, one not' "$mixed_root" \
	'scripts/exposed.sh:2: runs rg'

# An unset inside a branch may never run, so it does not neutralise the file.
# Requiring column 0 is what makes the statement answerable without tracking
# blocks.
indented_root=$(new_fixture indented)
# shellcheck disable=SC2016 # fixture bodies are shell text the gate reads, not
# text this suite expands; every $ below belongs to the fixture.
write_source "$indented_root" scripts/scan.sh '#!/usr/bin/env bash
if [[ -n ${CI:-} ]]; then
	unset RIPGREP_CONFIG_PATH
fi
rg -n pattern .'
track "$indented_root"
assert_fails 'unset inside a branch' "$indented_root" 'scripts/scan.sh:5: runs rg'

# A ripgrep the file never runs is not one to neutralise. Flagging these would
# be answered by an exemption list, which is the thing that rots.
mention_root=$(new_fixture mention)
# shellcheck disable=SC2016 # as above: fixture text, expanded by nothing here.
write_source "$mention_root" scripts/mentions.sh '#!/usr/bin/env bash
# rg -n pattern . is how the old gate scanned.
printf "%s\n" "rg -n pattern ."
message="(rg exit $?)"
cat <<INSTRUCTIONS
rg -n pattern .
INSTRUCTIONS
printf "%s\n" "$message"'
track "$mention_root"
assert_passes 'mentions in comments, strings and here-documents' "$mention_root"

# A call reached through a pipeline, a command substitution or a continued
# logical line is still a call.
nested_root=$(new_fixture nested)
# shellcheck disable=SC2016 # as above: fixture text, expanded by nothing here.
write_source "$nested_root" scripts/nested.sh '#!/usr/bin/env bash
count=$(rg --count-matches pattern . | wc -l)
printf "%s\n" "$count"'
track "$nested_root"
assert_fails 'call inside a command substitution' "$nested_root" \
	'scripts/nested.sh:2: runs rg'

continued_root=$(new_fixture continued)
write_source "$continued_root" scripts/continued.sh '#!/usr/bin/env bash
rg \
	-n pattern .'
track "$continued_root"
assert_fails 'call across a continued line' "$continued_root" \
	'scripts/continued.sh:2: runs rg'

# An unset below the call it is meant to cover neutralises nothing, so only the
# calls after it are cleared. The call above is still reported.
late_root=$(new_fixture late)
write_source "$late_root" scripts/scan.sh '#!/usr/bin/env bash
rg -n early .
unset RIPGREP_CONFIG_PATH
rg -n late .'
track "$late_root"
assert_fails 'unset below the call' "$late_root" 'scripts/scan.sh:2: runs rg'

# Wrappers that take flags of their own still front an invocation. These are the
# idiomatic shapes a future gate is most likely to reach for.
for wrapper in 'xargs -0 rg -n pattern' 'timeout 5 rg -n pattern .' \
	'sudo -u nobody rg -n pattern .' 'env rg -n pattern .' \
	'nice -n 5 rg -n pattern .' '/usr/bin/rg -n pattern .' \
	'find . -exec rg -n pattern {} +'; do
	name=${wrapper%% *}
	wrapped_root=$(new_fixture "wrapped-$(printf '%s' "$name" | tr -c 'a-z0-9' '-')")
	write_source "$wrapped_root" scripts/scan.sh "#!/usr/bin/env bash
$wrapper"
	track "$wrapped_root"
	assert_fails "wrapper: $name" "$wrapped_root" 'scripts/scan.sh:2: runs rg'
done

# The same shapes are accepted once neutralised, so the wrapper handling reports
# exposure rather than merely reporting the wrapper.
wrapped_ok_root=$(new_fixture wrapped-ok)
write_source "$wrapped_ok_root" scripts/scan.sh '#!/usr/bin/env bash
unset RIPGREP_CONFIG_PATH
xargs -0 rg -n pattern
timeout 5 rg -n pattern .
find . -exec rg -n pattern {} +'
track "$wrapped_ok_root"
assert_passes 'neutralised wrappers' "$wrapped_ok_root"

# Discovery that cannot run is a fault, not a clean verdict: a gate that reports
# ok on an empty source list is the silent miss this gate exists to prevent.
faultless_root=$SCRATCH/no-lister
mkdir -p "$faultless_root"
status=0
output=$("$gate" "$faultless_root" 2>&1) || status=$?
[[ $status -eq 2 ]] || fail "missing lister: expected exit 2, got $status: $output"
[[ $output == *'source lister is missing'* ]] ||
	fail "missing lister: unexpected message: $output"

printf 'ripgrep-config-test: pass\n'
