#!/usr/bin/env bash
set -euo pipefail

# Fixture suite for the Justfile test recipe's modes: quiet default, verbose,
# pattern selection with dedupe, and usage errors. Each case builds a disposable
# git repository holding fake *-test.sh suites and invokes this repository's own
# Justfile against it, so discovery, capture, replay, and exit semantics are
# exercised end to end without touching the real suites.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/test-fixture-helpers.sh
. "$script_dir/test-fixture-helpers.sh"

clear_git_env
fixture_init test-recipe-test

justfile="$(git rev-parse --show-toplevel)/Justfile"

run_stdout=''
run_stderr=''
run_status=0

run_recipe() { # root [args...]
	local root=$1
	shift
	local err_path="$SCRATCH/stderr.$$.$RANDOM"
	run_status=0
	run_stdout=$(just --justfile "$justfile" --working-directory "$root" test "$@" 2>"$err_path") || run_status=$?
	run_stderr=$(cat "$err_path")
	rm -f -- "$err_path"
}

write_suite() { # path exit-status name
	cat >"$1" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '  ok   assertion in $3\n'
if [ "$2" -ne 0 ]; then
  printf 'stdout diagnostic from $3\n'
  printf 'stderr diagnostic from $3\n' >&2
  exit "$2"
fi
printf '$3: pass\n'
EOF
	chmod +x "$1"
}

new_fixture_repo() { # name [suite=exit-status...] -> prints root
	local root="$SCRATCH/$1"
	shift
	local spec sname sstatus
	git init -q -b main "$root"
	git -C "$root" config user.name 'Fixture Developer'
	git -C "$root" config user.email fixture@example.invalid
	mkdir -p "$root/scripts"
	for spec in "$@"; do
		sname=${spec%%=*}
		sstatus=${spec##*=}
		write_suite "$root/scripts/$sname-test.sh" "$sstatus" "$sname-test.sh"
	done
	# Discovery reads `git ls-files`, so the fake suites must be tracked before
	# the first invocation; committer identity is local to the fixture because
	# the host cannot be assumed to carry one.
	git -C "$root" add -A
	git -C "$root" commit -q -m base
	printf '%s' "$root"
}

assert_contains() { # haystack needle label
	case $1 in
	*"$2"*) ;;
	*) fail "$3: expected to contain: $2" ;;
	esac
}

refuses() { # haystack needle label
	case $1 in
	*"$2"*) fail "$3: expected not to contain: $2" ;;
	esac
}

all_pass_root=$(new_fixture_repo all-pass alpha=0 gamma=0)

# Case 1: quiet all-pass. One stderr run line per suite, one stdout ok line per
# suite, no per-assertion lines, summary line, exit 0.
run_recipe "$all_pass_root"
if [[ $run_status -ne 0 ]]; then
	fail "quiet all-pass: expected exit 0, got $run_status"
fi
for suite in alpha gamma; do
	assert_contains "$run_stderr" "run   scripts/$suite-test.sh" \
		"quiet all-pass run line ($suite)"
	assert_contains "$run_stdout" "ok   scripts/$suite-test.sh" \
		"quiet all-pass ok line ($suite)"
done
refuses "$run_stdout" 'assertion in' 'quiet all-pass hides per-assertion lines'
assert_contains "$run_stdout" 'test: 2 suites passed' 'quiet all-pass summary'

# Case 3a: selection runs only matching suites.
run_recipe "$all_pass_root" alpha
[[ $run_status -eq 0 ]] || fail "selection: expected exit 0, got $run_status"
assert_contains "$run_stdout" 'ok   scripts/alpha-test.sh' 'selection ran the match'
refuses "$run_stdout" 'gamma' 'selection skipped the non-match'
assert_contains "$run_stdout" 'test: 1 suites passed' 'selection summary'

# Case 3b: multiple patterns OR and deduplicate — gamma matches all three
# patterns (gamma, amma, gam) and must appear exactly once in the report.
dedupe_root=$(new_fixture_repo dedupe alpha=0 gamma=0)
run_recipe "$dedupe_root" gamma amma gam
[[ $run_status -eq 0 ]] || fail "dedupe: expected exit 0, got $run_status"
assert_contains "$run_stdout" 'test: 1 suites passed' 'deduped summary'
if [[ $(printf '%s\n' "$run_stdout" | grep -cF 'ok   scripts/gamma-test.sh') -ne 1 ]]; then
	fail 'dedupe: a suite matching several patterns did not execute exactly once'
fi

# Case 3c: zero matches exits 1 naming the patterns.
run_recipe "$all_pass_root" nope nada
[[ $run_status -eq 1 ]] || fail "zero matches: expected exit 1, got $run_status"
assert_contains "$run_stderr" 'no suite matches: nope nada' \
	'zero matches names the patterns'

fail_root=$(new_fixture_repo failure alpha=0 beta=3 gamma=0)

# Case 2: quiet failure. Passing suites listed first, the failing suite's
# combined output replayed on stderr, its status propagated, later suites not run.
run_recipe "$fail_root"
[[ $run_status -eq 3 ]] || fail "failure: expected exit 3, got $run_status"
assert_contains "$run_stdout" 'ok   scripts/alpha-test.sh' 'failure lists earlier pass'
assert_contains "$run_stderr" '== scripts/beta-test.sh' 'failure names the suite'
assert_contains "$run_stderr" 'stdout diagnostic from beta-test.sh' \
	'failure replays captured stdout on stderr'
assert_contains "$run_stderr" 'stderr diagnostic from beta-test.sh' \
	'failure replays captured stderr on stderr'
refuses "$run_stdout" 'gamma' 'failure stopped the run'

# Case 4: verbose streams headers and full per-suite output.
verbose_root=$(new_fixture_repo verbose alpha=0 gamma=0)
run_recipe "$verbose_root" --verbose
[[ $run_status -eq 0 ]] || fail "verbose: expected exit 0, got $run_status"
assert_contains "$run_stdout" '== scripts/alpha-test.sh' 'verbose header'
assert_contains "$run_stdout" 'assertion in alpha-test.sh' 'verbose per-assertion line'
refuses "$run_stdout" 'ok   scripts/' 'verbose does not synthesize ok lines'

# Case 5: unknown option exits 64 with usage text.
run_recipe "$verbose_root" -x
[[ $run_status -eq 64 ]] || fail "unknown option: expected exit 64, got $run_status"
# Case 6: -v short form behaves like the long form (spec criterion 2 names
# both spellings).
run_recipe "$verbose_root" -v alpha
[[ $run_status -eq 0 ]] || fail "-v: expected exit 0, got $run_status"
assert_contains "$run_stdout" '== scripts/alpha-test.sh' '-v short form'

printf 'test-recipe-test: pass\n'
