# 0068 — A timeout is not an answer

## Status

Accepted (2026-09-15)

## Context

Five shipped callers make `git` and `gh` calls, across eighteen invocation
expressions, and none of them carries a bound. Against an unreachable or
black-holing remote each blocks indefinitely. At a terminal that is visible and
interruptible; on an unattended queue it hangs the worker, which is issue #379.
That epic's acceptance criteria require the decision be applied to the
executables that make network calls rather than to one of them, so the decision
has to exist before any of them changes.

The callers, verified at `15fd217`: `publish-handoff:308,344,381,448,472`;
`publish-forge-review:242,260`; `cleared-dependencies.sh:82,171,186,234`;
`collect-telemetry:140,151,161,169,178,186`; and
`skills/quest-log/assets/profiles/github.sh:78`, the `github_run` wrapper that
`tracker.sh` sources and that serves every tracker operation. Issues #384, #386
and #387 apply this record to the first four. **The fifth has no applier
issue**, which is recorded here as a gap rather than closed here.

Three facts shape the decision, each checked in the tree rather than assumed.

**macOS does not ship `timeout(1)`.** `scripts/check-public-safety-test.sh:762-764`
already refused a `timeout`-based test leg for exactly this reason. Each of the
executed scripts refuses to run without every command on a fixed list —
`publish-handoff:104`, `publish-forge-review:48`, `collect-telemetry:97` — so
adding `timeout` to one of those lists makes that script refuse on a stock host.
Homebrew coreutils may supply `timeout` or `gtimeout` on a given machine; that is
a host accident, not a guarantee.

**The EXIT trap slot is already occupied in every target.**
`publish-forge-review:39`, `publish-handoff:97`, `collect-telemetry:111` and
`github.sh:76` each install one, and `cleared-dependencies.sh:66-73` records why
its sourced form cannot. So the mechanism has to be trap-free everywhere, which
usefully means one rule with no per-file exception.

**The exit taxonomy is not shared.** Both #379 and #382 generalize "exceeding the
bound exits 2" from `publish-handoff:17-19`. That reading holds for one file.

- `publish-handoff:17-19` — 0/1/2, where 2 is "could not run". `fault()` at `:61-64`.
- `publish-forge-review:41-43` — `fail()` = exit 1, and no exit-2 class anywhere.
- `collect-telemetry:88-91` — `die()` = exit 1; its exit 2 is `usage()` at `:78-86`.
- `cleared-dependencies.sh:325-332` — executed, 0/1/2, but **2 is usage**, not
  "could not run". Sourced only by its behaviour suite.
- `tracker.sh:18-26` — the richest of the five, and already correct:
  `EXIT_TRANSPORT=4` is precisely "the call did not answer", and `EXIT_PARTIAL=5`
  is "the write may have landed", which `github.sh:295-298` documents for a
  create that failed after possibly landing.

So a blanket exit-2 rule would be a contract change in three targets, would
collide with an existing usage class in two of them, and would discard a
taxonomy the fifth already has right.

## Decision

**One recorded convention, not a prescribed packaging.** `references/network-bounds.md`
carries the convention; each caller applies it at its own sites. The record
decides the idiom, the bound and the classification — not whether an applier
factors the idiom into a shared helper. Under this repository's own rule a
utility is warranted at the third repetition, so the applier that reaches it
makes that call and clears CLAUDE.md anatomy rule 2 with it; nothing here
forbids it.

**The mechanism is background, poll, kill, reap — trap-free.** Redirect the call's
stdout and stderr to separate files, run it in the background, capture `$!`, poll
`kill -0` against a tenth-second counter, then `kill -9` and `wait` to reap it and
recover its status. `scripts/check-public-safety-test.sh:762-789` already contains
this idiom. It is Bash 3.2-safe, needs no trap, and needs nothing macOS does not
ship. Exceeding the bound is signalled as return 124 — `timeout(1)`'s own
convention, and an internal return rather than any script's exit status.

**Stdout captured by a call that hit its bound is void.** The killed writer stopped
mid-stream, so a truncated capture is indistinguishable from a complete short
one — a half-written JSONL page from `--paginate --jq` parses cleanly and reads as
a smaller result set. The caller discards the capture on 124 and reports, rather
than parsing what arrived.

**A `git` call over SSH also sets `GIT_SSH_COMMAND`.** `kill -9` reaches `git`, not
the `ssh` child it spawned: the transport survives, reparented to init, still
holding the call's scratch files. `GIT_SSH_COMMAND='ssh -o ConnectTimeout=<n>
-o BatchMode=yes'` bounds the connect phase inside the transport that would
otherwise outlive the wrapper, and it is an environment variable for one call,
so it mutates no operator configuration. The wrapper stays as the outer bound for
the phases a connect timeout does not cover.

**The bound is 30 seconds for a call that issues one request and 120 seconds for
one that may issue more.** The trigger is the call's request count, not the
literal `--paginate` flag: `collect-telemetry:151` reaches `--limit 200` through
repeated requests without that flag. There is no per-request `gh` timeout, so a
multi-request call can only be bounded entire, and its effective per-page
allowance shrinks as pages grow. A multi-request site says so in a comment.

**Reads and writes take the same number; what differs is the obligation after it
is exceeded.** A bound does not make a write atomic. A call killed after
`gh issue comment` created the comment but before its URL came back leaves a
published block the script cannot verify. Such a call is reported as
**indeterminate** — the write may have landed — never as a failure, and it is not
retried. `github.sh:295-298` already reasons this way for an unretried create,
and `EXIT_PARTIAL` is the class it reports through.

**A timeout is classified in the caller's own existing vocabulary.** The invariant
that binds all five is that a timeout is not an answer: the diagnostic names the
call and says the bound was exceeded, and a timed-out call is never reported as a
negative or absent answer. Its expression is per-target, because three of the five
have no free "could not run" class and one already has a better one.

**GNU coreutils does not become a dependency.** `scripts/setup.sh` does not gain
it, and no required-command list gains `timeout` or `gtimeout`.

## Consequences

- A timed-out write is a new member of the post-write exit class
  `skills/return-to-town/SKILL.md:108-115` already reasons about, and a strictly
  weaker member: the script does not know whether the comment exists at all.
- #386 states it expects exit 2 in `publish-forge-review`. This record supersedes
  that expectation; adding an exit-2 class there would be a contract change its
  caller does not read, since `$quest` step 8 treats any nonzero the same way.
- `github.sh:78` has no applier issue. Applying this convention there needs one,
  or #379's criteria are met for four callers out of five.
- Timeouts count as failed reads in `collect-telemetry`, so against a dead remote
  they reach `RATE_LIMIT_STOP` and set a marker named `rate_limited` for a
  condition that is not rate limiting. #387 owns whether that marker is renamed.
- A per-call bound does not bound a run. `collect-telemetry` processes serially
  over a selection capped at 200, so its worst case is far larger than any single
  bound; #387 owns whether it needs an overall budget.
- Polling costs every call up to one interval of added latency, and the loop's own
  overhead accumulates: a 30-second bound fires at roughly 32 seconds on
  bash 3.2.57, not at 30.0. Nothing here depends on the difference, but a caller
  must not document the bound as exact.
- Each bounded call reaps the process it started. A transport child that process
  spawned is not reached by `kill -9` on it, which is why the `git` sites set a
  connect timeout as well; for `gh`, which performs its own HTTPS requests in
  process, there is no such child. A caller killed mid-call still orphans whatever
  was running, which is today's exposure unchanged.
- Four copies of one idiom will drift. That is the cost of not prescribing a
  shared helper now, and the reference is what they are checked against.
- The mechanism is a child a model has to reason about stopping only within one
  invocation, and CLAUDE.md anatomy rule 3 governs a process that survives
  *between* invocations — no PID file, no lockfile, no liveness check against a
  previous run. The precedent it extends lives in a test rather than in shipped
  code, which is stated here as the deliberate extension it is.
- `references/dispatch-liveness.md:55` documents a `timeout(1)`-based wait for a
  model-run background shell task. That is not a shipped executable and this
  record does not change it, but it carries the same stock-macOS exposure, which
  is recorded here and left to its own issue.

## Considered & rejected

- **Prescribing one shared sourced helper in this record.** judgment: the shared
  thing #382 asks for is a documented idiom, and which applier extracts it into a
  file is an executable change this record's scope excludes. Recording the
  convention does not foreclose it; the Consequences name the drift it would fix.
- **Adding `timeout(1)`, and so GNU coreutils, as a hard dependency.** verified: at
  15fd217 `scripts/setup.sh:47` declares
  `REQUIRED_TOOLS='git rg shellcheck shfmt jq zsh actionlint zizmor prek claude'`,
  with no coreutils; macOS does not ship `timeout`; and
  `scripts/check-public-safety-test.sh:762-764` records the suite already refusing
  a `timeout`-based leg for that reason.
- **A blanket "exceeding the bound exits 2".** verified: at 15fd217
  `rg --no-config -n 'exit 2' skills/quest/scripts/publish-forge-review` reports no
  match; `collect-telemetry:78-86` and `cleared-dependencies.sh:325-332` both spend
  exit 2 on usage; and `tracker.sh:18-26` already classes a dead call as
  `EXIT_TRANSPORT=4`.
- **Relying on `GIT_SSH_COMMAND` alone, without the wrapper.** verified: at 15fd217
  on macOS, `GIT_SSH_COMMAND='ssh -o ConnectTimeout=3 -o BatchMode=yes' git ls-remote`
  against a black-holed address returns in 3.02 s leaving no surviving `ssh`, but it
  bounds only the connect phase and reaches no `gh` call, which is fifteen of the
  eighteen invocations.
- **An EXIT-trap or signal-handler bound.** verified: `publish-forge-review:39`,
  `publish-handoff:97`, `collect-telemetry:111` and `github.sh:76` each already
  install an EXIT trap, and `cleared-dependencies.sh:66-73` records why its sourced
  form cannot.
- **A per-request bound for the multi-request calls.** verified: gh 2.100.0 exposes
  no per-request timeout — `gh api --help` and `gh help environment` each report no
  match for `timeout`.
- **Reusing the precedent's one-second poll verbatim.** verified: the precedent polls
  a single call in a test, where a second is free; at eighteen invocations, and at
  `collect-telemetry`'s 200 issues by six reads, a one-second floor adds twenty
  minutes to a run. Both BSD `sleep` on macOS and GNU `sleep` accept a fractional
  argument, so the tenth-second poll costs no portability: at 15fd217 on macOS
  `sleep 0.1` exits 0 in 0.102 s, and the whole idiom smoke-tested under
  `/bin/bash` 3.2.57 returns 124 on a bound exceeded, 0 with stdout captured on
  success, and the callee's own 3 with stderr captured on failure.
- **Leaving the bound to each applier.** judgment: that is the divergence this
  record exists to prevent, and #379's acceptance criteria refuse it outright.
- **Doing nothing.** judgment: an unattended worker that hangs on an unreachable
  remote stops the queue it was dispatched from, and nothing else in the pipeline
  ends that wait.
