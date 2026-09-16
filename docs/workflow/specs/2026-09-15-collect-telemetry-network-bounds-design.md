# Bounding collect-telemetry's six gh reads

Issue [#387](https://github.com/randomparity/adept/issues/387), part of epic #379. Applies
[`references/network-bounds.md`](../../../references/network-bounds.md) and
[ADR 0068](../../adr/0068-a-timeout-is-not-an-answer.md). No new ADR: the mechanism, the bounds
and this caller's classification are already recorded, and the two questions ADR 0068 delegates
here are answered by applying [ADR 0030](../../adr/0030-retrospective-telemetry-envelope-and-collector-contract.md)
and ADR 0068 rather than by a new decision.

## Problem

`skills/bards-tale/scripts/collect-telemetry` makes six `gh` reads, none bounded. Against a
black-holing remote each blocks forever, hanging an unattended worker. The script already has a
failure vocabulary a timeout has to fit into rather than extend: `die` is exit 1, exit 2 is
`usage`, and every metric position is a value, `unknown(<reason>)`, or `error`.

## Scope

### The mechanism

`bounded_call` is taken from `references/network-bounds.md` unchanged, including the line that
empties the stdout capture on 124. All seven non-adaptable properties hold here: the capture
files live inside the existing mode-0700 `mktemp -d` scratch root removed by the EXIT trap
already installed at `:111`; the six sites already redirect to files rather than capturing into a
command substitution, so each is a wrapper swap; stdout and stderr stay in separate files; the
escalation is TERM then KILL; the child is reaped; and every call captures its status.

One adapter, `bounded_read`, sits between `bounded_call` and the six fetch functions so the
mechanism appears once. It sets the two globals the rest of the script reads and relays the
captured stderr to the script's own stderr, which is where `gh`'s diagnostics went before the
bound and is prose, not a parsed channel. The job notice bash prints for a signalled background
job is suppressed with the reference's brace idiom so it cannot interleave with that relay.

### The failure signal

`fetch_failed` stops being a 0/1 flag and carries the call's own status: `gh`'s exit code, or
`124` when the bound was exceeded. Every existing reader tests it for zero or non-zero, so all
five sites keep working, and the two diagnostics that already print `gh exit $fetch_failed`
become true statements instead of printing the constant 1. A second global, `fetch_timed_out`,
is 1 exactly when the bound was exceeded; 124 is `bounded_call`'s internal signal, not a `gh`
exit, and keeping them in one variable would be the conflation ADR 0068 rejects.

### The bounds

Four reads issue one request and take 30 seconds: `gh repo view`, `gh issue view`, `gh pr list`
and `gh pr view`. Two may issue more and take 120 seconds: the timeline read at `:161`, which
paginates, and the search at `:151`, which reaches `--limit 200` through repeated requests with
no `--paginate` flag. Each of those two carries a comment saying the number bounds the whole
call and not each request, as the reference requires.

Both bounds are overridable by environment variable so the behaviour suite can exercise the
timeout path without waiting a field value out; the issue names that as an accepted way to make
the hang deterministic. Each value is refused unless it is one to five bare decimal digits with
no leading zero, checked before it reaches any arithmetic. All three clauses are load-bearing,
measured on bash 3.2.57 rather than assumed: bash evaluates a variable's contents recursively
inside `$(( ))`, where a crafted array subscript runs a command substitution; a leading zero
makes `$(( ))` error on `08` and read `010` as 8, changing the bound silently instead of refusing
it; and a bound above 99999 seconds is not a bound, while capping the digit count is also what
keeps the wrap out of reach — at nineteen digits `bound * 10` returns `-8446744073709551616`, the
poll loop never runs and the bound collapses to zero, killing every call at once. Five digits
settles the last two together without the validator reasoning about the shell's integer width. A
refused value is a `die`.

### Where a timeout lands

Nowhere new. A timed-out read sets `fetch_failed` non-zero exactly as a failed `gh` does, so the
existing branches already carry `error` into every tri-state metric position the read feeds, and
the emptied stdout capture means no `[[ -s $file ]]` branch can read a truncated capture as a
present one. The two hard stops gain a distinct diagnostic naming the bound.

The bounded set is the positions rendered through `metric_json`. `cycle_in_flight` is outside it
by the collector's existing design: it is a raw boolean companion to `cycle_hours`, not a
tri-state position, and it already reports `false` beside `cycle_hours: "error"` at `main` for
any failed `gh` timeline read. This change neither creates that nor alters it.

### Two delegated questions

**No aggregate budget.** The honest worst case first, since `RATE_LIMIT_STOP` does not supply
one: `consecutive_errors` resets at `:883` on any clean issue, so it bounds a *uniformly* failing
remote and not an intermittently failing one. A 200-issue selection where four issues in five
carry a hanging read can spend 160 × (120 + 30 + 30) = 28800 seconds — 8 hours — purely waiting
out bounds. Three reads, not four: `pr_side_view` is gated on `pr_ok` at `:554`, so a run cannot
hit that bound on an issue whose candidate read already failed. That is the answer to ADR 0068's
delegated question, and it is not "minutes".

The decision is still no aggregate budget, for a reason that does not depend on the circuit:
this convention exists to convert an unbounded hang into a finite, progress-making run, and it
does. Nine hours is bad; forever is a different category, and it is the one #379 is about. A run
budget is not a smaller version of this change — it needs a new envelope marker (the issue is
explicit that it cannot be called `rate_limited`), a minor bump under ADR 0030, and a renderer
change in `skills/bards-tale/SKILL.md`, which is outside this run's permitted surface. It is
reported as a follow-up candidate carrying the number above, not folded in here.

**No `schema_version` bump.** ADR 0030 bumps minor for an addition and major for a removal,
rename, re-type, re-nest, or a change to an existing sentinel's or envelope field's meaning.
Nothing is added and no sentinel changes meaning: ADR 0030 already defines `error` as "a `gh`
read failed (rate limit, 5xx, network — a fetch failure)", and a read that did not answer within
its bound is a network fetch failure under that existing definition. `rate_limited` is the one
envelope field whose *occurrence* changes, and its meaning does not: it marks fetch errors
stacked to `RATE_LIMIT_STOP`, a timeout is a fetch error, and before this change the same
condition produced no document at all rather than a document with a different marker. A field
that appears in runs that previously never finished is not a re-typed or re-meant field.
`SCHEMA_VERSION` stays `1.6`.

### Not in this change

The `rate_limited` marker keeps its name. Renaming it is a major bump under ADR 0030 requiring a
superseding record, and its only consumer, `skills/bards-tale/SKILL.md`, is outside this run's
permitted surface. Reported as a follow-up candidate. The `for tool in gh jq` preflight is
untouched: ADR 0068 decides GNU coreutils does not become a dependency. Retry and backoff are
excluded convention-wide. `jq` and the other local subprocesses reach no network and stay
unbounded.

## Failure model

**Actors and deployments**

- A local operator at a terminal running `$bards-tale`.
- An unattended worker running the same skill from a queue — the deployment this change exists
  for.
- The behaviour suite, which supplies a fake `gh` on `PATH` and sets the bound overrides.

**Invariants and assets at stake**

- The tri-state: a timed-out read must never present as `unknown(...)`, a zero, or JSON null.
- The stdout contract: exactly one JSON document, or a non-zero exit and no parseable document.
- No process outlives the call that started it.
- The envelope's shape, which a prior sidecar is parsed against.

**Accepted failure classes**

- The bound is approximate — poll overhead makes a 30-second bound fire near 32. Accepted and
  recorded by ADR 0068; nothing here reads it as a deadline.
- PID reuse inside one poll interval, same-uid. Accepted: `kill -0` is the only Bash 3.2 idiom
  available, and the reference records the window.
- A whole run can still take hours against an intermittently failing remote. Accepted with the
  measured figure and the reasoning in "Two delegated questions" above; finite is the property
  this change buys, and a run budget is a separate change reported as a follow-up candidate.
- `cycle_in_flight` stays a raw `false` beside a `cycle_hours` of `"error"`. Accepted: it is not
  a tri-state position, and this is `main`'s existing behaviour for any failed timeline read.
- A call killed by the operator mid-run orphans what was running, exactly as today. Accepted and
  named by the reference as outside the convention.

**Covered elsewhere**

- The other four bound appliers — issues #384 and #386, and `github.sh`, which ADR 0068 records
  as having no applier issue.
- The `rate_limited` misnomer — reported as a follow-up candidate, per the section above.
- `references/dispatch-liveness.md`'s `timeout(1)` use — ADR 0068 leaves it to its own issue.

## Threat model

The change adds one environment-variable entry point, which is the security trigger.

- **Boundary inventory.** *Added*: two environment variables read as network bounds. No existing
  boundary is widened; argv, `PATH` and the handling of `gh`'s responses are unchanged.
- **Actor model.** Whoever sets these variables is the same actor who supplies argv and `PATH`
  and who can already replace `gh` outright; the script trusts that actor completely and always
  has. `gh`'s responses remain untrusted input.
- **Control per boundary.** Each bound is rejected unless it is one to five bare decimal digits
  with no leading zero, before it reaches `$(( ))`. The digit rule stops bash's recursive
  arithmetic evaluation from running a command substitution hidden in an array subscript; the
  other two stop an octal reading and an overflow that would each silently change the bound
  rather than refuse it. On rejection the script `die`s, naming the variable and the value.
- **Explicitly out of scope.** Privilege escalation through these variables: not reachable, per
  the actor model. The content of `gh`'s captured stderr, relayed verbatim as before.

## Success

1. All six reads run under `bounded_call`; no `gh` invocation in the file is unbounded.
2. The two multi-request sites carry the bound-is-not-per-request comment.
3. A read killed at its bound lands as `error` in each tri-state metric position it feeds — the
   positions rendered through `metric_json`, never `unknown(...)`, never a zero, never null —
   proved by a suite case naming those positions explicitly.
4. The two hard stops say the bound was exceeded, and a `gh` nonzero exit says `gh exit <n>`
   instead; a suite case proves each form excludes the other.
5. A bound override that is not one to five digits without a leading zero is refused before any
   arithmetic.
6. Every assertion in the existing suite passes unmodified, and `schema_version` stays `1.6`.
7. `.claude-plugin/plugin.json` is at `5.10.3`.
8. The PR body states the aggregate-budget decision with the worst case it rests on, and states
   how the suite's hang is made deterministic. Issue #387 asks for both there.
9. A timed-out **comments** read is covered as well as a timed-out timeline read: its positions
   reach `error` only because the mechanism empties the stdout capture, so that line is proved
   rather than assumed.

## Validation

Every contract above is proved by `tests/fixtures/bards-tale/collect-telemetry-test.sh`, whose
fake `gh` gains a hang the suite selects per subcommand and runs under a one-second bound
override. The per-contract inventory, with each entry's red observation and green command, is the
Verification section of
`docs/workflow/plans/2026-09-15-collect-telemetry-network-bounds.md`.
