# Bound the gh calls in publish-forge-review and cleared-dependencies.sh

Issue: [#386](https://github.com/randomparity/adept/issues/386) · parent [#379](https://github.com/randomparity/adept/issues/379)
Record applied: [ADR 0068](../../adr/0068-a-timeout-is-not-an-answer.md) via [`references/network-bounds.md`](../../../references/network-bounds.md)

## Problem

`skills/quest/scripts/publish-forge-review` and `skills/quest-log/assets/cleared-dependencies.sh`
make six literal `gh` invocations between them, none bounded. Against an unreachable or
black-holing remote each blocks indefinitely and hangs an unattended worker. The convention that
ends that wait is already recorded and merged; this change applies it and invents nothing.

## Scope

Six literal invocation points, and the four wrapper callers the first of them serves:

| Site | Call | Requests | Bound |
|---|---|---|---|
| `publish-forge-review:242` | `gh pr comment` — **the write** | 2 (lookup + mutation) | 120 s |
| `publish-forge-review:260` | `gh api <endpoint>` — the readback | 1 | 30 s |
| `cleared-dependencies.sh:82` via `:102`, `:201`, `:241` | `gh issue view --json` | 1 | 30 s |
| `cleared-dependencies.sh:82` via `:287` | `gh api --paginate` | unbounded pages | 120 s |
| `cleared-dependencies.sh:171` | `gh label create` — a write | 1 | 30 s |
| `cleared-dependencies.sh:186`, `:234` | `gh issue edit` — writes | 4, growing with the label set | 120 s |

Request counts are measured, not inferred: `GH_DEBUG=api` against the live API on 2026-09-15
showed one `POST /graphql` for `gh issue view --repo N --json state`, one
`POST /repos/{owner}/{repo}/labels` for `gh label create`, two for `gh issue comment` (whose
commentable code path `gh pr comment` shares), and four for a `gh issue edit` carrying one
`--remove-label` and one `--add-label`.

Out of scope, with owners: `publish-handoff` (#384), `collect-telemetry` (#387),
`profiles/github.sh` (no applier issue; held by the campaign orchestrator), retry or backoff
anywhere, bounding non-network subprocesses, and adding any binary to
`publish-forge-review:48`'s required-command list (#382).

### Mechanism

`bounded_call` is transcribed from the reference, keeping its signature
(`seconds out-file err-file command…`), its seven non-adaptable properties, and its 124 return.
One adaptation, not among the seven: in the sourced recipe it is
`cleared_dependency_bounded_call`, matching that file's prefix convention, because sourcing it
into a caller's shell publishes the name. Nothing else differs, so both copies stay
byte-comparable against `references/network-bounds.md:26-56`, which is what ADR 0068 leaves as
the drift check. No `# scan-fault: deliberate — …` pragma is added:
`scripts/check-scan-fault-discards.sh:45` exempts `kill` and `wait` as pure builtins, confirmed
by running the gate over an un-pragma'd transcription.

Each file wraps it once more for its own capture-lifecycle discipline, rather than repeating
allocation at six sites:

- `publish-forge-review` gains `run_gh <seconds> <gh-args…>`, which allocates both captures with
  `mktemp`, forwards any captured stderr to the script's own stderr (preserving today's
  behaviour, where `gh`'s stderr is not captured at all), leaves stdout in `gh_capture` for the
  caller to read and remove, and returns the call's status or 124. `fail()` removes `gh_capture`,
  so no fatal path leaks one.
- `cleared-dependencies.sh` keeps its existing `cleared_dependency_run` wrapper and gives it a
  leading bound argument. On 124 it empties `cleared_dependency_out`, sets
  `cleared_dependency_err` to an authored "did not answer" diagnostic rather than to `gh`'s
  partial stderr, and returns 124 for the call site to classify.

The three label writes at `:171`, `:186` and `:234` keep merging a diagnostic they discard on
success — the reference protects a captured *value*, not every stream — but they merge after the
call, by concatenating the two captures, instead of in a `2>&1` redirect.

### Classification

`publish-forge-review` reports a timeout through `fail` — exit 1. It has no exit-2 class, and
ADR 0068's Consequences supersede issue #386's expectation of one by name.
`cleared-dependencies.sh` reports through its existing diagnostics and its exit 1 "degraded or
partial" verdict; its exit 2 stays `usage`. Every timeout message names the call and says the
bound was exceeded. The three writes, and the `gh pr comment` write, additionally say the write
may or may not have landed, and none is retried.

### Test determinism

The bound is injectable, which issue #386 offers as one of two acceptable designs. The suites set
it to 1 second and the fake `gh` blocks for 30 with `exec sleep 30`, so TERM reaches the blocking
process directly and the case costs about 1.1 s with a 30× margin on either side of the bound.
`publish-forge-review` reads `PUBLISH_FORGE_REVIEW_BOUND`; `cleared-dependencies.sh` uses
`cleared_dependency_bound_single` and `cleared_dependency_bound_multi`. Those two are assigned
with `:=` rather than `=` for one reason: the suite's direct-execution leg exports them into a
subprocess, and an unconditional `=` at the top of a sourced-or-executed file would overwrite the
exported value before any call read it. In sourced mode the suite reassigns them after sourcing,
which `=` would also have supported.

## Failure model

**Actors and deployments.** A local operator at a terminal; an unattended `$quest` or `$campaign`
worker; the two behaviour suites; CI. `cleared-dependencies.sh` additionally runs sourced, into a
caller's shell, from its suite.

**Invariants and assets at stake.** A timeout is never reported as a missing record, a false
condition, or a zero. A `WORK:REVIEW` annotation is posted at most once and never twice.
`publish-forge-review`'s stdout stays exactly one line, which `$quest` step 8 parses. A run that
changed no labels keeps saying so. `cleared-dependencies.sh`'s 0/1/2 verdict keeps its meanings.
Capture files are private and unguessable.

**Accepted failure classes.**
- `sleep` is not on `publish-forge-review:48`'s required-command list — adding it is #382's, per
  the frozen exclusions. It is POSIX-mandated and present wherever `gh` is; the list exists for
  commands that are genuinely absent on a stock host, which is why ADR 0068 refuses `timeout`. The
  shape if it were ever absent is worth naming: every site calls the wrapper as `… || rc=$?`, so
  `set -e` is suspended inside the function body and a failing `sleep` does not abort the call —
  the poll spins to its iteration limit and returns an immediate false 124, reported as a bound
  exceeded on a call that never ran long.
- The bound is approximate. Poll overhead accumulates, so a 30-second bound fires near 32.
- PID reuse inside one poll interval, same-uid, as `references/network-bounds.md` records.
- An indeterminate write leaves an artifact this script cannot verify. Reported, not resolved.
- A per-call bound does not bound a run; neither file gains an aggregate budget. An `apply`
  sweep against a dead remote can still run for a long time: up to
  `cleared_dependency_max_lookups` blocker reads at 30 s apiece, plus the per-candidate calls.
- A run killed by a signal mid-call leaves its mode-0600 capture files in `TMPDIR`. Both files
  are removed on every path the script itself takes, including `fail`, but neither is reachable
  from a signal handler: `cleared-dependencies.sh` deliberately installs no trap, and
  `publish-forge-review`'s existing EXIT trap does not fire inside the command-substitution
  subshell that runs its comment write. Two empty private files, in the same class as the orphan
  process below.
- Bash's `Terminated: 15` job notice reaches each file's own stderr, which is prose in both. Only
  `profiles/github.sh` parses its stderr, and that file is out of scope.

**Covered elsewhere.** The three sibling callers and their appliers (#384, #387, and the
unassigned `github.sh` gap ADR 0068 records); retry, backoff, and the required-command list
(#382); whether `collect-telemetry` needs an overall budget (#387).

## Threat model

**Boundary inventory.** Widened: three environment variables newly read
(`PUBLISH_FORGE_REVIEW_BOUND`, `cleared_dependency_bound_single`, `cleared_dependency_bound_multi`).
Added: four `mktemp` capture files per run at most, holding `gh` response bodies. No boundary is
added to the network side — the same calls are made, to the same host, with the same arguments.

**Actor model.** Trusted: the operator and the harness that set the process environment, who
already control `PATH` and therefore which `gh` runs. Untrusted: GitHub's response bodies, which
reach `jq` and `awk` as they do today, and any other local user on a shared host, who is the
reason the captures must not be world-readable or symlink-followable.

**Control per boundary.** Each bound is validated as a whole number of digits before any use —
`publish-forge-review` in `preflight()`, `cleared-dependencies.sh` at the top of
`cleared_dependency_run`. That guard is not cosmetic: bash evaluates an arithmetic operand as an
expression, so `$((bound * 10))` on a value of `x[$(echo PWNED >&2)]` runs the substitution, as
measured on `/bin/bash` 3.2.57. The guard turns that into a refusal instead; a merely
non-numeric value would otherwise evaluate to 0 and return 124 on every call, which is a denial
an actor with environment control already has by other means. Capture files
are allocated by `mktemp` at mode 0600 with unguessable names, never a `$$`-derived path in a
shared directory — the reference's first non-adaptable property, which exists precisely to keep
the `>` redirect from following a pre-created symlink. Response bodies are unchanged in handling:
`publish-forge-review` still compares them with `jq -e`, and `cleared-dependencies.sh` still runs
them through `cleared_dependency_safe_text` before any diagnostic is printed. On 124 the stdout
capture is emptied by the mechanism, so no half-written page is parsed.

**Explicitly out of scope.** A caller that controls `PATH` (it already controls `gh` itself);
`TMPDIR` pointing somewhere hostile (`mktemp` fails or creates privately, and the script reports);
the orphan a caller killed mid-call leaves, which is today's exposure unchanged.

## Success

1. Each of the six invocation points runs under `bounded_call` at the bound its row above states,
   and no `gh` invocation expression in either file is captured by a command substitution.
2. `publish-forge-review` exits 1 on a bound exceeded at either site, with a diagnostic naming the
   call and the bound; the `:242` write additionally reports the comment may or may not exist. A
   readback failure of **any** status, not only a bound exceeded, names the posted comment it
   could not verify: the comment is equally unverified either way, and withholding its URL on the
   pre-existing failure path would leave the operator to find it — which is how a re-run posts a
   second one.
3. `cleared-dependencies.sh` reports a bound exceeded through `unreadable blocker`,
   `unreadable dependent`, `verification unreadable`, `cannot list open dependents`, or the
   matching write diagnostic; exits 1; and keeps "no labels changed" true when it changed none.
4. `:287` states its bound's multi-request meaning in a comment at the site.
5. All four writes across the two files — `publish-forge-review:242` and
   `cleared-dependencies.sh:171`, `:186`, `:234` — report indeterminacy on a bound exceeded, and
   none of the four is retried.
6. `.claude-plugin/plugin.json` carries `5.10.2`, the version the campaign reserved for this row.
7. `just verify` is green.

## Validation

- **`publish-forge-review` write bound.** Mode: focused-test — `tests/fixtures/quest/publish-forge-review-test.sh`,
  new case `PFR-22`. Red before the change: the fake blocks 30 s and the suite hangs. Green:
  `just test publish-forge-review` — exit 1, stderr names the bound and the indeterminacy, exactly
  one comment invocation, body retained, no `review-publication-verified` line.
- **`publish-forge-review` readback bound.** Mode: focused-test — same file, new case `PFR-23`.
  Red: the suite hangs. Green: same command — exit 1, stderr names the readback bound, the posted
  comment is not disposed.
- **Child reaped.** Mode: focused-test — `PFR-22` records the fake's own pid and asserts
  `kill -0` on it fails after the run.
- **`cleared-dependencies.sh` read bound at `:102`.** Mode: focused-test —
  `tests/fixtures/quest-log/cleared-dependencies-test.sh`. Green: `just test cleared-dependencies`
  — `cleared_dependency_body_verdict` returns 1, reason contains `unreadable blocker #1` and the
  bound, and contains neither `missing blocker` nor `CLOSED`.
- **`cleared-dependencies.sh` read bounds at `:201` and `:241`.** Mode: focused-test — same file,
  one case each, because the two produce different diagnostics and `:241` runs *after* the label
  write, where reading a timeout as a failed write would be the costliest confusion. Green:
  `apply_cleared_dependency` returns 1; stderr carries `unreadable dependent #101` for the first
  and `verification unreadable for #101` for the second; and in the `:241` case `$gh_log` records
  no restoring `--add-label status:blocked`, because a call that did not answer is not evidence
  the write went wrong.
- **`cleared-dependencies.sh` paginated bound at `:287`.** Mode: focused-test — same file, sourced
  and again through direct execution. Green: exit 1, stderr carries `cannot list open dependents`,
  the bound, and `no labels changed`.
- **`cleared-dependencies.sh` write indeterminacy at `:171` and `:234`.** Mode: focused-test —
  same file. Green: `apply_cleared_dependency` returns 1, stderr says the label may or may not
  exist / the labels may or may not have been changed, and no further `gh issue edit` is logged.
- **`cleared-dependencies.sh` write indeterminacy at `:186`.** Mode: focused-test — same file. The
  best-effort restore is reached only from the conflict and race paths, which need the `:234`
  write to succeed first, so the hang arm keys on `--add-label status:blocked` rather than on the
  subcommand: that is the label only the restore carries, and the fake already discriminates on it
  at `:54`. Green: `apply_cleared_dependency` returns 1, stderr carries both the conflict report
  and `restoring #101 to status:blocked ... may or may not have been changed`, and `$gh_log`
  records exactly one edit, the `status:ready` one that succeeded.
- **Bound assignment per site in `cleared-dependencies.sh`.** Mode: focused-test — the file's two
  bound globals are independently settable, so the suite sets them to *different* values (1 and 2)
  and every one of the seven bound-exceeded cases asserts which number reached its diagnostic.
  A site passing the single-request bound where the table above requires the multi-request one, or
  the reverse, turns the suite red. Green: `just test cleared-dependencies`.
- **Bound assignment per site in `publish-forge-review`.** Mode: task-test-not-applicable — its
  one override, `PUBLISH_FORGE_REVIEW_BOUND`, feeds both constants, so no injected value can
  separate them and no executable observation distinguishes 30 from 120 without waiting the
  difference. The table above and the site comments are the record; the review reads them against
  it. Converging on the two-global shape is a campaign follow-up, not this change's.
- **`.claude-plugin/plugin.json` version.** Mode: focused-test — `just version-check`.
