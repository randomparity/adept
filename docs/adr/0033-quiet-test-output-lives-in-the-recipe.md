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
on a green run. Every non-twin suite sources the shared `test-fixture-helpers.sh`
scaffold, but each keeps its own local assertion printers, and the
3,747-line check-records twins print through their own inline `printf` sites.
(`time just test`: 4m48s wall on an Apple M5 Max host, 2026-08-23.)

## Decision

Quiet-by-default output and pattern-based selection are implemented **entirely in the
`Justfile` test recipe**: the recipe captures each suite's combined stdout+stderr, prints
one `ok   <suite>` line per passing suite, and replays the complete captured output only
for the failing suite before exiting with that suite's status. A leading `-v`/`--verbose`
argument restores today's streaming behavior. Positional substring patterns restrict which
discovered suites run; patterns matching zero discovered suites exit non-zero naming the
unmatched patterns, so a typo can never read as a green run over an empty set. Quiet mode
prints a `run   <suite>` line to **stderr** as each suite starts, so a wedged suite is
always nameable; the `ok   <suite>` stdout line is the completion marker. Every run —
quiet or verbose, full or selected — reports exactly which suites executed, and the
closing `test: N suites passed` counts them. No suite file changes.

## Consequences

- The contract ("quiet default, verbose escape hatch, selection") is enforced in one file;
  adding a suite needs no awareness of verbosity. Suite authors keep printing freely.
- A green quiet run hides warnings a verbose run would show; an agent inspecting a
  suspicious pass reruns with `-v`. Documented in CLAUDE.md.
- Selection matches substrings of discovery paths, not suite names or tags — good enough
  for paths like `scripts/check-plugin-version-test.sh`, cheap to explain, no new syntax.
- CI and the managed pre-push hook keep running the full set unflagged; nothing about
  their verdict path changes.
- Replayed failure output preserves content but not the live interleaving of stdout and
  stderr (one merged capture stream); order-sensitive diagnosis reruns the suite
  directly. Capture is in-memory (command substitution), leaving no scratch residue; the
  accepted residual is that a wedged or chatty suite buffers without bound until it exits
  or the run is interrupted — the stderr `run   <suite>` line names the suspect.

## Considered & rejected

- **Per-suite verbosity plumbing** (a shared `ok`-reporting helper every suite calls).
  judgment: the diff touches all 19 executing suites plus the shared helper — dozens of
  local assertion-printer sites across them, each edit needing its suite's own printer
  convention — to achieve centrally what capture-and-replay achieves in one recipe;
  cost without contract gain.
- **Environment-variable verbosity** (`TEST_VERBOSE=1`).
  verified: the push-time re-run chain is `git push` → `scripts/pre-push-hook` →
  `scripts/verify-push.sh` (`git worktree add --detach`, then `just ci`) → `just verify`
  → the test recipe.
  judgment: ambient exported state propagates through that inherited environment, so a
  developer's `TEST_VERBOSE` would surface as surprise verbosity in push output; the
  issue asks for a `-verbose` option, and a flag is invoked state rather than ambient
  state.
- **Streaming filter** (pipe live output through a matcher that drops `ok` lines).
  judgment: it must classify prose lines to work, so a suite whose summary line drifts
  gets misclassified silently; capture-and-replay classifies by exit status only.
- **Do nothing** (keep streaming output, add no selection). judgment: the per-assertion
  noise lands on every agent invocation while carrying no information on a green run, and
  the wall-clock cost of full-set re-runs recurs on every change.
- **Selection only, leave the default output streaming.** judgment: it fixes wall-clock
  but leaves the dominant green-run noise untouched, so it does not meet the issue's
  minimize-default-output goal.
- **Log capture** (`tee` each suite's output to a per-run log, print the quiet summary
  plus the log path). judgment: inspection of a suspicious pass becomes a file read
  instead of a re-run, but the retained artifacts need a home, a retention rule, and
  cleanup the repo's no-residue conventions would have to govern — more moving parts than
  the `-v` re-run they replace, which pattern selection already bounds to seconds.
- **Concurrent suite execution.** judgment: it would attack the wall-clock figure, but
  parallel output complicates failure attribution — the exact problem quiet mode exists
  to simplify — and the issue asks for quieter, narrower runs, not faster ones; pattern
  selection already bounds the common re-run to seconds.