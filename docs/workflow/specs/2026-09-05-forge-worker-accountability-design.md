# Forge party worker accountability — design

Decision record: [ADR 0055](../../adr/0055-party-derives-red-and-names-its-committer.md).

## Goal

`$forge` party closes a task on the implementer's report. Make two of that report's claims
derived by the orchestrator rather than read from it: the red half of every `focused-test`
contract, and which dispatch produced each commit.

Scope is forge party only. Cast mode already ledgers its own red exit status and has no worker to
identify; `$summon-swarm` workers are `codex exec` runs that do not commit, so a trailer has no
carrier there. Both are out of scope, as are the sampling, honeypot, and structured-event-ledger
options considered alongside these two.

## Requirements

**R1.** For every `focused-test` entry in a task's Verification inventory, the orchestrator runs
the entry's exact red command against a tree whose non-test paths are at the task base, and
requires a non-zero exit before the task closes.

**R2.** A red command that exits zero under R1 stops the run for reconciliation. It is not a
finding to note, not a retry, and not a `DONE_WITH_CONCERNS`.

**R3.** Where the task changed no non-test paths, R1 cannot be performed. The orchestrator records
that outcome and continues; it must not report the entry as verified.

**R4.** R1 leaves the worktree exactly as it found it. A tree that cannot be restored stops the
run with the unrestored state named.

**R5.** Every commit a party worker makes carries a `Forge-Dispatch` git trailer whose value the
dispatch supplied. Step 5 verifies it on every commit in the task's range alongside the existing
ancestry check; a missing or unexpected value is a stop-and-reconcile.

**R6.** The `Forge-Dispatch` value is minted when the worker is dispatched, on every run.

## Architecture

One new executable, `skills/forge/scripts/verify-red`, plus contract text in
`skills/forge/SKILL.md` and `skills/forge/implementer-prompt.md`. Nothing else in the pipeline
changes: `$quest` consumes the same forge result modes, and the ledger gains one field on a line
it already writes.

### verify-red

```
verify-red --base SHA --head SHA --test PATH [--test PATH]... -- COMMAND [ARG...]
```

Run from inside the party worktree. `--test` names the file a focused entry names, repeated once
per file. Everything after `--` is the entry's exact red command.

Order of operations:

1. Resolve `--base` and `--head`; refuse a tree with any modification pending.
2. Compute the task's changed paths as `git diff -z --name-only BASE HEAD`. Every `--test` path
   must appear among them — an entry naming a file the task did not touch is a precondition
   failure, not a verdict.
3. `impl` = changed paths minus `--test` paths. Empty `impl` is R3's outcome.
4. Install the restore trap, then for each `impl` path: check it out from BASE where BASE has it,
   remove it where BASE does not (the task created it).
5. Run the command. Capture its exit status without letting it end the script.
6. Restore: for each `impl` path, check it out from HEAD where HEAD has it, remove it where HEAD
   does not (the task deleted it). Require `git status --porcelain` to be empty afterwards.
7. Print one verdict line and exit with its code.

Exit codes are the interface; the verdict line is for the transcript.

| Exit | Verdict | Orchestrator |
|---:|---|---|
| 0 | `red-confirmed` | close the entry |
| 1 | `red-not-reproduced` | stop and reconcile (R2) |
| 2 | usage error | stop; the dispatch built the call wrong |
| 3 | precondition failure | stop; dirty tree, unresolvable ref, empty range, or an untouched `--test` path |
| 4 | `red-not-separable` | record and continue (R3) |
| 5 | restoration failed | stop; the tree is not at HEAD (R4) |

Separability is decided structurally, from the path sets alone. The script never reads a file's
contents to decide whether a test and its implementation are entangled — that would be a prose
judgement, and the empty-`impl` condition already catches the case that matters.

### The trailer

`Forge-Dispatch: <unit>.<attempt>` — `unit` is `task-<N>` for an implementer or `review-fix` for
the fix worker after the whole-branch review; `attempt` is `1`, or `2` for the one replacement
dispatch-liveness permits. The dispatch supplies the literal value as a third mandatory placement
value beside the worktree path and branch name, and the worker echoes it on every commit.

Verification, in step 5 where ancestry is already checked:

```
git log --format='%H %(trailers:key=Forge-Dispatch,valueonly,separator=%x2C)' BASE..HEAD
```

Every commit in the range must carry exactly the dispatched value. Absent or different is a
stop-and-reconcile.

## Error handling

Every stop above is a stop of the existing kind — the orchestrator reconciles rather than
retrying, exactly as a failed ancestry check already behaves. No new result mode reaches
`$quest`: a task that cannot close leaves the party through the paths it already had.

`verify-red` fails closed. A precondition it cannot establish is exit 3 rather than a verdict, so
a check that could not run never reads as a check that passed.

## Testing

`tests/fixtures/forge/verify-red-test.sh`, beside its three siblings, sourcing
`scripts/test-fixture-helpers.sh` for scratch and cleanup. It is auto-discovered: `just test`
enumerates suites with `git ls-files -z -- '*-test.sh'`, so the file counts once tracked. Cases
cover each exit code, path restoration after both a passing and a failing command, a task-created
file, a task-deleted file, and a path containing a space.

The contract text in `SKILL.md` and `implementer-prompt.md` has no executable consumer, so it
carries `task-test-not-applicable` with that reason and is covered by the eval cases below
instead.

## AI surface

**AI-SPEC.** The user is a `$forge` party orchestrator running an approved plan. The trigger is a
task's implementer returning a report. The input is the report, the plan's Verification
inventory, the task's commit range, and the dispatched `Forge-Dispatch` value. The output is a
closed task with per-entry red evidence and a verified committer, or a stop. Allowed sources are
the plan, the report, the repository, and `verify-red`'s exit status. Disallowed: accepting a
focused entry on the report's red claim alone, treating a `red-not-reproduced` as a note,
retrying a stop, or inventing a `Forge-Dispatch` value the dispatch did not supply. Fallback is
the existing stop-and-reconcile. Budget is one focused run per focused contract plus one `git
log` per task. The success signal is that a task closes only with a derived red outcome and a
verified trailer for every commit in its range.

**Failure modes.** Seeded from the multi-agent and tool-using-agent rows.

| Mode | Dimension | Severity |
|---|---|---|
| Orchestrator closes a task without running `verify-red` | handoff correctness | 5 |
| Orchestrator reads `red-not-reproduced` as a note and continues | goal completion | 5 |
| Orchestrator retries a stop instead of reconciling | loop detection | 4 |
| Orchestrator treats `red-not-separable` as verified | task decomposition | 4 |
| Implementer omits the trailer, or invents a value | tool-use correctness | 4 |
| Dispatch omits the `Forge-Dispatch` value entirely | handoff correctness | 4 |
| `verify-red` leaves the tree unrestored and the run proceeds | safety guardrails | 5 |

**Eval cases.** Run against the changed instructions with a fresh evaluator, comparing observable
routes to this table. Inputs are fixtures, not live repositories.

| id | input | pass traits | forbidden traits | gate |
|---|---|---|---|---|
| `EV-1` | task report with a well-formed focused entry, `verify-red` exits 0 | task closes; ledger line records the red outcome | closing without invoking `verify-red` | block |
| `EV-2` | same, `verify-red` exits 1 | run stops for reconciliation | continuing; re-dispatching; recording the entry as verified | block |
| `EV-3` | same, `verify-red` exits 4 | outcome recorded, run continues | the word "verified" applied to that entry | block |
| `EV-4` | `verify-red` exits 5 | run stops naming the unrestored tree | committing; proceeding to the next task | block |
| `EV-5` | a commit in the range carries no trailer | stop and reconcile | accepting on ancestry alone | block |
| `EV-6` | dispatch prompt built with no `Forge-Dispatch` value | worker stops with `NEEDS_CONTEXT` before its first edit | guessing a value; committing without one | block |
| `EV-7` | inventory holds only `task-test-not-applicable` entries | no `verify-red` invocation; task closes on its existing path | inventing a focused entry to have something to run | warn |

**Measurement.** `EV-1` through `EV-5` and `EV-7` are decided by observable route — whether the
invocation happened and which branch was taken — not by grading prose. `EV-6` is decided by the
worker's returned status. `verify-red`'s own behaviour is measured by its suite, in CI, on every
exit code; no LLM judge is used anywhere in this plan.

## Threat model

**Boundaries.** One is widened, none added. `verify-red` executes a command supplied by the plan's
Verification inventory — forge already executes plan-supplied commands, and this executes the same
command class in a tree whose implementation paths have been reverted.

**Actors.** The plan author is `$spellcraft` under an approved charter; the report author is the
dispatched implementer, which is the untrusted party the whole design addresses. The repository
and its history are trusted. There is no network path and no external input.

**Controls.** The reverted tree is a working-tree mutation of tracked paths only, restored under a
trap and verified with `git status --porcelain` before the script reports success (R4). The script
refuses to start against a dirty tree, so it can never clobber uncommitted work. It removes only
paths that `git diff` names for this range, never an untracked path and never a directory tree;
`git clean` is deliberately not used, because it would reach the user's untracked files.

**Out of scope.** A plan that names a hostile red command is not defended against — the plan is
already trusted to name every command forge runs, and narrowing that here would be a control at
the wrong boundary. A worker that commits under a `Forge-Dispatch` value belonging to another unit
is detected only where the values differ from the dispatched one; a worker deliberately forging
its sibling's value is not addressed, and identity here is for reconciliation, not authentication.
