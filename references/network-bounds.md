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
every target, so no rule here uses one.

```bash
# Run a command under a bound. Returns the command's own status, or 124 when the
# bound was exceeded. stdout and stderr land in separate caller-owned files: a
# merged capture once made a gh release notice part of a value a caller then
# decided labels from.
bounded_call() { # seconds out-file err-file command...
	# rc, not status: under zsh `status` is a read-only special parameter, and a
	# `local status=0` in a sourced body once killed a caller's whole session --
	# cleared-dependencies.sh:5-16 carries that record.
	local bound=$1 out=$2 err=$3 pid waited=0 grace=0 rc=0
	shift 3
	"$@" >"$out" 2>"$err" &
	pid=$!
	# Tenths, so the counter stays integer arithmetic on a Bash 3.2 floor.
	while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$((bound * 10))" ]; do
		sleep 0.1
		waited=$((waited + 1))
	done
	if kill -0 "$pid" 2>/dev/null; then
		# TERM, then KILL only if TERM does not land. Never a bare KILL.
		kill -TERM "$pid" 2>/dev/null || :
		while kill -0 "$pid" 2>/dev/null && [ "$grace" -lt 20 ]; do
			sleep 0.1
			grace=$((grace + 1))
		done
		kill -KILL "$pid" 2>/dev/null || :
		wait "$pid" 2>/dev/null || :
		# The writer was killed mid-stream, so the capture is void. Emptying it
		# here makes that structural: a site that parses it anyway gets nothing,
		# not a truncated page that reads as a complete short one.
		: >"$out"
		return 124
	fi
	wait "$pid" || rc=$?
	return "$rc"
}
```

The grace window is two seconds: long enough for `git` to tear its transport down, short
enough to be noise against a 30- or 120-second bound.

Bash announces a signalled background job on the script's own stderr — `… Terminated: 15` —
and the `2>/dev/null` on `wait` does not suppress it, because the notice is printed before the
reap. Where that stderr is prose the notice is harmless noise beside the caller's own
diagnostic. **Where it is machine-parsed it is a contract break**: `github.sh:58-66` records
that `tracker.sh`'s stderr is a single JSON error object callers parse, and that a plain line
beside it breaks the parse on a run that otherwise succeeded. Such a site keeps the notice off
that channel by invoking the bound as `{ bounded_call … ; } 2>/dev/null`, which does suppress
it — the redirect is in place when the reap happens.

Adapt it to the call site. Seven properties are not adaptable.

- **Allocate the capture files privately.** `mktemp` (mode 0600), or a file inside an
  `mktemp -d` root (0700), removed on the caller's existing EXIT trap — never a `$$`-derived
  name in a shared temporary directory, where the capture is world-readable at the default
  umask and the `>` redirect will follow a pre-created symlink. This pins what all five callers
  already do: `github.sh`, `cleared-dependencies.sh`, `collect-telemetry`, `publish-handoff` and
  `publish-forge-review` each allocate through `mktemp`. Named without line numbers, because
  applying this convention moved every one of them.
- **Capture to files, not to a command substitution.** `value=$(gh ...)` blocks in the parent
  and bounds nothing. A site that captures a value today reads it back out of the stdout file
  instead. That is a restructuring, not a wrapper swap, and it was most of the work: twelve of
  the eighteen invocations captured into a command substitution, and only `collect-telemetry`'s
  six already redirected to a file. All five callers have since been restructured; `github_run`
  in `github.sh` was the last, in #394.
- **Keep the streams the site already keeps apart, apart.** `gh` writes non-fatal material to
  stderr while exiting 0, and two files where a site merged them once is what this preserves.
  A site that deliberately merges a diagnostic it discards on success — `cleared-dependencies.sh:102-104`
  records two — keeps doing that; the rule protects a captured *value*, not every stream.
- **Discard the stdout capture on 124.** The writer was killed mid-stream, so a truncated
  capture is indistinguishable from a complete short one. A half-written JSONL page parses
  cleanly and reads as a smaller result set. Report; do not parse what arrived. The function
  empties the file on that path so the obligation is structural rather than remembered — keep
  that line.
- **Escalate; never send a bare `KILL`.** `SIGKILL` cannot be handled, so a `git` severed by it
  never tears down the `ssh` or `git-remote-https` it spawned: the transport is reparented to
  init and holds the connection after the wrapper has returned. On `SIGTERM` `git` tears it down
  and no child survives. Measured on macOS at 15fd217 against a black-holed address, over both
  transports: TERM leaves no surviving child, KILL leaves one, reparented to pid 1. `KILL` stays
  as the escalation for a process that ignores TERM, which is what `timeout(1)` spends its `-k`
  flag on.
- **Reap before returning.** The `wait` after the escalation is what stops the process this call
  started outliving it. Nothing here polls a *previous* invocation, keeps a PID file, or leaves
  a process for a later run to reason about.
- **Capture the status at the call site.** Write `bounded_call <bound> "$out" "$err" <cmd> || rc=$?`,
  never a bare statement. Every caller here runs under `set -e`, where a bare call aborts the
  script the moment the bound is exceeded — before the line that would classify the breach or
  print the diagnostic, which is the one thing this convention exists to make happen.

`124` is this function's internal signal, borrowed from `timeout(1)`'s convention. It is never a
script's exit status.

## The bound

- **30 seconds** for a call that issues one request.
- **120 seconds** for a call that may issue more than one.

The trigger is the request count, not the literal `--paginate` flag: `collect-telemetry:257`
reaches `--limit 200` through repeated requests without it. There is no per-request `gh` timeout,
so such a call can only be bounded entire, and its effective per-page allowance shrinks as pages
grow. Say so in a comment at the site, so the next reader does not read the number as per-request.

The bound is not exact. Poll overhead accumulates, so a 30-second bound fires at roughly 32
seconds. Do not document it as a deadline.

## Writes

A bound does not make a write atomic. A call killed after the write landed but before its
response came back leaves a published artifact the script cannot verify.

- Report such a call as **indeterminate** — the write may have landed — never as a failure.
- Do not retry it.
- Say which call it was, so an operator can look.

`github.sh:421-424` already reasons this way for an unretried create, and reports it through
`EXIT_PARTIAL`.

## Classification

Report a timeout in the caller's **own existing vocabulary**. Do not add an exit class to a
script that does not have one, and do not take a number that script already spends on something
else; the point is that a timeout is distinguishable from an answer, not that every caller grows
the same number.

All five callers below now do this. `publish-handoff` was bounded in #384,
`publish-forge-review` and `cleared-dependencies.sh` in #386, `collect-telemetry` in #387, and
`github.sh` in #394.

| Caller | A timeout reports as |
|---|---|
| `skills/return-to-town/scripts/publish-handoff` | `fault` — exit 2, its "could not run" class |
| `skills/quest/scripts/publish-forge-review` | `fail` — exit 1; it has no exit-2 class |
| `skills/bards-tale/scripts/collect-telemetry` | `die` — exit 1; its exit 2 is `usage`. In the tri-state a timed-out read is `error`, never `unknown(...)`, never a zero |
| `skills/quest-log/assets/cleared-dependencies.sh` | exit 1 — its "degraded or partial" verdict; exit 2 is `usage`. Through the wrapper, a nonzero return carrying `cleared_dependency_err` |
| `skills/quest-log/assets/profiles/github.sh` | `EXIT_TRANSPORT` (4) — it already means "the call did not answer". Its stderr is a parsed JSON object, so this is the site that must brace the bound against the job notice |

Whatever the status, the diagnostic names the call and says the bound was exceeded. A message
that reports a timeout as a missing record, a false condition, or an unknown value is the defect
this convention exists to prevent.

## Raising a misfit

If applying this convention to a call site does not fit the mechanism — a shape none of the
above covers, or a classification that collides with something the script already reports —
raise it as a finding against issue #382 rather than working around it locally. A local
workaround is the divergence the record exists to prevent.

## What this does not cover

- **An aggregate budget.** A per-call bound does not bound a run. A script that makes many calls
  serially can still take far longer than any single bound allows; whether it needs an overall
  budget is that script's own question.
- **Orphans after the caller itself dies.** Each bounded call reaps the process it started. A
  caller killed mid-call leaves the same orphan it would today.
- **Classifying an interactive prompt.** `ssh` reads a passphrase or a host-key confirmation
  from `/dev/tty`, not from the redirected streams, so at an attended terminal a `git` call can
  sit on a prompt until the bound fires and then be reported as a bound exceeded. The bound
  contains it; it does not name it. An applier that wants the sharper diagnostic sets
  `GIT_TERMINAL_PROMPT=0` for the call, which is a fail-fast knob and not the connect timeout
  ADR 0068 rejected. Unattended there is no controlling terminal and the call fails fast anyway.
- **PID reuse.** Bash reaps the background child as soon as it exits, freeing its PID to the
  kernel, so a poll that lands after a reuse sees an unrelated process as the call still running
  and signals it at the bound. The window is one poll interval, same-uid, and `kill -0` is the
  only Bash 3.2 idiom available; it is stated here so the next reader does not rediscover it.
