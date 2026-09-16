# Plan — bound collect-telemetry's six gh reads

**Goal.** Put every `gh` read in `skills/bards-tale/scripts/collect-telemetry` under the network
bound recorded in `references/network-bounds.md`, so a black-holing remote cannot hang an
unattended worker, and make a read killed at its bound report as the failed read it is.

**Architecture.** One `bounded_call` (verbatim from the reference) plus one thin `bounded_read`
adapter sit above the six existing single-call fetch functions. Each fetch function becomes a
one-statement wrapper swap: the call already redirected to a file, so nothing is restructured.
`bounded_read` sets the `fetch_failed` / `fetch_timed_out` pair the rest of the script already
branches on, so no metric-position logic changes.

**Tech stack.** Bash only. No new dependency, no new required command.

Design: `docs/workflow/specs/2026-09-15-collect-telemetry-network-bounds-design.md`.
Failure model: that spec's `## Failure model`.

Expected implementation size: 200–250 changed lines (M) — from the file map below: a bound
validator, `bounded_call` and `bounded_read`, six wrapper swaps and two hard-stop diagnostics in
the collector; three hang scenarios, three refusal cases and one mutual-exclusion assertion in
its suite; and one version field.

## Global Constraints

- **Bash 3.2 is the floor** (macOS ships 3.2.57). No `mapfile`, no `readarray`, no associative
  arrays. `#!/usr/bin/env bash`, `set -euo pipefail`, **tab** indentation.
- macOS does not ship `timeout(1)`, and ADR 0068 decides GNU coreutils does not become a
  dependency. Nothing here adds a required command.
- The EXIT trap slot in this file is taken at `:111`; the mechanism is trap-free.
- Capture a scan's exit status explicitly; never trail `|| true`.
- Prefer lines ≤ 100 characters.
- `rg` in gate scripts passes `--no-config`.
- Guardrails: `just lint`, `just format-check`, `just test collect-telemetry`, and the full
  `just verify`. Run them bare — the exit status is the verdict.
- `BASE_BRANCH` is `main`. Branch: `feat/bound-collect-telemetry-387`.
- `.claude-plugin/plugin.json` `version` is **exactly `5.10.3`** (campaign-assigned).
- The repository is public: no host paths, hostnames, addresses, or credentials in any file.

## File map

| File | Owns now | Owns after |
|---|---|---|
| `skills/bards-tale/scripts/collect-telemetry` | six unbounded `gh` reads, a 0/1 `fetch_failed` flag, two hard stops printing a constant as a `gh` exit | the same six reads under a bound, `fetch_failed` carrying the call's own status, `fetch_timed_out` beside it, two hard stops that distinguish a bound from a `gh` exit |
| `tests/fixtures/bards-tale/collect-telemetry-test.sh` | behaviour coverage for the tri-state, the rate-limit cutoff and the selection abort | the same, plus a deterministic hang and four timeout scenarios |
| `.claude-plugin/plugin.json` | `version` | `version` at `5.10.3` |

No file moves; no caller migrates; no path becomes obsolete. The six fetch functions are already
the right owner of one read each, so this is a clean extension of an existing boundary.

## Task 1 — bound the six reads

Creates: nothing. Modifies: the three files above. Tests:
`tests/fixtures/bards-tale/collect-telemetry-test.sh`.

**Interfaces.** This task defines, and nothing earlier supplies:

- `bounded_call <seconds> <out-file> <err-file> <command...>` → the command's own status, or
  `124` when the bound was exceeded.
- `bounded_read <seconds> <destination> <command...>` → sets globals `fetch_failed` (the call's
  own status: `gh`'s exit code, or `124`) and `fetch_timed_out` (`1` only for `124`).
- `BOUND_ONE_REQUEST` / `BOUND_MANY_REQUESTS` — validated integers, defaulting to 30 and 120,
  overridable by `COLLECT_TELEMETRY_BOUND_ONE_REQUEST` / `COLLECT_TELEMETRY_BOUND_MANY_REQUESTS`.
- `check_bound <variable-name> <value>` → returns 0, or `die`s naming the variable and value.
- `fetch_err` — the one reused stderr capture path inside the existing `$work` root.

Consumed from the existing file, each confirmed present at `main` `1c40c98`: `die()` at `:88`,
`work` at `:101`, the EXIT trap at `:111`, `SEARCH_LIMIT` at `:77`, and `$repo` / `$owner` /
`$name` set at `:812-814`.

### Verification

| Contract | Mode |
|---|---|
| A hung hard-stop read exits 1 with a bound diagnostic | `focused-test` — `collect-telemetry-test.sh`, new "bounded reads" scenarios. Red before the change: the run hangs instead of exiting. Green: `just test collect-telemetry` |
| A hung per-issue read lands `error`, not `unknown`, in every tri-state position it feeds | `focused-test` — same suite, `FAKE_GH_HANG=api` scenario. Red: the run hangs. Green: same command |
| A bound override that is not one to five digits without a leading zero is refused | `focused-test` — same suite, three cases. Red: the variable is unread, so the run succeeds instead of exiting non-zero. Green: same command |
| The two hard-stop forms exclude each other | `focused-test` — same suite; the existing selection-failure scenario gains an assertion that a `gh` nonzero exit prints `gh exit ` and *not* the bound clause. Red: the assertion is absent, so nothing proves the one-way substring is not the whole story. Green: same command |
| The envelope is unchanged | `focused-test` — the suite's existing assertions, unmodified. Green: same command |
| `version` at `5.10.3` | `task-test-not-applicable` — `scripts/check-plugin-version.sh` is the repository gate for this field; a second assertion would restate it |

### Steps

**1. Add the hang hook to the fake `gh`.** In `tests/fixtures/bards-tale/collect-telemetry-test.sh`,
immediately after the `printf 'gh %s\n' "$*" >>"${CALL_LOG:?}"` line inside the `FAKE_GH`
heredoc, insert:

```bash
# A read the suite wants to see bounded. `exec`, so the bound's TERM reaches
# this process directly and leaves no orphan behind; a plain child would be
# reparented. The duration never costs the suite anything -- the run waits for
# the bound, not for the sleep -- so it is set far above any bound the suite
# uses rather than tuned close to one, which is the flake in both directions.
if [[ ${FAKE_GH_HANG:-} == "$1" ]]; then
	exec sleep 300
fi
```

**2. Let `run_collector` forward the knobs.** In the same file, add these three lines to **each**
of the two environment prefixes inside `run_collector`, beside the existing `FAKE_DIR` line:

```bash
					FAKE_GH_HANG="${FAKE_GH_HANG:-}" \
					COLLECT_TELEMETRY_BOUND_ONE_REQUEST="${COLLECT_TELEMETRY_BOUND_ONE_REQUEST:-}" \
					COLLECT_TELEMETRY_BOUND_MANY_REQUESTS="${COLLECT_TELEMETRY_BOUND_MANY_REQUESTS:-}" \
```

They read the caller's **shell** variable rather than relying on an assignment prefix reaching a
function's environment, and an unset one forwards empty, which the collector's own `:-` defaults
absorb. Leave everything else in `run_collector` alone.

**3. Write the four failing scenarios.** Append them to the same file, immediately before the
`# --- usage ---` section. Note that each direct invocation spells its assignments out: a word
produced by expanding an array is no longer recognised as an assignment prefix.

```bash
# --- scenario: bounded reads ---------------------------------------------------
# The overrides put the timeout path within a second, so the hang the fake
# supplies is observed rather than waited out. The previous scenario removed
# search.json, which the first case here does not reach.
PATH="$SCRATCH/bin:$PATH" FAKE_DIR="$SCRATCH/fake" CALL_LOG="$SCRATCH/calls" \
	FAKE_GH_HANG=repo COLLECT_TELEMETRY_BOUND_ONE_REQUEST=1 \
	COLLECT_TELEMETRY_BOUND_MANY_REQUESTS=1 \
	"$collector" 'status:ready' >"$SCRATCH/stdout" 2>"$SCRATCH/stderr" &&
	fail 'a repository read that exceeded its bound must exit non-zero'
if jq -e . >/dev/null 2>&1 <"$SCRATCH/stdout"; then
	fail 'an aborted collection emitted a parseable document'
fi
assert_contains 'exceeded its 1s network bound' "$SCRATCH/stderr"
assert_contains 'repository could not be resolved: the call exceeded its network bound' \
	"$SCRATCH/stderr"

printf '%s\n' '[]' >"$SCRATCH/fake/search.json"
PATH="$SCRATCH/bin:$PATH" FAKE_DIR="$SCRATCH/fake" CALL_LOG="$SCRATCH/calls" \
	FAKE_GH_HANG=search COLLECT_TELEMETRY_BOUND_ONE_REQUEST=1 \
	COLLECT_TELEMETRY_BOUND_MANY_REQUESTS=1 \
	"$collector" 'status:ready' >"$SCRATCH/stdout" 2>"$SCRATCH/stderr" &&
	fail 'a selection read that exceeded its bound must exit non-zero'
assert_contains 'selection read failed: the call exceeded its network bound' "$SCRATCH/stderr"

# A per-issue read that exceeded its bound answered nothing, so every position it
# feeds is error. phase_build_hours is the sharp one: a timeline read that
# succeeds and returns no events yields unknown(no-events) there, so "error" is
# what separates a read that answered emptily from one that did not answer. The
# search-derived span stays a number, proving the timeout reaches only the
# positions the timed-out read fed.
rm -f "$SCRATCH"/fake/tl-*.json "$SCRATCH"/fake/issue-*.json \
	"$SCRATCH"/fake/prlist-*.json "$SCRATCH"/fake/pr-*.json
jq -nc '[{number: 301, state: "closed", createdAt: "2026-07-01T09:00:00Z",
	closedAt: "2026-07-01T14:00:00Z", labels: []}]' >"$SCRATCH/fake/search.json"
printf '%s\n' '{"comments":[]}' >"$SCRATCH/fake/issue-301.json"
printf '%s\n' '[]' >"$SCRATCH/fake/prlist-301.json"
FAKE_GH_HANG=api
COLLECT_TELEMETRY_BOUND_ONE_REQUEST=1
COLLECT_TELEMETRY_BOUND_MANY_REQUESTS=1
if ! run_collector 'status:ready'; then
	cat "$SCRATCH/stderr" >&2
	fail 'a per-issue read that exceeded its bound must not abort the run'
fi
FAKE_GH_HANG=
COLLECT_TELEMETRY_BOUND_ONE_REQUEST=
COLLECT_TELEMETRY_BOUND_MANY_REQUESTS=
assert_doc 'every position a timed-out timeline read feeds is error, never unknown' \
	'([.metrics.issues[] | select(.number == 301)][0]) |
	[.cycle_hours, .phase_build_hours, .phase_review_hours, .reopen_count,
	 .triage_latency_hours, .queue_wait_hours, .blocked_dwell_hours,
	 .human_response_hours, .rework_bounces, .review_drift_hours]
	| all(. == "error")'
assert_doc 'a span the timed-out read did not feed keeps its value' \
	'([.metrics.issues[] | select(.number == 301)][0].lead_time_hours) == 5'
assert_contains 'exceeded its 1s network bound' "$SCRATCH/stderr"

# The three refusals, each a value that would otherwise change the bound
# silently rather than be rejected: a non-digit that $(( )) would evaluate, a
# leading zero it would read as octal, and a six-digit value that overflows when
# multiplied by ten and collapses the bound to zero. search.json is written back
# first so that, before the collector reads the variable at all, this case
# reaches a clean exit 0 -- which is the red.
printf '%s\n' '[]' >"$SCRATCH/fake/search.json"
for bad in abc 08 100000; do
	PATH="$SCRATCH/bin:$PATH" FAKE_DIR="$SCRATCH/fake" CALL_LOG="$SCRATCH/calls" \
		COLLECT_TELEMETRY_BOUND_ONE_REQUEST="$bad" \
		"$collector" 'status:ready' >"$SCRATCH/stdout" 2>"$SCRATCH/stderr" &&
		fail "a bound override of '$bad' must exit non-zero"
	assert_contains 'COLLECT_TELEMETRY_BOUND_ONE_REQUEST' "$SCRATCH/stderr"
done
```

Then, in the **existing** `# --- scenario: selection failure aborts ---` block, add one line
after the `assert_contains 'selection read failed' "$SCRATCH/stderr"` line, so the two hard-stop
forms are proved to exclude each other rather than only to share a prefix:

```bash
assert_contains 'selection read failed (gh exit ' "$SCRATCH/stderr"
if rg --no-config -qF 'exceeded its network bound' "$SCRATCH/stderr"; then
	fail 'a gh nonzero exit must not be reported as a bound exceeded'
fi
```

**4. Confirm red, in the two shapes this change has.** The two shapes need two procedures,
because a suite that hangs and a suite that fails an assertion are not distinguishable by exit
status alone.

*The three hang contracts.* Their red is the hang itself, so it is discriminated against a
measured baseline rather than against a guess. First measure the baseline with the scenarios
absent — `git stash && time bash tests/fixtures/bards-tale/collect-telemetry-test.sh && git stash
pop`; on the development host that is about 85 seconds, exit 0. Then, with the scenarios present
and the collector unchanged:

```sh
bash tests/fixtures/bards-tale/collect-telemetry-test.sh >"$TMPDIR/red.log" 2>&1 &
suite=$!
sleep 240
if kill -0 "$suite" 2>/dev/null; then echo 'red: suite has outlived 3x its baseline'; fi
kill -TERM "$suite" 2>/dev/null || :
wait "$suite" 2>/dev/null || :
```

Expect `red: suite has outlived 3x its baseline` — the unbounded `gh repo view` is blocked on the
fake with nothing to end it. Substitute your own measured baseline if it differs; the number to
beat is that measurement, not 240. Terminating the suite leaves up to one orphaned `sleep 300`
per hang scenario reached, which exit on their own within five minutes; do not reach for a
host-wide `pkill`, which would also kill an unrelated process on a shared machine.

*The override contract.* Temporarily delete the three hang scenarios — everything from the
`# --- scenario: bounded reads ---` banner down to the
`printf '%s\n' '[]' >"$SCRATCH/fake/search.json"` line that opens the refusal loop — and run
`just test collect-telemetry` bare. Expect exit 1 naming `a bound override of 'abc' must exit
non-zero`: the collector does not read the variable yet, so it succeeds. Restore the scenarios
before step 5.

*The mutual-exclusion guard.* This one has no pre-implementation red, because it guards the
message that already exists at `main` against the branch this change adds. Bite it with a
controlled fault after step 9 instead: make the `elif ((fetch_failed))` arm of the selection hard
stop print the bound wording too, run `just test collect-telemetry`, expect exit 1 naming `a gh
nonzero exit must not be reported as a bound exceeded`, then revert the fault.

**5. Declare and validate the bounds.** In `skills/bards-tale/scripts/collect-telemetry`,
immediately after the `for tool in gh jq` loop, insert:

```bash
# Network bounds, per references/network-bounds.md: 30 seconds for a call that
# issues one request, 120 for one that may issue more. Overridable so the
# behaviour suite reaches the timeout path without waiting a field value out.
#
# All three clauses of the check are load-bearing, and each was measured on
# bash 3.2.57 rather than assumed. Non-digits: $(( )) evaluates a variable's
# contents recursively, so a crafted array subscript there runs a command
# substitution. A leading zero: $(( )) reads 08 as octal and errors, and 010 as
# 8 -- a bound changed silently rather than refused. More than five digits:
# bound * 10 overflows, the poll loop is skipped, and the bound collapses to
# zero, killing every call immediately. ${#2} is a string length, so the length
# test never evaluates the value.
check_bound() { # variable-name value
	local digits=0
	case $2 in
	'' | 0* | *[!0-9]*) digits=0 ;;
	*) digits=1 ;;
	esac
	if ((digits)) && ((${#2} <= 5)); then
		return 0
	fi
	die "$1 must be 1 to 99999 whole seconds, not '$2'"
}

BOUND_ONE_REQUEST=${COLLECT_TELEMETRY_BOUND_ONE_REQUEST:-30}
BOUND_MANY_REQUESTS=${COLLECT_TELEMETRY_BOUND_MANY_REQUESTS:-120}
check_bound COLLECT_TELEMETRY_BOUND_ONE_REQUEST "$BOUND_ONE_REQUEST"
check_bound COLLECT_TELEMETRY_BOUND_MANY_REQUESTS "$BOUND_MANY_REQUESTS"
```

**6. Allocate the stderr capture.** Immediately after the `trap cleanup EXIT` line, insert:

```bash
# One stderr capture, reused: the reads are serial, bounded_call truncates it per
# call, and $work is the mode-0700 root the trap above removes.
fetch_err="$work/fetch.err"
```

**7. Add the mechanism.** Insert this whole block immediately before the
`# --- issue-side reads ---` banner comment:

```bash
# --- network bounds -------------------------------------------------------------

# Run a command under a bound. Returns the command's own status, or 124 when the
# bound was exceeded. stdout and stderr land in separate caller-owned files.
# Verbatim from references/network-bounds.md; all seven of its non-adaptable
# properties hold here unchanged.
bounded_call() { # seconds out-file err-file command...
	# rc, not status: under zsh `status` is a read-only special parameter.
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

# One bounded gh read into DESTINATION, setting the pair every caller of the six
# fetch functions below reads. fetch_failed carries the call's own status -- gh's
# exit code, or 124 for a bound exceeded -- so the two hard stops can print a
# true number instead of a constant; fetch_timed_out says which of the two it
# was, because 124 is bounded_call's internal signal and never a gh exit.
#
# gh's stderr reached this script's stderr before the bound and still does. That
# channel is prose, so the braced redirect suppresses only the job notice bash
# prints for a signalled background job, which would otherwise interleave with
# the relay. The 124 line is the convention's standing obligation: a call that
# exceeded its bound reported nothing, and for a per-issue read this line is the
# operator's only account of why the metric says error.
bounded_read() { # seconds destination command...
	local bound=$1 destination=$2
	shift 2
	fetch_failed=0
	fetch_timed_out=0
	{ bounded_call "$bound" "$destination" "$fetch_err" "$@" || fetch_failed=$?; } 2>/dev/null
	if [[ -s $fetch_err ]]; then
		cat -- "$fetch_err" >&2
	fi
	if ((fetch_failed == 124)); then
		fetch_timed_out=1
		printf '%s: %s exceeded its %ss network bound and did not answer\n' \
			"${0##*/}" "$*" "$bound" >&2
	fi
}
```

**8. Swap the six reads.** Replace each fetch function body in place, keeping every existing
comment above it:

```bash
issue_side_repo() { # destination
	bounded_read "$BOUND_ONE_REQUEST" "$1" gh repo view --json nameWithOwner
}

issue_side_search() { # query destination
	# 120 seconds, not 30: --limit 200 is served by repeated requests even with
	# no --paginate flag, so this number bounds the whole call and never one
	# request -- the per-page allowance shrinks as the page count grows.
	bounded_read "$BOUND_MANY_REQUESTS" "$2" \
		gh search issues --repo "$repo" "$1" \
		--json number,state,closedAt,createdAt,labels --limit "$SEARCH_LIMIT"
}

issue_side_timeline() { # number destination
	# 120 seconds, not 30: --paginate issues an unbounded number of requests
	# under one invocation, so this number bounds the whole call and never one
	# request -- the per-page allowance shrinks as the page count grows.
	bounded_read "$BOUND_MANY_REQUESTS" "$2" \
		gh api "repos/${owner}/${name}/issues/$1/timeline" --paginate --jq '.[]'
}

issue_side_comments() { # number destination
	bounded_read "$BOUND_ONE_REQUEST" "$2" \
		gh issue view "$1" --repo "$repo" --json comments
}

pr_side_candidates() { # number destination
	bounded_read "$BOUND_ONE_REQUEST" "$2" \
		gh pr list --repo "$repo" --search "$1 in:body" --state merged \
		--json number,body
}

pr_side_view() { # pr-number destination
	bounded_read "$BOUND_ONE_REQUEST" "$2" \
		gh pr view "$1" --repo "$repo" \
		--json comments,additions,deletions,changedFiles,createdAt,mergedAt,commits,statusCheckRollup
}
```

**9. Distinguish the two hard stops.** Replace the single `((fetch_failed == 0)) || die ...`
line after `issue_side_repo "$work/repo.json"` with:

```bash
if ((fetch_timed_out)); then
	die 'repository could not be resolved: the call exceeded its network bound'
elif ((fetch_failed)); then
	die "repository could not be resolved (gh exit $fetch_failed)"
fi
```

and the one after `issue_side_search "$query" "$work/search.json"` with:

```bash
if ((fetch_timed_out)); then
	die 'selection read failed: the call exceeded its network bound'
elif ((fetch_failed)); then
	die "selection read failed (gh exit $fetch_failed)"
fi
```

**10. Record the bound in the file's contract header.** After the existing
`# - Every gh read belongs to one of two named groups:` bullet's paragraph, add:

```bash
# - Every gh read runs under the bound recorded in references/network-bounds.md:
#   30 seconds for a call that issues one request, 120 for one that may issue
#   more. A read killed at its bound answered nothing, so it is a failed read --
#   "error" at every metric position it feeds, never "unknown(...)", never a
#   zero. The document's shape is unchanged, so schema_version stays 1.6.
```

**11. Bump the plugin version.** Set `.claude-plugin/plugin.json`'s `version` to `5.10.3`.

**12. State the aggregate-budget decision in the PR body.** Issue #387 asks for this answer in
the PR, not only in a design file, so it is a deliverable of this task rather than shipping
prose. The PR body must carry, in its own short section: that there is no aggregate budget; that
`RATE_LIMIT_STOP` bounds only a uniformly failing remote because `consecutive_errors` resets at
`collect-telemetry:883`; the resulting worst case of roughly 9 hours for a 200-issue selection
with four issues in five carrying a hanging read; and that a run budget is reported as a
follow-up candidate because it needs a new envelope marker, a minor bump under ADR 0030, and a
renderer change in `skills/bards-tale/SKILL.md`, which this run may not touch.

**13. Confirm green.** Run, bare and in order:

- `just test collect-telemetry` — expect `ok tests/fixtures/bards-tale/collect-telemetry-test.sh`
  and `test: 1 suites passed`, exit 0.
- `just lint` — expect no output, exit 0.
- `just format-check` — expect no output, exit 0.
- `just verify` — expect the full chain green, exit 0, with `version-check` reporting that it
  checked the first two rules only (no `BASE_SHA` locally).

### Acceptance criteria

- `rg --no-config -c 'if ! gh ' skills/bards-tale/scripts/collect-telemetry` exits 1 with no
  match: that idiom is exactly the six old unbounded forms, and nothing else in the file uses it.
- `rg --no-config -c 'bounded_read "' skills/bards-tale/scripts/collect-telemetry` reports 6 —
  one call site per fetch function.
- `issue_side_search` and `issue_side_timeline` each carry the "bounds the whole call and never
  one request" comment.
- The suite's existing envelope assertion still requires `schema_version == "1.6"` and passes.
- The PR body carries the aggregate-budget section step 12 specifies.
- `just verify` exits 0.

### Rollback

Every change is additive or a like-for-like body swap inside one file plus its suite; reverting
the branch is the whole rollback. No state is written outside the existing scratch directory,
which the existing EXIT trap already removes.
