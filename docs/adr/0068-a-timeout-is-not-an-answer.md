# 0068 — A timeout is not an answer

## Status

Accepted (2026-09-15)

## Context

Four shipped executables make `git` and `gh` calls, across fourteen call sites,
and none of them carries a bound. Against an unreachable or black-holing remote
each blocks indefinitely. At a terminal that is visible and interruptible; on an
unattended queue it hangs the worker, which is issue #379. That epic's
acceptance criteria require the decision be applied to the executables that make
network calls rather than to one of them, so the decision has to exist before
any of them changes. Issues #384, #386 and #387 apply it.

Three facts shape the decision, each checked in the tree rather than assumed.

**macOS does not ship `timeout(1)`.** `scripts/check-public-safety-test.sh:762-764`
already refused a `timeout`-based test leg for exactly this reason. Each of the
three *executed* scripts refuses to run without every command on a fixed list —
`publish-handoff:104`, `publish-forge-review:48`, `collect-telemetry:97` — so
adding `timeout` to one of those lists makes that script refuse on a stock host.
Homebrew coreutils may supply `timeout` or `gtimeout` on a given machine; that is
a host accident, not a guarantee.

**The EXIT trap slot is already occupied in all four.** `publish-forge-review:39`,
`publish-handoff:97` and `collect-telemetry:111` each install one, and
`cleared-dependencies.sh:66-73` cannot install one at all, because that file is
sourced: "a trap installed here would take the slot from whichever skill sourced
it". So the mechanism has to be trap-free everywhere, which usefully means one
rule with no per-file exception.

**The exit taxonomy is not shared.** Both #379 and #382 generalize "exceeding the
bound exits 2" from `publish-handoff:17-19`. That taxonomy belongs to
`publish-handoff` alone. `publish-forge-review:41-43` has `fail()` = exit 1 and
carries no exit-2 class anywhere in the file. `collect-telemetry:88-91` has
`die()` = exit 1, and its only exit 2 is `usage()` at `:78-86` — a usage class a
timeout must not collide with. `cleared-dependencies.sh` is sourced: it returns a
status and never exits at all. A blanket exit-2 rule would be a contract change
in three of the four targets, and inapplicable in one of them.

## Decision

**One recorded convention, not one shared implementation.**
`references/network-bounds.md` carries the convention; each executable implements
it at its own call sites. The shared thing is the decision, not the code. The
four call shapes differ materially — a stdout-capturing wrapper that keeps stderr
on a separate scratch file, plain direct calls, and paginated invocations — and a
shared sourced helper would couple three otherwise independent applier pull
requests to one merge order while crossing skill directory boundaries.

**The mechanism is background, poll, kill, reap — trap-free.** Redirect the
call's stdout and stderr to separate scratch files, run it in the background,
capture `$!`, poll `kill -0` against a counter, then `kill -9` and `wait` to reap
it and recover its status. `scripts/check-public-safety-test.sh:762-789` already
contains this idiom. It is Bash 3.2-safe, needs no trap, and needs nothing macOS
does not ship. The poll interval is 0.1 s rather than that precedent's 1 s,
because the precedent polls one call in a test and this runs at fourteen call
sites; the counter therefore counts tenths, which keeps the arithmetic integer.
Exceeding the bound is signalled to the caller as return 124 — `timeout(1)`'s own
convention, reused because it is unambiguous here, and an internal return rather
than any script's exit status.

**The bound is 30 seconds for a single request and 120 seconds for a whole
paginated invocation.** The 30 is the count the existing in-repo idiom already
polls to. There is no per-request `gh` timeout, so `--paginate` can only be
bounded as one invocation, whose effective per-page allowance therefore shrinks
as pages grow; 120 is four times the single-request bound, which covers a handful
of pages, and a paginated site states in a comment that its bound is a
whole-invocation budget rather than a per-request one.

**Reads and writes take the same number; what differs is the obligation after it
is exceeded.** A bound on a write does not make the write atomic. A call killed
after `gh issue comment` created the comment but before its URL came back leaves a
published block the script cannot verify. Such a call is reported as
**indeterminate** — the write may have landed — never as a failure, and it is not
retried, which this record does not authorize anywhere.

**A timeout is classified in the script's own existing vocabulary.** The invariant
that binds all four is that a timeout is not an answer: the diagnostic names the
call and says the bound was exceeded, and a timed-out call is never reported as a
negative or absent answer. Its expression is per-target — `fault` (exit 2) in
`publish-handoff`, which has that class; `fail` (exit 1) in `publish-forge-review`,
which does not; `die` (exit 1) in `collect-telemetry`, whose exit 2 is taken, and
`error` rather than `unknown(...)` or a zero in its tri-state; and a nonzero return
through the existing `cleared_dependency_err` diagnostic in the sourced file.

**GNU coreutils does not become a dependency.** `scripts/setup.sh` does not gain
it, and no required-command list gains `timeout` or `gtimeout`.

## Consequences

- A timed-out write is a new member of the post-write exit class
  `skills/return-to-town/SKILL.md:108-115` already reasons about, and a strictly
  weaker member: the script does not know whether the comment exists at all.
- #386 states it expects exit 2 in `publish-forge-review`. This record supersedes
  that expectation; adding an exit-2 class there would be a contract change its
  caller does not read, since `$quest` step 8 treats any nonzero from that helper
  the same way.
- Timeouts count as failed reads in `collect-telemetry`, so against a dead remote
  they reach `RATE_LIMIT_STOP` and set a marker named `rate_limited` for a
  condition that is not rate limiting. #387 owns whether that marker is renamed.
- A per-call bound does not bound a run. `collect-telemetry` processes serially
  over a selection capped at 200, six reads each, so its aggregate wall time is a
  separate question this record does not answer; #387 owns it.
- Polling costs every call up to one interval of added latency, so a bounded call
  is never faster than about 0.1 s. Over `collect-telemetry`'s worst case — 200
  issues, six reads each — that is roughly two minutes added to a run whose calls
  already dominate it. It is the price of not having `timeout(1)`.
- The bound is granular to the poll interval, so a call is killed at 30.0–30.1 s
  rather than at 30 exactly. Nothing here depends on the tenth.
- Each bounded call reaps its own child before returning, so no child outlives the
  call. The remaining orphan window is the script itself being killed mid-call,
  which is today's exposure unchanged and not what this record bounds.
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

- **A shared sourced helper all four adopt.** judgment: one wrapper covering a
  stdout-capturing call that must keep stderr separate, plain direct calls, and
  paginated invocations is more complex than four local adaptations, and it would
  serialize #384, #386 and #387 behind whichever pull request lands it.
- **Adding `timeout(1)`, and so GNU coreutils, as a hard dependency.** verified: at
  15fd217 `scripts/setup.sh:47` declares
  `REQUIRED_TOOLS='git rg shellcheck shfmt jq zsh actionlint zizmor prek claude'`,
  with no coreutils; macOS does not ship `timeout`; and
  `scripts/check-public-safety-test.sh:762-764` records the suite already refusing
  a `timeout`-based leg for that reason.
- **A blanket "exceeding the bound exits 2".** verified: at 15fd217
  `rg --no-config -n 'exit 2' skills/quest/scripts/publish-forge-review` reports no
  match; `collect-telemetry:78-86` spends exit 2 on `usage()`; and
  `cleared-dependencies.sh` is sourced and never exits.
- **Reusing the precedent's one-second poll verbatim.** verified: the precedent
  polls a single call in a test, where a second is free; at fourteen call sites,
  and at `collect-telemetry`'s 200 issues by six reads, a one-second floor adds
  twenty minutes to a run. Both BSD `sleep` on macOS and GNU `sleep` accept a
  fractional argument, so the tenth-second poll costs no portability: at 15fd217
  on macOS, `sleep 0.1` exits 0 in 0.102 s, and the whole idiom smoke-tested
  under `/bin/bash` 3.2.57 returns 124 on a bound exceeded, 0 with stdout
  captured on success, and the callee's own 3 with stderr captured on failure.
- **An EXIT-trap or signal-handler bound.** verified: `publish-forge-review:39`,
  `publish-handoff:97` and `collect-telemetry:111` each already install an EXIT
  trap, and `cleared-dependencies.sh:66-73` records why a sourced file cannot.
- **A per-request bound for the paginated calls.** verified: gh 2.100.0 exposes no
  per-request timeout — `gh api --help` and `gh help environment` each report no
  match for `timeout`.
- **`git` and SSH transport knobs instead of a wrapper.** verified: this
  repository's `origin` is `git@github.com:randomparity/adept.git`, so the SSH
  transport carries `git ls-remote` and `http.lowSpeedTime` does not reach it;
  the knobs that would are `ssh_config` settings, they bound no `gh` call, and
  setting them means mutating the operator's own configuration.
- **Leaving the bound to each applier.** judgment: that is the divergence this
  record exists to prevent, and #379's acceptance criteria refuse it outright.
- **Doing nothing.** judgment: an unattended worker that hangs on an unreachable
  remote stops the queue it was dispatched from, and nothing else in the pipeline
  ends that wait.
