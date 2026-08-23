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

- **Quiet by default.** The recipe prints a `run   <suite>` line to stderr as each suite
  starts — a wedged suite is always nameable — then captures the suite's combined
  stdout+stderr. On success it prints one stdout line, `ok   <suite-path>`. On failure it
  prints the header and replays the complete captured output **to stderr**, then exits
  with the suite's own status (stop-on-first-failure preserved). Replaying on stderr
  keeps the stdout cap honest; the capture residuals ADR 0033 discloses apply here too:
  replay preserves content but not live stdout/stderr interleaving, and an in-memory
  capture buffers a wedged suite without bound until it exits or the run is interrupted.
- **Positional patterns select suites.** `just test plugin-version verify-push` runs only
  suites whose `git ls-files` path contains at least one pattern as a substring (OR
  semantics). Patterns are unioned into a deduplicated set: a suite matching several
  patterns executes exactly once. Patterns apply after discovery and after the
  check-records-pair exclusion.
  When patterns are given and nothing matches, the recipe exits 1 naming the patterns;
  the existing no-suites-discovered floor still covers the no-pattern case.
- **Unknown dash-arguments are rejected** with exit 64 (sysexits usage), distinct from
  the recipe's infrastructure-failure exit 2; positional arguments never start with `-`.

Exit semantics are unchanged in every mode: the recipe's status is still the verdict,
the summary line still reads `test: N suites passed`, and CI (`just ci` → `just verify`)
keeps running the full suite set with no flags.

### Rejected alternatives

See ADR 0033 for why the quieting lives in the recipe rather than in the suites or in an
output filter, and why the flag is CLI rather than environment.

## Error handling

| Condition | Behavior |
|---|---|
| Suite fails | Header + full captured output replayed on stderr; exit = suite's status; later suites do not run |
| Pattern matches no suite | `test: no suite matches: <patterns>` on stderr, exit 1 |
| No suites discovered at all | Existing message, exit 1 |
| Unknown option (`-x`, `--wat`) | `test: unknown option: <arg>` on stderr, exit 64 (usage); the recipe's infrastructure failures keep exit 2 |

## Testing and verification

New suite `scripts/test-recipe-test.sh` (auto-discovered by the recipe itself) builds a
disposable git fixture holding fake `*-test.sh` scripts and invokes the real Justfile via
`just --justfile <repo>/Justfile --working-directory <fixture> test ...`. The fixture
initializes its own git repository with local `user.name`/`user.email` (committer
identity is not assumed from the host), tracks the fake suites before invoking `just`
(discovery reads `git ls-files`), and runs with the shared fixture isolation
(`clear_git_env`) so outer-repo config cannot reach it. Cases:

1. Quiet all-pass: one stderr `run` line per suite start, one `ok` stdout line per fake
   suite, no per-assertion lines, summary line, exit 0.
2. Quiet failure: passing suites listed `ok`, failing suite's captured output replayed,
   exit nonzero, later suites not run.
3. Selection: a matching pattern runs only matching suites; multiple patterns OR and
   deduplicate (a suite matching two patterns runs once); a non-matching pattern exits 1
   and names the patterns.
4. `--verbose`: headers and full output stream exactly as before.
5. Unknown option exits 64 with the usage message.

Guardrails: `just verify` green; version bump PATCH (no skill added or renamed; tooling
behavior + docs).

## Acceptance criteria

1. `just test` default output carries at most one stdout line per suite plus the summary;
   a failing suite replays its complete combined output on stderr and stops the run with
   the suite's status.
2. `just test -v` and `just test --verbose` reproduce the pre-change streaming behavior.
3. `just test <pattern>...` runs exactly the suites whose path contains any pattern,
   each matching suite exactly once; zero matches exits 1 naming the patterns.
4. Suite exit statuses decide the recipe verdict in all modes; no mode can turn a failed
   suite green.
5. CLAUDE.md documents the modes and gives selection guidance (selected suites while
   iterating, full `just verify` before shipping, `--verbose` when inspecting failures
   or when a green run's silence looks suspicious — quiet mode hides warnings).
6. `scripts/test-recipe-test.sh` covers cases 1–5 above and passes under `just test`.
7. `just verify` green; plugin version bumped.
