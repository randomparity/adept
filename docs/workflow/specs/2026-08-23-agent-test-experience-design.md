# Agent test experience (`just test` modes) — design

Date: 2026-08-23 · Issue: [#210](https://github.com/randomparity/adept/issues/210) · ADR: [0033](../../adr/0033-quiet-test-output-lives-in-the-recipe.md)

## Goal

An agent (or human) iterating on this repository can run one unit suite in seconds, sees
a quiet default output that names what ran and what failed, and can restore full
per-assertion output with an explicit flag. CLAUDE.md documents when to use each mode.

## Current state

`just test` discovers every `*-test.sh` under `git ls-files`, skips the byte-identical
check-records pair (they run inside `git-fixture-isolation-test.sh`), prints a `== <suite>`
header before each, streams the suite's full output, and stops on the first failure. A
full run is 19 suites / ~4.5 minutes / ~150 lines. Two agent-experience problems:

1. **No selection.** Verifying one change means re-running all 19 suites; there is no way
   to run only the suite that covers it.
2. **Volume without signal.** Per-assertion `ok` lines dominate the output on every run,
   including the common all-green case where the only facts that matter are which suites
   ran and whether any failed.

The failure path is already good: every suite reports diagnostics through its own
conventions, and `fail()` writes to stderr. Nothing here may weaken that.

## Decision

All three behaviors live in the `Justfile` `test` recipe. No suite file changes.

- **Quiet by default.** The recipe captures each suite's combined stdout+stderr. On
  success it prints one line, `ok   <suite-path>`. On failure it prints the header, the
  full captured output, and exits with the suite's own status (stop-on-first-failure
  preserved).
- **`--verbose` / `-v` restores today's behavior** exactly: streaming headers and full
  per-suite output.
- **Positional patterns select suites.** `just test plugin-version verify-push` runs only
  suites whose `git ls-files` path contains at least one pattern as a substring (OR
  semantics). Patterns apply after discovery and after the check-records-pair exclusion.
  When patterns are given and nothing matches, the recipe exits 1 naming the patterns;
  the existing no-suites-discovered floor still covers the no-pattern case.
- **Unknown dash-arguments are rejected** with exit 2; positional arguments never start
  with `-`.

Exit semantics are unchanged in every mode: the recipe's status is still the verdict,
the summary line still reads `test: N suites passed`, and CI (`just ci` → `just verify`)
keeps running the full suite set with no flags.

### Rejected alternatives

See ADR 0033 for why the quieting lives in the recipe rather than in the suites or in an
output filter, and why the flag is CLI rather than environment.

## Error handling

| Condition | Behavior |
|---|---|
| Suite fails | Header + full captured output replayed; exit = suite's status; later suites do not run |
| Pattern matches no suite | `test: no suite matches: <patterns>` on stderr, exit 1 |
| No suites discovered at all | Existing message, exit 1 |
| Unknown option (`-x`, `--wat`) | `test: unknown option: <arg>` on stderr, exit 2 |

## Testing and verification

New suite `scripts/test-recipe-test.sh` (auto-discovered by the recipe itself) builds a
disposable git fixture holding fake `*-test.sh` scripts and invokes the real Justfile via
`just --justfile <repo>/Justfile --working-directory <fixture> test ...`. Cases:

1. Quiet all-pass: one `ok` line per fake suite, no per-assertion lines, summary line,
   exit 0.
2. Quiet failure: passing suites listed `ok`, failing suite's captured output replayed,
   exit nonzero, later suites not run.
3. Selection: a matching pattern runs only matching suites; multiple patterns OR; a
   non-matching pattern exits 1 and names the patterns.
4. `--verbose`: headers and full output stream exactly as before.
5. Unknown option exits 2.

Guardrails: `just verify` green; version bump PATCH (no skill added or renamed; tooling
behavior + docs).

## Acceptance criteria

1. `just test` default output carries at most one line per suite plus the summary; a
   failing suite replays its complete combined output and stops the run with the suite's
   status.
2. `just test -v` and `just test --verbose` reproduce the pre-change streaming behavior.
3. `just test <pattern>...` runs exactly the suites whose path contains any pattern;
   zero matches exits 1 naming the patterns.
4. Suite exit statuses decide the recipe verdict in all modes; no mode can turn a failed
   suite green.
5. CLAUDE.md documents the modes and gives selection guidance (selected suites while
   iterating, full `just verify` before shipping, `--verbose` when inspecting failures).
6. `scripts/test-recipe-test.sh` covers cases 1–5 above and passes under `just test`.
7. `just verify` green; plugin version bumped.
