# Agent test experience (`just test` modes) — implementation plan

Date: 2026-08-23 · Issue: [#210](https://github.com/randomparity/adept/issues/210) ·
Spec: [2026-08-23-agent-test-experience-design.md](../specs/2026-08-23-agent-test-experience-design.md) ·
ADR: [0033](../../adr/0033-quiet-test-output-lives-in-the-recipe.md)

## Goal

`just test` gains quiet-by-default output, `-v/--verbose`, and pattern-based suite
selection, implemented entirely in the recipe, proven by a new fixture suite, and
documented in CLAUDE.md.

## Architecture

One recipe (`test` in `Justfile`) owns discovery (unchanged), selection (new), and output
shaping (capture-and-replay by default, streaming under `-v`). One new suite
(`scripts/test-recipe-test.sh`) proves the recipe end-to-end against disposable git
fixtures using the repo's own Justfile. CLAUDE.md documents the modes; the plugin version
bumps once at the end.

## Tech stack

Bash (3.2 floor — no `mapfile`, no associative arrays), `just` shebang recipes, existing
`scripts/test-fixture-helpers.sh`, git. No new dependencies.

## Global Constraints

Transcribed from the spec and repository instructions:

- Default output: one stderr `run   <suite>` line per suite start; one stdout
  `ok   <suite-path>` line per passing suite; failure replays header + full captured
  combined output **to stderr** and exits with the suite's own status;
  stop-on-first-failure.
- Patterns are positional substrings of discovery paths, OR semantics, unioned into a
  deduplicated set (each matching suite executes exactly once); zero matches exits 1
  naming the patterns; the no-suites-discovered floor still covers the no-pattern case.
- Unknown dash-options exit **64** with `test: unknown option: <arg>` on stderr;
  infrastructure failures keep exit 2; suite failures keep the suite's status.
- Verbose mode reproduces today's streaming behavior exactly (`== <suite>` headers,
  full live output).
- The check-records pair stays excluded from discovery; CI/pre-push run unflagged.
- Conventions: bash 3.2 floor; tab indentation; `set -euo pipefail`; guarded scratch-file
  create/remove with EXIT trap (mirror the lint/test recipes' pattern); shellcheck -x
  clean; shfmt-formatted; conventional commits ≤72 chars; never commit to main.
- Version bump: PATCH in `.claude-plugin/plugin.json` only (currently `2.9.3` → `2.9.4`);
  gate: `just version-check`.

## Task 1 — Prove the recipe contract with a failing suite, then implement it

**Files:** creates `scripts/test-recipe-test.sh`; modifies `Justfile` (`test` recipe
only).

**Interfaces:** consumes `test-fixture-helpers.sh`
(`clear_git_env`, `fixture_init <label>`, `SCRATCH`, `fail <msg...>`) exactly as
`scripts/check-plugin-version-test.sh` uses them. Later tasks rely on:
`scripts/test-recipe-test.sh` passes under `just test` and is auto-discovered by
`git ls-files -- '*-test.sh'`.

### Step 1.1 — Write the failing suite

Create `scripts/test-recipe-test.sh` verbatim:

```bash
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

new_fixture_repo() { # name -> prints root
	local root="$SCRATCH/$1"
	git init -q -b main "$root"
	git -C "$root" config user.name 'Fixture Developer'
	git -C "$root" config user.email fixture@example.invalid
	mkdir -p "$root/scripts"
	write_suite "$root/scripts/alpha-test.sh" 0 alpha-test.sh
	write_suite "$root/scripts/beta-test.sh" 3 beta-test.sh
	write_suite "$root/scripts/gamma-test.sh" 0 gamma-test.sh
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

all_pass_root=$(new_fixture_repo all-pass)

# Case 1: quiet all-pass. One stderr run line per suite, one stdout ok line per
# suite, no per-assertion lines, summary line, exit 0.
run_recipe "$all_pass_root"
if [[ $run_status -ne 0 ]]; then
	fail "quiet all-pass: expected exit 0, got $run_status"
fi
for suite in alpha beta gamma; do
	assert_contains "$run_stderr" "run   scripts/$suite-test.sh" \
		"quiet all-pass run line ($suite)"
	assert_contains "$run_stdout" "ok   scripts/$suite-test.sh" \
		"quiet all-pass ok line ($suite)"
done
refuses "$run_stdout" 'assertion in' 'quiet all-pass hides per-assertion lines'
assert_contains "$run_stdout" 'test: 3 suites passed' 'quiet all-pass summary'

# Case 3a: selection runs only matching suites.
run_recipe "$all_pass_root" alpha
[[ $run_status -eq 0 ]] || fail "selection: expected exit 0, got $run_status"
assert_contains "$run_stdout" 'ok   scripts/alpha-test.sh' 'selection ran the match'
refuses "$run_stdout" 'gamma' 'selection skipped the non-match'
assert_contains "$run_stdout" 'test: 1 suites passed' 'selection summary'

# Case 3b: multiple patterns OR and deduplicate — gamma matches all three
# patterns (gamma, amma, gam) and must appear exactly once in the report.
dedupe_root=$(new_fixture_repo dedupe)
run_recipe "$dedupe_root" gamma amma gam
[[ $run_status -eq 0 ]] || fail "dedupe: expected exit 0, got $run_status"
assert_contains "$run_stdout" 'test: 1 suites passed' 'deduped summary'
refuses "$run_stdout" 'beta' 'dedupe kept unrelated suites out'

# Case 3c: zero matches exits 1 naming the patterns.
run_recipe "$all_pass_root" nope nada
[[ $run_status -eq 1 ]] || fail "zero matches: expected exit 1, got $run_status"
assert_contains "$run_stderr" 'no suite matches: nope nada' \
	'zero matches names the patterns'

fail_root=$(new_fixture_repo failure)

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
verbose_root=$(new_fixture_repo verbose)
run_recipe "$verbose_root" --verbose
[[ $run_status -eq 0 ]] || fail "verbose: expected exit 0, got $run_status"
assert_contains "$run_stdout" '== scripts/alpha-test.sh' 'verbose header'
assert_contains "$run_stdout" 'assertion in alpha-test.sh' 'verbose per-assertion line'
refuses "$run_stdout" 'ok   scripts/' 'verbose does not synthesize ok lines'

# Case 5: unknown option exits 64 with usage text.
run_recipe "$verbose_root" -x
[[ $run_status -eq 64 ]] || fail "unknown option: expected exit 64, got $run_status"
assert_contains "$run_stderr" 'test: unknown option: -x' 'unknown option message'

# Case 6: --verbose spelled out behaves like -v.
run_recipe "$verbose_root" --verbose alpha
[[ $run_status -eq 0 ]] || fail "--verbose: expected exit 0, got $run_status"
assert_contains "$run_stdout" '== scripts/alpha-test.sh' '--verbose long form'

printf 'test-recipe-test: pass\n'
```

### Step 1.2 — Confirm the suite fails

```sh
./scripts/test-recipe-test.sh
```

Run it directly, not through `just test`: the pre-change recipe ignores arguments, so
the just form would run all 19 existing suites (~4.8 minutes) before reaching this one
and could redden on an unrelated suite first. Direct invocation isolates the red.

Expect: the suite runs (it is auto-discovered) and **fails** — the current recipe has no
selection, no run/ok lines, and treats `-x` as a suite name — with messages like
`test-recipe-test: quiet all-pass run line (alpha): expected to contain: run   scripts/alpha-test.sh`.
If it unexpectedly passes, stop: the suite is testing nothing and must be fixed before
implementation.

### Step 1.3 — Implement the recipe

In `Justfile`, replace the whole `test` recipe body (keep the recipe name and the
existing comment blocks about capture and guarding — carry them over verbatim):

```just
	#!/usr/bin/env bash
	set -euo pipefail
	verbose=0
	patterns=()
	for arg in "$@"; do
		case $arg in
		-v | --verbose)
			verbose=1
			;;
		-*)
			printf 'test: unknown option: %s\n' "$arg" >&2
			exit 64
			;;
		*)
			patterns+=("$arg")
			;;
		esac
	done
	suites="$(mktemp)" || {
		echo "test: could not create a scratch file for the suite list" >&2
		exit 2
	}
	cleanup() {
		local status=$?
		if ! rm -f -- "$suites"; then
			echo "test: retained scratch path: $suites" >&2
			if ((status == 0)); then
				exit 2
			fi
		fi
		exit "$status"
	}
	trap cleanup EXIT
	git ls-files -z -- '*-test.sh' >"$suites"
	count=0
	while IFS= read -r -d '' suite; do
		case $suite in
		.github/scripts/check-records-test.sh | \
		  skills/tome-of-lore/assets/check-records-test.sh)
			continue
			;;
		esac
		if ((${#patterns[@]})); then
			matched=0
			for pattern in "${patterns[@]}"; do
				case $suite in
				*"$pattern"*)
					matched=1
					break
					;;
				esac
			done
			((matched)) || continue
		fi
		if ((verbose)); then
			printf '== %s\n' "$suite"
			"./$suite" </dev/null
		else
			printf 'run   %s\n' "$suite" >&2
			status=0
			output=$("./$suite" </dev/null 2>&1) || status=$?
			if ((status != 0)); then
				printf '== %s\n' "$suite" >&2
				printf '%s\n' "$output" >&2
				exit "$status"
			fi
			printf 'ok   %s\n' "$suite"
		fi
		count=$((count + 1))
	done <"$suites"
	if ((count == 0)); then
		if ((${#patterns[@]})); then
			printf 'test: no suite matches: %s\n' "${patterns[*]}" >&2
		else
			printf 'test: no suites discovered\n' >&2
		fi
		exit 1
	fi
	printf 'test: %s suites passed\n' "$count"
```

(Indentation inside the Justfile is tabs, matching every other recipe.)

### Step 1.4 — Confirm green

```sh
just test test-recipe
```

Expect: `test-recipe-test: pass` and the recipe summary line — this is the green proof
through the real entry point, exercising discovery and argument plumbing end to end.
Exit 0.

**Acceptance:** suite fails against the old recipe (observed in 1.2), passes against the
new one; `shellcheck -x scripts/test-recipe-test.sh` exits 0; `shfmt -d
scripts/test-recipe-test.sh` reports no diffs (the `scripts/` tree is tab-indented).

**Commit:** `feat(test): quiet default, verbose flag, and pattern selection in just test`
— paths `Justfile scripts/test-recipe-test.sh`.

## Task 2 — Document the modes and bump the version

**Files:** modifies `CLAUDE.md` (section "Verifying a change"),
`.claude-plugin/plugin.json`.

**Interfaces:** none consumed; downstream readers get the documented contract.

### Step 2.1 — CLAUDE.md guidance

In `CLAUDE.md`, directly after the paragraph introducing `just verify` / `just hooks`
and before the `just plugin-check` paragraph, insert:

```markdown
Unit tests support two refinements while iterating:

- `just test <pattern>...` runs only the discovered suites whose path contains any
  pattern as a substring — `just test plugin-version` runs
  `scripts/check-plugin-version-test.sh` alone. Zero matches exits 1 naming the
  patterns; a suite matching several patterns still runs once. Output is quiet by
  default: a `run   <suite>` line on stderr as each suite starts, an `ok   <suite>`
  line when it passes, and the first failing suite's complete output replayed on
  stderr before the run stops with that suite's status.
- `just test --verbose [<pattern>...]` restores the full streaming output — every
  assertion line — for inspecting a failure or a suspiciously quiet pass (the quiet
  default hides warnings a passing suite printed).

Selection speeds up iteration; it never substitutes for `just verify` before shipping —
CI and the pre-push hook always run the full suite set.
```

### Step 2.2 — Bump the version

`.claude-plugin/plugin.json`: `"version": "2.9.3"` → `"version": "2.9.4"` (PATCH: no
skill added or renamed, no invocation contract broken).

### Step 2.3 — Verify

```sh
just version-check && claude plugin validate ./ --strict
```

Expect both exit 0.

**Acceptance:** CLAUDE.md renders the two bullets above the plugin-check paragraph;
version strictly greater than base.

**Commit:** `docs(test): document just test modes and bump version to 2.9.4` — paths
`CLAUDE.md .claude-plugin/plugin.json`.

## Task 3 — Full guardrail sweep

Run the complete chain bare, in order, each exit code the verdict:

```sh
just records
just verify
```

Expect: `records` prints `Records OK.`; `verify` ends `test: N suites passed` (N = 20 —
19 original suites plus `test-recipe-test`) followed by the prek dry-run line, exit 0.
Fix any red finding at its cause before committing; a red `verify` after Tasks 1–2 is a
defect in those tasks, not a reason to adjust gates.

No further commit is expected in this task unless the sweep found something.

## Rollback

Single PR revert restores prior behavior wholesale; the recipe change is contained in
one recipe plus one additive suite and one doc section. No data, schema, or external
state.

## Implementation deltas (as shipped)

Deviations from the snippets above, applied without contract change:

1. The recipe needed the `[positional-arguments]` attribute. Without it, just 1.58.0
   does not deliver variadic parameters to a shebang recipe at all (`$@` is empty), so
   neither patterns nor `-v/--verbose` could reach the script. With the attribute,
   flags after the recipe name pass through verbatim (`just test -v` reaches the
   recipe). There is no `--` end-of-options handling: a bare `--` is an unknown option
   and takes the exit-64 usage path, matching the documented model that positional
   arguments never start with `-`.
2. `new_fixture_repo` takes explicit `suite=exit-status` arguments instead of always
   writing alpha/beta/gamma: the all-pass and verbose fixtures need only passing suites,
   and Case 1's expected summary is `test: 2 suites passed`. The dedupe case asserts
   gamma's `ok` line appears exactly once via `grep -c`, and Case 6 exercises the `-v`
   short form (spec criterion 2 names both spellings).
