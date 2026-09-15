# Network bounds for shipped executables

Apply this convention to every `git` and `gh` call a shipped executable in this repository
makes. It is the standard [ADR 0068](../docs/adr/0068-a-timeout-is-not-an-answer.md) records;
that record carries the reasoning, this file carries what to do. Local subprocesses that reach
no network — `git rev-parse --local-env-vars` and the like — are outside it, and so is retry or
backoff, which this convention does not authorize anywhere.

## The invariant

**A timeout is not an answer.** A call that exceeded its bound did not report that the condition
under test is false, that a record is absent, or that a count is zero. It reported nothing. Every
rule below exists to keep that distinction intact from the call site to whatever the caller acts
on.

## The mechanism

Trap-free, Bash 3.2, and nothing macOS does not ship. The EXIT trap slot is already taken in
every target, and one of them is sourced and cannot install a trap at all, so no rule here uses
one.

```bash
# Run a command under a bound. Returns the command's own status, or 124 when the
# bound was exceeded. stdout and stderr land in separate caller-owned files: a
# merged capture once made a gh release notice part of a value a caller then
# decided labels from.
bounded_call() { # seconds out-file err-file command...
	local bound=$1 out=$2 err=$3 pid waited=0 status=0
	shift 3
	"$@" >"$out" 2>"$err" &
	pid=$!
	# Tenths, so the counter stays integer arithmetic on a Bash 3.2 floor.
	while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$((bound * 10))" ]; do
		sleep 0.1
		waited=$((waited + 1))
	done
	if kill -0 "$pid" 2>/dev/null; then
		kill -9 "$pid" 2>/dev/null || :
		wait "$pid" 2>/dev/null || :
		return 124
	fi
	wait "$pid" || status=$?
	return "$status"
}
```

Adapt it to the call site rather than sharing one copy: the shapes differ, and a shared sourced
helper would couple otherwise independent changes. Three properties are not adaptable.

- **Capture to files, not to a command substitution.** `value=$(gh ...)` blocks in the parent
  and bounds nothing. A site that captures a value today reads it back out of the stdout file
  instead.
- **Keep the two streams apart.** `gh` writes non-fatal material to stderr while exiting 0.
- **Reap before returning.** The `wait` after `kill -9` is what stops the child outliving the
  call. Nothing here polls a *previous* invocation, keeps a PID file, or leaves a process for a
  later run to reason about.

`124` is this function's internal signal, borrowed from `timeout(1)`'s convention. It is never a
script's exit status.

## The bound

- **30 seconds** for a single request.
- **120 seconds** for a whole `--paginate` invocation. There is no per-request `gh` timeout, so a
  paginated call can only be bounded entire, and its effective per-page allowance shrinks as
  pages grow. State that in a comment at any paginated site, so the next reader does not mistake
  the number for a per-request one.

Reads and writes take the same number. What differs is what follows.

## Writes

A bound does not make a write atomic. A call killed after the write landed but before its
response came back leaves a published artifact the script cannot verify.

- Report such a call as **indeterminate** — the write may have landed — never as a failure.
- Do not retry it.
- Say which call it was, so an operator can look.

## Classification

Report a timeout in the executable's **own existing vocabulary**. Do not add an exit class to a
script that does not have one; the point is that a timeout is distinguishable from an answer, not
that every script grows the same number.

| Executable | A timeout reports as |
|---|---|
| `skills/return-to-town/scripts/publish-handoff` | `fault` — exit 2, its "could not run" class |
| `skills/quest/scripts/publish-forge-review` | `fail` — exit 1; it has no exit-2 class |
| `skills/bards-tale/scripts/collect-telemetry` | `die` — exit 1; its exit 2 is `usage`. In the tri-state a timed-out read is `error`, never `unknown(...)`, never a zero |
| `skills/quest-log/assets/cleared-dependencies.sh` | a nonzero return through the existing `cleared_dependency_err` diagnostic; it is sourced and never exits |

Whatever the status, the diagnostic names the call and says the bound was exceeded. A message
that reports a timeout as a missing record, a false condition, or an unknown value is the defect
this convention exists to prevent.

## What this does not cover

- **An aggregate budget.** A per-call bound does not bound a run. A script that makes many calls
  serially can still take far longer than any single bound allows; whether it needs an overall
  budget is that script's own question.
- **Orphans after the script itself dies.** Each bounded call reaps its own child, so no child
  outlives the call. A script killed mid-call leaves the same orphan it would today.
