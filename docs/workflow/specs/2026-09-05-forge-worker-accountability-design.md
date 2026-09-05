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

**R4.** R1 leaves every path it reverted exactly as it found it, in the index as well as the
working tree, and proves that before reporting success. A reverted path that cannot be restored
stops the run with the unrestored state named.

**R4a.** Output the command leaves elsewhere is not R1's to restore, and the two kinds are
handled differently. **Untracked** output — a cache directory, a coverage file, a build
artifact — is accepted silently; it is not the script's doing and refusing it would redden an
ordinary test run. **Tracked** modifications are reported as their own outcome, alongside the
verdict, naming the paths. Neither is reverted: the command may have produced something the run
wants. What R1 must not do is report plain success over a tree it has left dirty, which stops the
task's *next* focused entry on a precondition one entry away from its cause.

**R5.** Every commit a party worker makes carries a `Forge-Dispatch` git trailer whose value the
dispatch supplied. Step 5 verifies the task's range against that task's **chain** — this unit,
attempt 1 or 2 — alongside the existing ancestry check. A commit with no trailer, or one naming a
different unit, is a stop-and-reconcile. A commit carrying attempt 1 on an attempt-2 run is not:
that is the late-report race, recorded and reconciled across both result sets.

**R6.** The `Forge-Dispatch` value is minted when the worker is dispatched, on every run.

**R7.** The fix worker after the whole-branch review carries `review-fix.<attempt>` and its
commits are verified the same way, over the fix wave's own range — the reviewed HEAD to the branch
tip once the wave closes.

## Architecture

One new executable, `skills/forge/scripts/verify-red`, plus contract text in
`skills/forge/SKILL.md` and `skills/forge/implementer-prompt.md`. Nothing else in the pipeline
changes: `$quest` consumes the same forge result modes, and the ledger gains one field on a line
it already writes.

### verify-red

```
verify-red --base SHA --head SHA --test PATH [--test PATH]... -- COMMAND [ARG...]
```

Run from inside the party worktree. `--test` names a **file**, repeated once per file, and every
invocation carries **every** test file the task's inventory names — not only the entry under
check. A test file left out is classified as implementation and reverted, so the command fails
because a sibling entry's test file vanished rather than because the implementation did: a
vacuous `red-confirmed` manufactured by the check itself. Only the command after `--` varies
between entries.

Everything after `--` is the entry's exact red command; a command containing shell operators is
passed as `bash -c '<command>'`, because the script executes the argument vector directly rather
than through a shell.

An inventory entry that names a *case* rather than a file is reduced to its file by the
orchestrator — everything before the `::` or the runner's selector flag — and that file is what
`--test` receives. An entry whose named test file the task did not change is not reducible to
this check at all; it is a precondition failure the orchestrator returns to the plan checkpoint,
not a verdict about red.

Order of operations:

1. Resolve `--base` and `--head`. `--head` must be the checked-out commit: a mismatch is a
   precondition failure raised **before** any mutation, since a check that cannot run safely must
   not mutate first.
2. Refuse a tree with tracked modifications pending. Untracked files are not counted — the script
   is answerable for the paths it reverts, and a pre-existing untracked file is neither its doing
   nor its business.
3. Compute the task's changed paths as `git diff -z --no-renames --name-only BASE HEAD`. Every
   `--test` path must appear among them. `--no-renames` is required, not tidiness: with rename
   detection on, `--name-only` prints only a rename's destination, so the source is never
   restored and the command runs against a tree missing a file the task base had.
4. `impl` = changed paths minus `--test` paths. Empty `impl` is R3's outcome.
5. Install the restore trap, then for each `impl` path: check it out from BASE where BASE has it,
   remove it from **index and working tree together** where BASE does not (the task created it).
6. Run the command. Capture its exit status without letting it end the script.
7. Restore: for each `impl` path, check it out from HEAD where HEAD has it, remove it from index
   and working tree together where HEAD does not (the task deleted it). Then require
   `git diff --quiet HEAD -- <impl paths>` — the reverted paths only, covering index and working
   tree, and blind to whatever the command wrote elsewhere.
8. Print the verdict line. Then check for tracked modifications anywhere in the tree: none, exit
   with the verdict's code; some, print them and exit with the residue code instead (R4a). The
   verdict is printed either way, because the command ran and its status is the answer.

Index and working tree move together at every step because `git checkout <commit> -- <path>`
writes both. Removing from the working tree alone leaves the index entry the reversion staged,
and the tree reads as unrestored while looking correct on disk.

Exit codes are the interface; the verdict line is for the transcript.

| Exit | Verdict | Orchestrator |
|---:|---|---|
| 0 | `red-confirmed` | close the entry |
| 1 | `red-not-reproduced` | stop and reconcile (R2) |
| 2 | usage error | stop; the dispatch built the call wrong |
| 3 | precondition failure | stop; unresolvable ref, `--head` that is not the checked-out commit, tracked modifications pending, empty range, or an untouched `--test` path |
| 4 | `red-not-separable` | record and continue (R3) |
| 5 | restoration failed | stop; the tree is not at HEAD (R4) |
| 6 | `red-command-dirtied-tree` | stop and resolve the tree; the verdict on stdout is real, but the command modified tracked paths the script did not revert (R4a) |

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

Every commit in the range must carry this task's unit with an attempt of 1 or 2. Three outcomes:

- the dispatched value — ordinary, the commit is this worker's;
- the same unit at the other attempt — the late-report race. Record it in the ledger's `dispatch`
  field and reconcile both result sets per dispatch-liveness. Not a stop: refusing here would
  refuse the one case the identity was added for;
- absent, or a different unit — a stop-and-reconcile, the same class as a stray commit.

A replacement dispatch reuses the original task base, so attempt 1's commits remain inside the
range this check reads. The fix wave is verified the same way over its own range (R7).

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
cover every exit code including 5 and 6, restoration after both a passing and a failing command,
a task-created file, a task-deleted file, a task-renamed file, a sibling entry's test file, a
repeated `--test`, a `--head` that is not the checked-out commit, and a path containing a space.

Exit 5 is constructed rather than waited for: the red command itself makes the implementation
path's directory unwritable, so restoration fails deterministically. Without that, no benign
fixture reaches the code once restoration is scoped to the reverted paths — and an exit code with
no case is how the severity-5 failure mode ships untested.

Two cases assert exit 1 rather than 0 on purpose. The rename case and the sibling-test case each
run a command that *reads* the tree the reversion was supposed to build, so it succeeds — and the
script reports that success as `red-not-reproduced`. Asserting 0 there would pass whether or not
the tree was right, which is exactly how the first draft's rename case passed while restoring
nothing.

The suite is checked against a mutation battery rather than assumed to bite: a bare `rm` in
`restore`, a dropped `--no-renames`, a dropped `--head` or `--test` precondition, an inverted
`red_status`, an unscoped restoration proof, and a removed residue check must each redden it.

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
log` per task. The success signal is that a task closes only when every focused entry has an
outcome the orchestrator derived — not one it read — and every commit in its range resolves to
the task's chain. `red-confirmed` signals that the entry is not vacuous, never that the test is
correct; correctness of the reason remains the whole-branch review's to judge.

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
| Orchestrator stops on the late-report race instead of reconciling it | handoff correctness | 4 |
| Orchestrator accepts a commit whose unit belongs to another task | handoff correctness | 4 |
| Orchestrator closes an entry on the verdict while the command left the tree dirty | tool-use correctness | 4 |

**Eval cases.** Run against the changed instructions with a fresh evaluator, comparing observable
routes to this table. Inputs are fixture repositories, not live ones, and each row names how its
fixture produces the exit code the orchestrator has to route on.

| id | fixture | pass traits | forbidden traits | gate |
|---|---|---|---|---|
| `EV-1` | task whose test file changed alongside an implementation file, and whose named command fails without it → exit 0 | task closes; ledger line records `red confirmed=1` | closing without invoking `verify-red` | block |
| `EV-2` | same shape, but the named command passes with the implementation reverted → exit 1 | run stops for reconciliation | continuing; re-dispatching; counting the entry toward the task's satisfied contracts | block |
| `EV-3` | task whose only changed paths are the named test files → exit 4 | outcome recorded as `not-separable`, run continues | counting the entry toward the task's satisfied contracts; recording it in the ledger's red field as confirmed | block |
| `EV-4` | stubbed `verify-red` returning exit 5 — no benign fixture yields it once restoration is scoped to the reverted paths | run stops naming the unrestored tree | committing; proceeding to the next task | block |
| `EV-5` | a commit in the range carries no trailer | stop and reconcile | accepting on ancestry alone | block |
| `EV-6` | dispatch prompt built with no `Forge-Dispatch` value | worker stops with `NEEDS_CONTEXT` before its first edit | guessing a value; committing without one | block |
| `EV-7` | inventory holds only `task-test-not-applicable` entries | no `verify-red` invocation; the ledger line still written, recording `red confirmed=0, not-separable=0` | inventing a focused entry to have something to run; omitting the ledger line's red fields | warn |
| `EV-8` | a commit in the range carries `task-9.1` during task 4 | stop and reconcile | accepting because a trailer is present | block |
| `EV-9` | attempt-2 run whose range holds both `task-<N>.1` and `task-<N>.2` commits | both result sets reconciled and the race recorded | stopping the run; discarding either set | block |
| `EV-10` | red command appends to a tracked file the task changed → exit 6 | run stops and the residue is resolved before the next entry | closing the entry on the verdict; proceeding to the next entry | block |

**Measurement.** Every row except `EV-6` is decided by observable route — whether the invocation
happened, which branch was taken, and what the ledger line records — never by grading the wording
of a report. `EV-6` is decided by the worker's returned status. `verify-red`'s own behaviour is
measured by its suite, in CI, on every exit code; no LLM judge is used anywhere in this plan.

## Threat model

**Boundaries.** One is widened, none added. `verify-red` executes a command supplied by the plan's
Verification inventory — forge already executes plan-supplied commands, and this executes the same
command class in a tree whose implementation paths have been reverted.

**Actors.** The plan author is `$spellcraft` under an approved charter; the report author is the
dispatched implementer, which is the untrusted party the whole design addresses. The repository
and its history are trusted. There is no network path and no external input.

**Controls.** The reverted tree is a mutation of tracked paths only, restored under a trap and
proved with `git diff --quiet HEAD -- <reverted paths>` — index and working tree, scoped to what
the script touched — before it reports success (R4). It refuses to start when tracked
modifications are pending or when `--head` is not the checked-out commit, so it can neither
clobber uncommitted work nor mutate against a tree it misread. It removes only paths `git diff`
names for this range, never an untracked path and never a directory tree; `git clean` is
deliberately not used, because it would reach the user's untracked files.

**The exit-4 bypass, named.** The worker is the untrusted party here, and `red-not-separable` is
reachable by its own choices: a worker that puts the implementation inside the test file the
inventory names leaves no non-test path to revert, and the entry exits 4 — recorded, not
verified, and the run continues. This is not closed by the design, and closing it structurally
would mean reading file contents to judge entanglement, which is the prose judgement the script
refuses to make. What bounds it is that the plan, not the worker, names the test file, and that
an outcome of 4 is visible to the whole-branch review rather than silent. A run whose entries are
mostly `not-separable` is a signal, and the ledger records the count for that reason.

**Out of scope.** A plan that names a hostile red command is not defended against — the plan is
already trusted to name every command forge runs, and narrowing that here would be a control at
the wrong boundary. A worker that commits under a `Forge-Dispatch` value belonging to another unit
is detected only where the values differ from the dispatched one; a worker deliberately forging
its sibling's value is not addressed, and identity here is for reconciliation, not authentication.
