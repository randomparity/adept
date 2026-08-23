# 0033 Quiet test output lives in the recipe

## Status

Proposed

## Context

Discovery (`git ls-files -- '*-test.sh'`) yields 21 paths; the recipe deliberately skips
both byte-identical check-records twins — those run under `just records` and inside
`git-fixture-isolation-test.sh` — so 19 suites execute, streaming each one's full output
behind a `== <suite>` header. Agents iterating on the repository pay two costs: the just
recipes offer no subset selection (every change re-runs all 19 suites; a direct
`./scripts/<suite>` invocation exists but bypasses the recipe's discovery and summary),
and the default output is dominated by per-assertion `ok` lines that carry no information
on a green run. The suites themselves are heterogeneous: most share
`test-fixture-helpers.sh`, but several keep their own scaffolding deliberately, and the
3,747-line check-records twins print through their own inline `printf` sites.
(`time just test`: 4m48s wall on an Apple M5 Max host, 2026-08-23.)

## Decision

Quiet-by-default output and pattern-based selection are implemented **entirely in the
`Justfile` test recipe**: the recipe captures each suite's combined stdout+stderr, prints
one `ok   <suite>` line per passing suite, and replays the complete captured output only
for the failing suite before exiting with that suite's status. A leading `-v`/`--verbose`
argument restores today's streaming behavior. Positional substring patterns restrict which
discovered suites run; patterns matching zero discovered suites exit non-zero naming the
unmatched patterns, so a typo can never read as a green run over an empty set. Every run —
quiet or verbose, full or selected — reports exactly which suites executed: the per-suite
`ok   <suite>` lines are that report, and the closing `test: N suites passed` counts them.
No suite file changes.

- The contract ("quiet default, verbose escape hatch, selection") is enforced in one file;
  adding a suite needs no awareness of verbosity. Suite authors keep printing freely.
- A green quiet run hides warnings a verbose run would show; an agent inspecting a
  suspicious pass reruns with `-v`. Documented in CLAUDE.md.
- Selection matches substrings of discovery paths, not suite names or tags — good enough
  for paths like `scripts/check-plugin-version-test.sh`, cheap to explain, no new syntax.
- CI and the managed pre-push hook keep running the full set unflagged; nothing about
  their verdict path changes.

## Considered & rejected

- **Per-suite verbosity plumbing** (a shared `ok`-reporting helper every suite calls).
  judgment: the diff touches ~15 files including dozens of inline printf sites in the
  byte-identical check-records twins (`just records` compares them byte for byte, so each
  edit lands twice), all to achieve centrally what capture-and-replay achieves in one
  recipe — cost without contract gain.
- **Environment-variable verbosity** (`TEST_VERBOSE=1`). judgment: the issue asks for a
  `-verbose` option, and an exported variable leaks into nested invocations — the managed
  pre-push hook re-runs `just verify` in an isolated worktree and would inherit surprise
  verbosity into push output.
- **Streaming filter** (pipe live output through a matcher that drops `ok` lines).
  judgment: it must classify prose lines to work, so a suite whose summary line drifts
  gets misclassified silently; capture-and-replay classifies by exit status only.
- **Do nothing** (keep streaming output, add no selection). judgment: the per-assertion
  noise lands on every agent invocation while carrying no information on a green run, and
  the wall-clock cost of full-set re-runs recurs on every change.
- **Selection only, leave the default output streaming.** judgment: it fixes wall-clock
  but leaves the dominant green-run noise untouched, so it does not meet the issue's
  minimize-default-output goal.
