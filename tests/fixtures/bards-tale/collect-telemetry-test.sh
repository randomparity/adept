#!/usr/bin/env bash
set -euo pipefail

# ripgrep applies RIPGREP_CONFIG_PATH's contents as arguments ahead of the ones
# passed below, so a personal ripgreprc would otherwise steer this suite's own
# assertions.
unset RIPGREP_CONFIG_PATH

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=SCRIPTDIR/../../../scripts/test-fixture-helpers.sh
. "$script_dir/../../../scripts/test-fixture-helpers.sh"

# The suite lives in tests/fixtures/ so it is excluded from the installed
# payload. Everything it exercises does ship, so resolve those from the skill
# root once rather than counting `..` at each use.
skill_root=$(cd -- "$script_dir/../../../skills/bards-tale" && pwd -P)
collector="$skill_root/scripts/collect-telemetry"
fixture_init collect-telemetry-test

# Every assertion runs the emitted document through jq so a malformed stdout
# fails here instead of reading as a field mismatch.
assert_doc() { # description expression
	if ! jq -e "$2" >/dev/null 2>&1 <<<"$DOC"; then
		fail "$1: document does not satisfy: $2"
	fi
}

assert_contains() { # needle haystack-file
	if ! rg --no-config -qF "$1" "$2"; then
		fail "$1: not found in $2"
	fi
}

assert_count() { # description pattern file expected
	local observed
	observed=$(rg --no-config -c "$2" "$3" || true)
	if [[ ${observed:-0} != "$4" ]]; then
		fail "$1: expected $4 matches of '$2', observed ${observed:-0}"
	fi
}

# --- the fake gh --------------------------------------------------------------
# Dispatches on the subcommand and serves files from $FAKE_DIR, logging every
# invocation to $CALL_LOG so the suite can pin which reads ran. A response file
# that exists but is empty serves as a genuinely empty successful read (an
# empty timeline); one that does not exist makes the read fail non-zero --
# serve's exit 1 on the verbatim branches, jq's own exit status once the api
# branch projects through it -- which is how the tri-state and rate-limit
# cases model a failed gh read.
mkdir -p "$SCRATCH/bin"
printf '%s\n' '#!/usr/bin/env bash' >"$SCRATCH/bin/gh"
cat >>"$SCRATCH/bin/gh" <<'FAKE_GH'
set -euo pipefail
printf 'gh %s\n' "$*" >>"${CALL_LOG:?}"
# A read the suite wants to see bounded. Matched on the subcommand, or on the
# first two words where one subcommand is not enough: both PR-side reads arrive
# as `pr`, so `pr list` and `pr view` are only separable as a pair.
#
# FAKE_GH_PARTIAL is what makes the hang able to tell `bounded_call`'s
# capture-emptying line from its absence. A real gh killed at its bound has
# usually written part of a response already, and a truncated capture is
# non-empty, so every `[[ -s $file ]]` guard downstream reads it as a present
# answer. A hang that writes nothing leaves the capture empty either way and
# proves nothing about that line. The prefix goes out from a subshell, which
# flushes on exit -- `exec` replaces the image and would discard a buffered
# write.
#
# `exec`, so the bound's TERM reaches this process directly and leaves no orphan
# behind; a plain child would be reparented. The duration never costs the suite
# anything -- the run waits for the bound, not for the sleep -- so it is set far
# above any bound the suite uses rather than tuned close to one, which is the
# flake in both directions.
if [[ ${FAKE_GH_HANG:-} == "$1" || ${FAKE_GH_HANG:-} == "$1 ${2:-}" ]]; then
	if [[ -n ${FAKE_GH_PARTIAL:-} ]]; then
		(printf '%s' "$FAKE_GH_PARTIAL")
	fi
	exec sleep 300
fi
serve() {
	if [[ -e $1 ]]; then
		cat "$1"
	else
		exit 1
	fi
}
case $1 in
repo)
	# gh repo view --json nameWithOwner --jq .nameWithOwner
	printf '%s\n' '{"nameWithOwner":"example/repo"}'
	;;
search)
	# gh search issues --repo ... <query> --json ... --limit ...
	serve "${FAKE_DIR:?}/search.json"
	;;
api)
	# gh api repos/<owner>/<name>/issues/<N>/timeline --paginate --jq '.[]'.
	# The fake extracts the --jq program and projects the canned payload
	# through real jq in compact mode, so a fixture stores what GitHub
	# actually returns -- one page-shaped JSON array per call -- and the
	# collector receives the flattened JSONL real gh would emit. A jq
	# evaluation failure propagates non-zero.
	jq_expr=
	path_arg=
	expect_expr=0
	for arg in "$@"; do
		if ((expect_expr)); then
			jq_expr=$arg
			expect_expr=0
			continue
		fi
		case $arg in
		--jq) expect_expr=1 ;;
		*/issues/*) path_arg=$arg ;;
		esac
	done
	number=${path_arg##*/issues/}
	number=${number%%/*}
	if [[ -n $jq_expr ]]; then
		jq -c "$jq_expr" "${FAKE_DIR:?}/tl-$number.json"
	else
		serve "${FAKE_DIR:?}/tl-$number.json"
	fi
	;;
issue)
	# gh issue view <N> --repo ... --json comments
	for arg in "$@"; do
		case $arg in
		-* | --*) ;;
		*)
			if [[ $arg =~ ^[0-9]+$ ]]; then
				serve "${FAKE_DIR:?}/issue-$arg.json"
				exit 0
			fi
			;;
		esac
	done
	exit 1
	;;
pr)
	shift
	case $1 in
	list)
		# gh pr list --search "<N> in:body" --state merged --json number,body
		number=
		for arg in "$@"; do
			case $arg in
			*" in:body") number=${arg%% *} ;;
			esac
		done
		serve "${FAKE_DIR:?}/prlist-$number.json"
		;;
	view)
		# gh pr view <P> --repo ... --json ...
		for arg in "$@"; do
			case $arg in
			-*) ;;
			*)
				if [[ $arg =~ ^[0-9]+$ ]]; then
					serve "${FAKE_DIR:?}/pr-$arg.json"
					exit 0
				fi
				;;
			esac
		done
		exit 1
		;;
	esac
	;;
*)
	exit 64
	;;
esac
FAKE_GH
chmod +x "$SCRATCH/bin/gh"

run_collector() { # selector [prior-sidecar]
	CALL_LOG="$SCRATCH/calls"
	FAKE_DIR="$SCRATCH/fake"
	: >"$CALL_LOG"
	mkdir -p "$FAKE_DIR"
	# Bash 3.2 floor: an empty array under `set -u` cannot expand bare, so the
	# optional prior-sidecar argument rides a guarded expansion.
	prior_args=''
	if [[ -n ${2:-} ]]; then
		prior_args=$2
	fi
	if [[ -n $prior_args ]]; then
		DOC=$(
			PATH="$SCRATCH/bin:$PATH" \
				CALL_LOG="$CALL_LOG" \
				FAKE_DIR="$FAKE_DIR" \
				FAKE_GH_HANG="${FAKE_GH_HANG:-}" \
				FAKE_GH_PARTIAL="${FAKE_GH_PARTIAL:-}" \
				COLLECT_TELEMETRY_BOUND_ONE_REQUEST="${COLLECT_TELEMETRY_BOUND_ONE_REQUEST:-}" \
				COLLECT_TELEMETRY_BOUND_MANY_REQUESTS="${COLLECT_TELEMETRY_BOUND_MANY_REQUESTS:-}" \
				"$collector" "$1" "$prior_args" 2>"$SCRATCH/stderr"
		) || return 1
	else
		DOC=$(
			PATH="$SCRATCH/bin:$PATH" \
				CALL_LOG="$CALL_LOG" \
				FAKE_DIR="$FAKE_DIR" \
				FAKE_GH_HANG="${FAKE_GH_HANG:-}" \
				FAKE_GH_PARTIAL="${FAKE_GH_PARTIAL:-}" \
				COLLECT_TELEMETRY_BOUND_ONE_REQUEST="${COLLECT_TELEMETRY_BOUND_ONE_REQUEST:-}" \
				COLLECT_TELEMETRY_BOUND_MANY_REQUESTS="${COLLECT_TELEMETRY_BOUND_MANY_REQUESTS:-}" \
				"$collector" "$1" 2>"$SCRATCH/stderr"
		) || return 1
	fi
}

# --- fixture pieces -----------------------------------------------------------
mkdir -p "$SCRATCH/fake"

scope_block_101='<!-- WORK:SCOPE -->
## Scope — issue #101

- **outcome**: something
- complexity: M

<!-- SCOPE:COMPLETE -->'
review_block_211='<!-- WORK:REVIEW -->
## Review — PR #211

verdict: approve
exit: none
findings: 0
iterations: 2
security: not triggered

<!-- REVIEW:COMPLETE -->'
trajectory_decoy_101='<!-- WORK:TRAJECTORY -->
## Trajectory — issue #101

- phase: decoy-never-completed'
trajectory_block_101='<!-- WORK:TRAJECTORY -->
## Trajectory — issue #101

- **Branch/PR**: feat/trajectories-110
- phase: handoff
- pr: 219
- guardrails: just verify green
- surprises worth remembering: label history ran backwards

<!-- TRAJECTORY:COMPLETE -->'
divination_block_101='<!-- WORK:DIVINATION -->
## Divination — issue #101

blast radius: collector plus suite
complexity: S

<!-- DIVINATION:COMPLETE -->'

# --- scenario: success --------------------------------------------------------
# Two selected issues (an epic-labelled third is excluded), one fully
# instrumented and closed, one open and in flight. Timeline fixtures are
# page-shaped JSON arrays -- what GitHub's timeline endpoint returns per call;
# the fake gh applies the collector's '.[]' projection, so the suite also
# covers an element lacking .label entirely (the commented event below, with
# payload fields no metric reads). Under the old verbatim-serving fake that
# case was indistinguishable from a well-formed stream.
cat >"$SCRATCH/fake/search.json" <<'JSON'
[
 {"number":101,"state":"closed","createdAt":"2026-07-01T08:00:00Z",
  "closedAt":"2026-07-01T14:00:00Z","labels":[{"name":"risk:night-safe"}]},
 {"number":102,"state":"closed","createdAt":"2026-07-01T08:00:00Z",
  "closedAt":"2026-07-01T14:00:00Z","labels":[{"name":"epic"}]},
 {"number":103,"state":"open","createdAt":"2026-07-01T09:30:00Z",
  "closedAt":null,"labels":[]}
]
JSON
cat >"$SCRATCH/fake/tl-101.json" <<'JSON'
[
 {"event":"labeled","label":{"name":"status:ready"},"created_at":"2026-07-01T09:00:00Z"},
 {"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T10:00:00Z"},
 {"event":"labeled","label":{"name":"status:blocked"},"created_at":"2026-07-01T10:30:00Z"},
 {"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T11:00:00Z"},
 {"event":"labeled","label":{"name":"status:in-review"},"created_at":"2026-07-01T11:00:00Z"},
 {"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T12:00:00Z"},
 {"event":"labeled","label":{"name":"status:in-review"},"created_at":"2026-07-01T12:30:00Z"},
 {"event":"reopened","created_at":"2026-07-01T12:45:00Z"},
 {"event":"commented","body":{"body":"noise"},"actor":{"login":"ghost"}},
 {"event":"labeled","label":{"name":"status:awaiting-merge"},"created_at":"2026-07-01T13:30:00Z"},
 {"event":"closed","created_at":"2026-07-01T14:00:00Z"}
]
JSON
cat >"$SCRATCH/fake/tl-103.json" <<'JSON'
[
 {"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T09:00:00Z"}
]
JSON
jq -n --arg decoy "$trajectory_decoy_101" --arg scope "$scope_block_101" \
	--arg traj "$trajectory_block_101" --arg div "$divination_block_101" \
	'{comments: [{body:$decoy}, {body:$scope}, {body:$traj}, {body:$div}]}' \
	>"$SCRATCH/fake/issue-101.json"
printf '%s\n' '{"comments":[]}' >"$SCRATCH/fake/issue-103.json"
cat >"$SCRATCH/fake/prlist-101.json" <<'JSON'
[
 {"number":210,"body":"Part of #101"},
 {"number":211,"body":"Closes #101"}
]
JSON
jq -n --arg b "$review_block_211" '{comments:[{body:$b}],additions:300,deletions:100,
	changedFiles:7,createdAt:"2026-07-01T12:00:00Z",mergedAt:"2026-07-01T13:36:00Z",
	commits:[{committedDate:"2026-07-01T11:00:00Z"},
		{committedDate:"2026-07-01T12:30:00Z"},
		{committedDate:"2026-07-01T13:00:00Z"}],
	statusCheckRollup:[
	 {__typename:"CheckRun",name:"suite",startedAt:"2026-07-01T13:10:00Z",
	  completedAt:"2026-07-01T13:20:00Z"},
	 {__typename:"CheckRun",name:"verify",startedAt:"2026-07-01T13:12:00Z",
	  completedAt:"2026-07-01T13:30:00Z"},
	 {__typename:"StatusContext",name:"lint"}]}' >"$SCRATCH/fake/pr-211.json"
printf '%s\n' '[]' >"$SCRATCH/fake/prlist-103.json"

if ! run_collector 'status:ready'; then
	cat "$SCRATCH/stderr" >&2
	fail 'success scenario unexpectedly failed'
fi

assert_doc 'top-level envelope.' \
	'.schema_version == "1.6"
	and .selector == "status:ready"
	and .mode == "label-set"
	and (.generated_at | type == "string")
	and .truncated == false
	and .population.count == 2
	and .population.issues == [101, 103]
	and (.metrics | type == "object")
	and (has("rate_limited") | not)'
assert_doc 'issue 101 cycle: hours to one decimal, not floored days' \
	'([.metrics.issues[] | select(.number == 101)][0].cycle_hours) == 4'
assert_doc 'issue 101 phases' \
	'([.metrics.issues[] | select(.number == 101)][0]) |
	.phase_build_hours == 1 and .phase_review_hours == 2.5'
assert_doc 'issue 103 in-flight cycle is a number with the flag set' \
	'([.metrics.issues[] | select(.number == 103)][0]) |
	.cycle_in_flight == true and (.cycle_hours | type == "number")
	and .phase_build_hours == "unknown(no-events)"
	and .phase_review_hours == "unknown(no-events)"'

assert_doc 'issue 101 queue and rework metrics' \
	'([.metrics.issues[] | select(.number == 101)][0]) |
	.triage_latency_hours == 1 and .queue_wait_hours == 1
	and .blocked_dwell_hours == 0.5 and .rework_bounces == 1
	and .human_response_hours == 0.1 and .review_drift_hours == 0.9'
assert_doc 'PR resolved to the closing PR' \
	'([.metrics.issues[] | select(.number == 101)][0].pr) == 211'
assert_doc 'review fields parsed from the latest complete block' \
	'([.metrics.issues[] | select(.number == 101)][0]) |
	.review_iterations == 2 and .review_verdict == "approve"
	and .security == "not triggered" and .exit == "none"'
assert_doc 'LOC actual is additions plus deletions' \
	'([.metrics.issues[] | select(.number == 101)][0].loc_actual) == 400'
assert_doc 'issue 103 queue metrics are data gaps, dwell and bounces are measured zeros' \
	'([.metrics.issues[] | select(.number == 103)][0]) |
	.triage_latency_hours == "unknown(never-ready)"
	and .queue_wait_hours == "unknown(no-ready-anchor)"
	and .blocked_dwell_hours == 0 and .rework_bounces == 0
	and .human_response_hours == "unknown(never-awaiting-merge)"
	and .review_drift_hours == "unknown(no-review-phase)"'
assert_doc 'scope estimate extracted' \
	'([.metrics.issues[] | select(.number == 101)][0].scope_estimate) == "M"'
assert_doc 'cohort boundary and close instant for the instrumented issue' \
	'([.metrics.issues[] | select(.number == 101)][0]) |
	.scope_complete == true
	and .closed_at == "2026-07-01T14:00:00Z"'
assert_doc 'trajectory fields mined from the latest complete block only' \
	'([.metrics.issues[] | select(.number == 101)][0]) |
	.risk_band == "night-safe"
	and .trajectory_phase == "handoff"
	and .trajectory_branch == "feat/trajectories-110"
	and .trajectory_pr == 219
	and .trajectory_guardrails == "just verify green"
	and .trajectory_surprises == "label history ran backwards"'
assert_doc 'divination complexity and the miss-location chain verdict' \
	'([.metrics.issues[] | select(.number == 101)][0]) |
	.divination_complexity == "S" and .scope_miss_location == "divergent"'
assert_doc 'uninstrumented issue leaves every mined position a data gap' \
	'([.metrics.issues[] | select(.number == 103)][0]) |
	.risk_band == "unjudged"
	and .trajectory_phase == "unknown" and .trajectory_branch == "unknown"
	and .trajectory_pr == "unknown" and .trajectory_guardrails == "unknown"
	and .trajectory_surprises == "unknown"
	and .divination_complexity == "unknown"
	and .scope_miss_location == "unknown(no-divination)"'

assert_doc 'GitHub-native spans for issue 101' \
	'([.metrics.issues[] | select(.number == 101)][0]) |
	.lead_time_hours == 6 and .pr_lifespan_hours == 1.6
	and .full_delivery_hours == 5.6 and .merge_lag_hours == 0.6
	and .build_private_hours == 1 and .ci_wall_hours == 0.3
	and .reopen_count == 1'
assert_doc 'the label-less commented event shifts no metric' \
	'([.metrics.issues[] | select(.number == 101)][0]) |
	.cycle_hours == 4 and .blocked_dwell_hours == 0.5
	and .human_response_hours == 0.1 and .rework_bounces == 1'

assert_doc 'uninstrumented issue reports unknown, never zero' \
	'([.metrics.issues[] | select(.number == 103)][0]) |
	.pr == "unknown(no-closer)"
	and .review_iterations == "unknown(no-closer)"
	and .loc_actual == "unknown(no-closer)"
	and .scope_estimate == "unknown"
	and .review_verdict == "unknown"
	and .security == "unknown"
	and .exit == "unknown"
	and .scope_complete == false
	and .closed_at == "unknown(not-closed)"'
assert_doc 'open issue lead time is an incomplete span, never elapsed-so-far' \
	'([.metrics.issues[] | select(.number == 103)][0]) |
	.lead_time_hours == "unknown(not-closed)"
	and .reopen_count == 0
	and .pr_lifespan_hours == "unknown(no-closer)"
	and .full_delivery_hours == "unknown(no-closer)"
	and .merge_lag_hours == "unknown(no-closer)"
	and .build_private_hours == "unknown(no-closer)"
	and .ci_wall_hours == "unknown(no-closer)"'

assert_doc 'null-free invariant' \
	'[. | .. | select(type == "null")] | length == 0'
assert_doc 'aggregate stays flat and combined, as schema 1.4 fixed it' \
	'.metrics.aggregate.cycle_hours.count == 2
	and .metrics.aggregate.blocked_dwell_hours == {count: 2, median: 0.25, min: 0, max: 0.5}'
assert_doc 'cohort aggregates split instrumented from legacy' \
	'.metrics.cohorts.instrumented.cycle_hours == {count: 1, median: 4, min: 4, max: 4}
	and (.metrics.cohorts.legacy.cycle_hours.count) == 1
	and (.metrics.cohorts.legacy.cycle_hours.median | type == "number")
	and .metrics.cohorts.instrumented.human_response_hours
		== {count: 1, median: 0.1, min: 0.1, max: 0.1}
	and .metrics.cohorts.legacy.reopen_count.count == 1'
assert_doc 'combined quartiles gated below the N >= 20 threshold' \
	'.metrics.quartiles.cycle_hours == {count: 2}
	and .metrics.quartiles.lead_time_hours == {count: 1}
	and (.metrics.quartiles.cycle_hours | has("p25") | not)'
assert_doc 'weekly throughput: Monday-start bucket, instability-gated median' \
	'.metrics.throughput.weeks
	== [{week_start: "2026-06-29", closed_count: 1,
	     median_cycle_hours: "unknown(instability-rule)"}]'
assert_doc 'coverage counts value-state entries' \
	'.metrics.coverage == {
		cycle_hours: 2, phase_build_hours: 1, phase_review_hours: 1,
		pr: 1, review_iterations: 1, scope_estimate: 1, loc_actual: 1,
		lead_time_hours: 1, pr_lifespan_hours: 1, full_delivery_hours: 1,
		merge_lag_hours: 1, build_private_hours: 1, ci_wall_hours: 1,
		reopen_count: 2,
		triage_latency_hours: 1, queue_wait_hours: 1, blocked_dwell_hours: 2,
		human_response_hours: 1, rework_bounces: 2, review_drift_hours: 1,
		trajectory_phase: 1, divination_complexity: 1, scope_miss_location: 1}'
assert_doc 'risk-band segmentation gated behind the instability rule' \
	'.metrics.risk_band_cycle_hours["night-safe"].count == 1
	and .metrics.risk_band_cycle_hours["night-safe"].median == "unknown(instability-rule)"
	and .metrics.risk_band_cycle_hours["unjudged"].count == 1
	and .metrics.risk_band_cycle_hours["night-watch"].count == 0
	and .metrics.risk_band_cycle_hours["daytime-only"].count == 0'

assert_count 'every gh read is logged' '^gh ' "$SCRATCH/calls" 9
if rg --no-config -q 'graphql' "$SCRATCH/calls"; then
	fail 'collector issued a graphql read'
fi
if rg --no-config -q 'gh repo view .*--jq' "$SCRATCH/calls"; then
	fail 'repo read must capture raw JSON: a pre-projected --jq value cannot be re-parsed by the extraction jq'
fi

# --- scenario: date-range mode -------------------------------------------------
cat >"$SCRATCH/fake/search.json" <<'JSON'
[]
JSON
if ! run_collector '2026-07-01..2026-07-20'; then
	cat "$SCRATCH/stderr" >&2
	fail 'date-range scenario unexpectedly failed'
fi
assert_doc 'date-range mode and empty population' \
	'.mode == "date-range"
	and .population.count == 0
	and .truncated == false
	and .metrics.issues == []'
assert_contains 'closed:2026-07-01..2026-07-20' "$SCRATCH/calls"

# --- scenario: truncation ------------------------------------------------------
python3 - "$SCRATCH/fake/search.json" <<'PY'
import json, sys
issues = [{"number": n, "state": "closed",
           "closedAt": "2026-07-01T14:00:00Z", "labels": []}
          for n in range(1, 201)]
with open(sys.argv[1], "w") as fh:
    json.dump(issues, fh)
PY
for n in $(seq 1 200); do
	# An empty page array: '.[]' emits zero bytes, the same stream an
	# issue with no timeline events produces against real gh.
	printf '%s\n' '[]' >"$SCRATCH/fake/tl-$n.json"
	printf '%s\n' '{"comments":[]}' >"$SCRATCH/fake/issue-$n.json"
	printf '%s\n' '[]' >"$SCRATCH/fake/prlist-$n.json"
done
if ! run_collector 'status:ready'; then
	cat "$SCRATCH/stderr" >&2
	fail 'truncation scenario unexpectedly failed'
fi
assert_doc 'limit-equal population marks truncated' '.truncated == true'
# A current run that truncated cannot move against any prior population, so
# even an untruncated prior reports incomparable with the current-side reason.
cat >"$SCRATCH/prior-untruncated.json" <<'JSON'
{"schema_version":"1.5","selector":"status:ready","mode":"label-set",
 "generated_at":"2026-07-20T00:00:00Z","truncated":false,
 "population":{"count":1,"issues":[1]},
 "metrics":{"aggregate":{
   "cycle_hours":{"count":1,"median":9,"min":9,"max":9}}}}
JSON
if ! run_collector 'status:ready' "$SCRATCH/prior-untruncated.json"; then
	cat "$SCRATCH/stderr" >&2
	fail 'truncated-current scenario unexpectedly failed'
fi
assert_doc 'a truncated current run is incomparable against an untruncated prior' \
	'.truncated == true
	and .metrics.movement == {status:"incomparable",
		reason:"truncated-current"}'

# --- scenario: tri-state errors and the rate-limit cutoff ----------------------
# Seven selected issues. The first five timeline reads fail; the collector stops
# after five consecutive errored issues and emits a partial document carrying
# rate_limited, leaving issues 206 and 207 unprocessed.
rm -f "$SCRATCH"/fake/tl-*.json "$SCRATCH"/fake/issue-*.json \
	"$SCRATCH"/fake/prlist-*.json "$SCRATCH"/fake/pr-*.json
python3 - "$SCRATCH/fake/search.json" <<'PY'
import json, sys
issues = [{"number": n, "state": "closed",

           "closedAt": "2026-07-01T14:00:00Z", "labels": []}
          for n in range(201, 208)]
with open(sys.argv[1], "w") as fh:
    json.dump(issues, fh)
PY
for n in 206 207; do
	printf '%s\n' '[]' >"$SCRATCH/fake/tl-$n.json"
done
if ! run_collector 'status:blocked'; then
	cat "$SCRATCH/stderr" >&2
	fail 'rate-limit scenario unexpectedly failed'
fi
assert_doc 'partial document carries the explicit marker' \
	'.rate_limited == true and .population.count == 7'
assert_doc 'processed-but-errored issues carry error, not unknown' \
	'([.metrics.issues[] | select(.number == 203)][0].cycle_hours) == "error"'
assert_doc 'reopen count under a failed timeline read is error' \
	'([.metrics.issues[] | select(.number == 203)][0].reopen_count) == "error"'
assert_doc 'queue metrics under a failed timeline read are error' \
	'([.metrics.issues[] | select(.number == 203)][0]) |
	.triage_latency_hours == "error" and .queue_wait_hours == "error"
	and .blocked_dwell_hours == "error" and .rework_bounces == "error"
	and .human_response_hours == "error" and .review_drift_hours == "error"'
assert_doc 'cohort flag under a failed comment read is error; close instant survives' \
	'([.metrics.issues[] | select(.number == 203)][0]) |
	.scope_complete == "error"
	and .closed_at == "2026-07-01T14:00:00Z"'
assert_doc 'processing stopped after the fifth consecutive error' \
	'([.metrics.issues[] | select(.number == 205)] | length) == 1
	and ([.metrics.issues[] | select(.number == 206)] | length) == 0
	and ([.metrics.issues[] | select(.number == 207)] | length) == 0'

# --- scenario: ambiguity and a failed PR-side read -----------------------------
cat >"$SCRATCH/fake/search.json" <<'JSON'
[
 {"number":301,"state":"closed","createdAt":"2026-07-01T06:00:00Z",
  "closedAt":"2026-07-01T14:00:00Z","labels":[]},
 {"number":302,"state":"closed","createdAt":"2026-07-01T06:00:00Z",
  "closedAt":"2026-07-02T20:00:00Z","labels":[]}
]
JSON
# 301: never in progress; two closing PRs -> ambiguous.
printf '%s\n' '[]' >"$SCRATCH/fake/tl-301.json"
printf '%s\n' '{"comments":[]}' >"$SCRATCH/fake/issue-301.json"
cat >"$SCRATCH/fake/prlist-301.json" <<'JSON'
[
 {"number":401,"body":"Fixes #301"},
 {"number":402,"body":"Resolves #301"}
]
JSON
# 302: timeline ok, but the pr-list read fails (missing prlist file).
cat >"$SCRATCH/fake/tl-302.json" <<'JSON'
[
 {"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T10:00:00Z"},
 {"event":"closed","created_at":"2026-07-02T20:00:00Z"}
]
JSON
if ! run_collector 'priority:P1'; then
	cat "$SCRATCH/stderr" >&2
	fail 'ambiguity scenario unexpectedly failed'
fi
# 302 also has a failing issue-comment read (no issue file): the scope
# estimate is error while the cycle still computes from the timeline.
assert_doc 'ambiguous closers stay unknown, never guessed' \
	'([.metrics.issues[] | select(.number == 301)][0]) |
	.pr == "unknown(ambiguous)"
	and .review_iterations == "unknown(ambiguous)"
	and .loc_actual == "unknown(ambiguous)"
	and .pr_lifespan_hours == "unknown(ambiguous)"
	and .ci_wall_hours == "unknown(ambiguous)"'
assert_doc 'never-instrumented issue reports queue-metric data gaps' \
	'([.metrics.issues[] | select(.number == 301)][0]) |
	.triage_latency_hours == "unknown(never-ready)"
	and .queue_wait_hours == "unknown(no-ready-anchor)"
	and .blocked_dwell_hours == 0 and .rework_bounces == 0
	and .human_response_hours == "unknown(never-awaiting-merge)"
	and .review_drift_hours == "unknown(no-review-phase)"'
assert_doc 'PR-side spans inherit a failed PR read as error' \
	'([.metrics.issues[] | select(.number == 302)][0]) |
	.pr_lifespan_hours == "error" and .full_delivery_hours == "error"
	and .merge_lag_hours == "error" and .build_private_hours == "error"
	and .ci_wall_hours == "error"'
assert_doc 'reopen count still computes when only the PR side fails' \
	'([.metrics.issues[] | select(.number == 302)][0].reopen_count) == 0'
assert_doc 'issue-side queue metrics survive a failed PR read' \
	'([.metrics.issues[] | select(.number == 302)][0]) |
	.triage_latency_hours == "unknown(never-ready)"
	and .queue_wait_hours == "unknown(no-ready-anchor)"
	and .blocked_dwell_hours == 0 and .rework_bounces == 0
	and .human_response_hours == "unknown(never-awaiting-merge)"
	and .review_drift_hours == "unknown(no-review-phase)"'
assert_doc 'never-in-progress is a data gap, not an error' \
	'([.metrics.issues[] | select(.number == 301)][0].cycle_hours) == "unknown(never-in-progress)"'
assert_doc 'failed PR-side read is error while issue-side still computes' \
	'([.metrics.issues[] | select(.number == 302)][0]) |
	.pr == "error" and .loc_actual == "error"
	and .review_iterations == "error"
	and (.cycle_hours | type == "number")'
assert_doc 'failed issue-side comment read is error, cycle unaffected' \
	'([.metrics.issues[] | select(.number == 302)][0].scope_estimate) == "error"'

# --- scenario: statusCheckRollup timing variants --------------------------------
# 401 resolves to a merged PR with an empty rollup; 402's PR carries only
# checks without both timestamps (StatusContext-shaped entries). Both are data
# gaps with distinct reasons, never zero and never a guessed wall time.
cat >"$SCRATCH/fake/search.json" <<'JSON'
[
 {"number":401,"state":"closed","createdAt":"2026-07-01T06:00:00Z",
  "closedAt":"2026-07-01T14:00:00Z","labels":[]},
 {"number":402,"state":"closed","createdAt":"2026-07-01T06:00:00Z",
  "closedAt":"2026-07-01T14:00:00Z","labels":[]}
]
JSON
for n in 401 402; do
	printf '%s\n' '[]' >"$SCRATCH/fake/tl-$n.json"
	printf '%s\n' '{"comments":[]}' >"$SCRATCH/fake/issue-$n.json"
done
printf '%s\n' '[{"number":411,"body":"Closes #401"}]' >"$SCRATCH/fake/prlist-401.json"
printf '%s\n' '[{"number":412,"body":"Closes #402"}]' >"$SCRATCH/fake/prlist-402.json"
jq -n '{comments:[],additions:1,deletions:0,changedFiles:1,
	createdAt:"2026-07-01T10:00:00Z",mergedAt:"2026-07-01T11:00:00Z",
	commits:[{committedDate:null},{committedDate:"2026-07-01T09:30:00Z"}],
	statusCheckRollup:[]}' >"$SCRATCH/fake/pr-411.json"
jq -n '{comments:[],additions:1,deletions:0,changedFiles:1,
	createdAt:"2026-07-01T10:00:00Z",mergedAt:"2026-07-01T11:00:00Z",
	commits:[{committedDate:"2026-07-01T09:30:00Z"}],
	statusCheckRollup:[{__typename:"StatusContext",name:"lint"}]}' >"$SCRATCH/fake/pr-412.json"
if ! run_collector 'status:ready'; then
	cat "$SCRATCH/stderr" >&2
	fail 'rollup-variant scenario unexpectedly failed'
fi
assert_doc 'empty rollup is unknown(no-checks)' \
	'([.metrics.issues[] | select(.number == 401)][0].ci_wall_hours) == "unknown(no-checks)"'
assert_doc 'untimed-only rollup is unknown(no-check-timings)' \
	'([.metrics.issues[] | select(.number == 402)][0].ci_wall_hours) == "unknown(no-check-timings)"'
assert_doc 'single-commit PR spans compute' \
	'([.metrics.issues[] | select(.number == 401)][0]) |
	.merge_lag_hours == 1.5 and .build_private_hours == 0.5
	and .pr_lifespan_hours == 1 and .full_delivery_hours == 5'

# --- scenario: drift, unlabeled dwell exit, still-blocked, backwards spans -----
# 501 (closed): the label-derived review phase disagrees with the GitHub-derived
# PR lifespan far past the 10%-or-1h threshold; a blocked episode exits through
# its unlabeled event. 502 (open): an in-progress anchor predating ready and an
# awaiting-merge label written after merge both run backwards and report as
# error, never clamped; a blocked episode with no exit stays unknown.
# 503 (closed): a dwell interval whose exit precedes its entry sums negative
# and reports as error, never a negative span.
cat >"$SCRATCH/fake/search.json" <<'JSON'
[
 {"number":501,"state":"closed","createdAt":"2026-07-01T06:00:00Z",
  "closedAt":"2026-07-01T18:00:00Z","labels":[]},
 {"number":502,"state":"open","createdAt":"2026-07-01T06:00:00Z",
  "closedAt":null,"labels":[]},
 {"number":503,"state":"closed","createdAt":"2026-07-01T06:00:00Z",
  "closedAt":"2026-07-01T14:00:00Z","labels":[]}
]
JSON
cat >"$SCRATCH/fake/tl-501.json" <<'JSON'
[
 {"event":"labeled","label":{"name":"status:ready"},"created_at":"2026-07-01T07:00:00Z"},
 {"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T08:00:00Z"},
 {"event":"labeled","label":{"name":"status:in-review"},"created_at":"2026-07-01T08:30:00Z"},
 {"event":"labeled","label":{"name":"status:awaiting-merge"},"created_at":"2026-07-01T09:00:00Z"},
 {"event":"labeled","label":{"name":"status:blocked"},"created_at":"2026-07-01T10:00:00Z"},
 {"event":"unlabeled","label":{"name":"status:blocked"},"created_at":"2026-07-01T11:00:00Z"},
 {"event":"closed","created_at":"2026-07-01T18:00:00Z"}
]
JSON
cat >"$SCRATCH/fake/tl-503.json" <<'JSON'
[
 {"event":"labeled","label":{"name":"status:blocked"},"created_at":"2026-07-01T10:00:00Z"},
 {"event":"unlabeled","label":{"name":"status:blocked"},"created_at":"2026-07-01T09:00:00Z"},
 {"event":"closed","created_at":"2026-07-01T14:00:00Z"}
]
JSON
printf '%s\n' '{"comments":[]}' >"$SCRATCH/fake/issue-503.json"
printf '%s\n' '[]' >"$SCRATCH/fake/prlist-503.json"
printf '%s\n' '{"comments":[]}' >"$SCRATCH/fake/issue-501.json"
printf '%s\n' '[{"number":421,"body":"Closes #501"}]' >"$SCRATCH/fake/prlist-501.json"
jq -n '{comments:[],additions:10,deletions:2,changedFiles:2,
	createdAt:"2026-07-01T08:30:00Z",mergedAt:"2026-07-01T17:30:00Z",
	commits:[{committedDate:"2026-07-01T08:00:00Z"}],
	statusCheckRollup:[{__typename:"CheckRun",name:"suite",
		startedAt:"2026-07-01T09:00:00Z",completedAt:"2026-07-01T09:20:00Z"}]}' \
	>"$SCRATCH/fake/pr-421.json"
printf '%s\n' '{"comments":[]}' >"$SCRATCH/fake/issue-502.json"
printf '%s\n' '[{"number":422,"body":"Closes #502"}]' >"$SCRATCH/fake/prlist-502.json"
cat >"$SCRATCH/fake/tl-502.json" <<'JSON'
[
 {"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T05:00:00Z"},
 {"event":"labeled","label":{"name":"status:ready"},"created_at":"2026-07-01T06:30:00Z"},
 {"event":"labeled","label":{"name":"status:awaiting-merge"},"created_at":"2026-07-01T08:00:00Z"},
 {"event":"labeled","label":{"name":"status:blocked"},"created_at":"2026-07-01T09:00:00Z"}
]
JSON
if ! run_collector 'status:blocked'; then
	cat "$SCRATCH/stderr" >&2
	fail 'drift scenario unexpectedly failed'
fi
assert_doc 'issue 501 queue spans and unlabeled dwell exit' \
	'([.metrics.issues[] | select(.number == 501)][0]) |
	.triage_latency_hours == 1 and .queue_wait_hours == 1
	and .blocked_dwell_hours == 1 and .rework_bounces == 0
	and .human_response_hours == 8.5
	and .review_drift_hours == 8.5'
assert_doc 'issue 502 backwards spans are errors, unexited dwell is unknown' \
	'([.metrics.issues[] | select(.number == 502)][0]) |
	.triage_latency_hours == 0.5 and .queue_wait_hours == "error"
	and .blocked_dwell_hours == "unknown(still-blocked)"
	and .rework_bounces == 0 and .human_response_hours == "error"'
assert_doc 'backwards dwell interval is error, never a negative span' \
	'([.metrics.issues[] | select(.number == 503)][0].blocked_dwell_hours) == "error"'
assert_doc 'drift coverage counts only the paired issue' \
	'.metrics.coverage.review_drift_hours == 1
	and .metrics.coverage.blocked_dwell_hours == 1'

# --- scenario: the divination-to-scope-to-actual chain --------------------------
# 701: divination M, scope S, actual 100 (M) — the assessment matched reality
# and the freeze diverged from it. 702: all three land in S. 703: divination
# and scope agree against an L actual — the assessment's error carried into
# the freeze. 701 also carries a phase-only trajectory block: fields the
# block does not name stay unknown.
cat >"$SCRATCH/fake/search.json" <<'JSON'
[
 {"number":701,"state":"closed","createdAt":"2026-07-01T06:00:00Z",
  "closedAt":"2026-07-01T14:00:00Z","labels":[]},
 {"number":702,"state":"closed","createdAt":"2026-07-01T06:00:00Z",
  "closedAt":"2026-07-01T14:00:00Z","labels":[]},
 {"number":703,"state":"closed","createdAt":"2026-07-01T06:00:00Z",
  "closedAt":"2026-07-01T14:00:00Z","labels":[]}
]
JSON
for n in 701 702 703; do
	printf '%s\n' '[]' >"$SCRATCH/fake/tl-$n.json"
done
printf '%s\n' '[{"number":711,"body":"Closes #701"}]' >"$SCRATCH/fake/prlist-701.json"
printf '%s\n' '[{"number":712,"body":"Closes #702"}]' >"$SCRATCH/fake/prlist-702.json"
printf '%s\n' '[{"number":713,"body":"Closes #703"}]' >"$SCRATCH/fake/prlist-703.json"
printf '%s\n' '{"comments":[],"additions":80,"deletions":20}' >"$SCRATCH/fake/pr-711.json"
printf '%s\n' '{"comments":[],"additions":20,"deletions":10}' >"$SCRATCH/fake/pr-712.json"
printf '%s\n' '{"comments":[],"additions":300,"deletions":100}' >"$SCRATCH/fake/pr-713.json"
mk_issue_comment() { # number scope-complexity div-complexity
	jq -n --arg scope "<!-- WORK:SCOPE -->
## Scope — issue #$1

- complexity: $2

<!-- SCOPE:COMPLETE -->" --arg div "<!-- WORK:DIVINATION -->
## Divination — issue #$1

- complexity: $3

<!-- DIVINATION:COMPLETE -->" \
		'{comments:[{body:$scope},{body:$div}]}'
}
mk_issue_comment 701 S M >"$SCRATCH/fake/issue-701.json"
mk_issue_comment 702 S S >"$SCRATCH/fake/issue-702.json"
mk_issue_comment 703 M M >"$SCRATCH/fake/issue-703.json"
jq --arg t '<!-- WORK:TRAJECTORY -->
## Trajectory — issue #701

- phase: handoff

<!-- TRAJECTORY:COMPLETE -->' \
	'{comments: (.comments + [{body:$t}])}' \
	"$SCRATCH/fake/issue-701.json" >"$SCRATCH/fake/issue-701.tmp.json"
mv "$SCRATCH/fake/issue-701.tmp.json" "$SCRATCH/fake/issue-701.json"
if ! run_collector 'status:blocked'; then
	cat "$SCRATCH/stderr" >&2
	fail 'calibration scenario unexpectedly failed'
fi
assert_doc 'freeze verdict when the assessment matched reality' \
	'([.metrics.issues[] | select(.number == 701)][0]) |
	.divination_complexity == "M" and .scope_estimate == "S"
	and .loc_actual == 100 and .scope_miss_location == "freeze"
	and .trajectory_phase == "handoff" and .trajectory_branch == "unknown"'
assert_doc 'aligned verdict when every link lands in one band' \
	'([.metrics.issues[] | select(.number == 702)][0]) |
	.scope_miss_location == "aligned"'
assert_doc 'assessment verdict when the estimate repeats the divination' \
	'([.metrics.issues[] | select(.number == 703)][0]) |
	.scope_miss_location == "assessment"'

# --- scenario: a stable risk-band segment ---------------------------------------
# Six closed issues with measured cycles: five night-safe (stable), one
# carrying night-safe plus daytime-only (most restrictive wins), so the
# night-safe band crosses the instability threshold while daytime-only and
# unjudged stay gated.
python3 - "$SCRATCH/fake/search.json" <<'PY'
import json, sys
issues = []
for n in range(801, 807):
    labels = [{"name": "risk:night-safe"}]
    if n == 806:
        labels.append({"name": "risk:daytime-only"})
    issues.append({"number": n, "state": "closed",
                   "createdAt": "2026-07-01T06:00:00Z",
                   "closedAt": "2026-07-01T14:00:00Z", "labels": labels})
with open(sys.argv[1], "w") as fh:
    json.dump(issues, fh)
PY
# Cycles grow with the issue number (one through five hours for the
# night-safe band), so the pinned median cannot pass while equal to the
# min or max.
for n in 801 802 803 804 805 806; do
	hour=$((8 + n - 800))
	cat >"$SCRATCH/fake/tl-$n.json" <<JSON
[{"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T08:00:00Z"},
 {"event":"closed","created_at":"2026-07-01T$(printf '%02d:00:00Z' "$hour")"}]
JSON
	printf '%s\n' '{"comments":[]}' >"$SCRATCH/fake/issue-$n.json"
	printf '%s\n' '[{"number":820,"body":"Closes #'"$n"'"}]' \
		>"$SCRATCH/fake/prlist-$n.json"
	printf '%s\n' '{"comments":[],"additions":10,"deletions":2}' \
		>"$SCRATCH/fake/pr-820.json"
done
if ! run_collector 'risk:night-safe'; then
	cat "$SCRATCH/stderr" >&2
	fail 'segmentation scenario unexpectedly failed'
fi
assert_doc 'a stable segment reports its distribution' \
	'.metrics.risk_band_cycle_hours["night-safe"]
	== {count: 5, median: 3, min: 1, max: 5}'
assert_doc 'thin segments report only their count' \
	'.metrics.risk_band_cycle_hours["daytime-only"].count == 1
	and .metrics.risk_band_cycle_hours["daytime-only"].median
		== "unknown(instability-rule)"
	and .metrics.risk_band_cycle_hours["unjudged"].count == 0
	and .metrics.risk_band_cycle_hours["unjudged"].max
		== "unknown(instability-rule)"'

# --- scenario: quartiles cross the combined-population threshold ---------------
# Twenty-one closed issues with measured cycles 1..21 hours: the combined
# population crosses N >= 20 so nearest-rank p25/p75 appear over the sorted
python3 - "$SCRATCH/fake/search.json" "$SCRATCH/fake" <<'PY'
import json, sys
from datetime import datetime, timedelta, timezone

closed = datetime(2026, 7, 1, 14, 0, tzinfo=timezone.utc)
issues = []
for n in range(901, 922):
    k = n - 900  # cycle: 1..21 hours, closed on one date -> one week bucket
    start = closed - timedelta(hours=k)
    fmt = lambda d: d.strftime("%Y-%m-%dT%H:%M:%SZ")
    issues.append({"number": n, "state": "closed",
                   "createdAt": "2026-07-01T06:00:00Z",
                   "closedAt": fmt(closed), "labels": []})
    with open(f"{sys.argv[2]}/tl-{n}.json", "w") as fh:
        json.dump([{"event": "labeled",
                    "label": {"name": "status:in-progress"},
                    "created_at": fmt(start)},
                   {"event": "closed",
                    "created_at": fmt(closed)}], fh)
with open(sys.argv[1], "w") as fh:
    json.dump(issues, fh)
PY
for n in $(seq 901 921); do
	printf '%s\n' '{"comments":[]}' >"$SCRATCH/fake/issue-$n.json"
	printf '%s\n' '[{"number":930,"body":"Closes #'"$n"'"}]' \
		>"$SCRATCH/fake/prlist-$n.json"
	printf '%s\n' '{"comments":[],"additions":10,"deletions":2}' \
		>"$SCRATCH/fake/pr-930.json"
done
if ! run_collector 'status:blocked'; then
	cat "$SCRATCH/stderr" >&2
	fail 'quartile scenario unexpectedly failed'
fi
assert_doc 'combined quartiles appear at and above N >= 20' \
	'.metrics.quartiles.cycle_hours.count == 21
	and .metrics.quartiles.cycle_hours.p25 == 6
	and .metrics.quartiles.cycle_hours.p75 == 16'
assert_doc 'a populated week reports its median' \
	'.metrics.throughput.weeks == [{week_start: "2026-06-29",
		closed_count: 21, median_cycle_hours: 11}]'

# The N = 20 edge discriminates the rank convention: nearest-rank p25/p75 of
# cycles 1..20 land on values 5 and 15, where a floor index would read 6/16.
python3 - "$SCRATCH/fake/search.json" <<'PY'
import json, sys
issues = [{"number": n, "state": "closed",
           "createdAt": "2026-07-01T06:00:00Z",
           "closedAt": "2026-07-01T14:00:00Z", "labels": []}
          for n in range(901, 921)]
with open(sys.argv[1], "w") as fh:
    json.dump(issues, fh)
PY
if ! run_collector 'status:blocked'; then
	cat "$SCRATCH/stderr" >&2
	fail 'quartile N=20 scenario unexpectedly failed'
fi
assert_doc 'nearest-rank quartiles discriminate at the N = 20 edge' \
	'.metrics.quartiles.cycle_hours.count == 20
	and .metrics.quartiles.cycle_hours.p25 == 5
	and .metrics.quartiles.cycle_hours.p75 == 15'

# --- scenario: movement against a prior sidecar --------------------------------
# One closed issue (cycle 4h, lead 8h) compared against handcrafted prior
# sidecars. The prior sidecar is a local file input: no additional gh read of
# any kind may appear because of it. The priors are crafted by hand because
# they stand in for documents captured from earlier runs, not because the fake
# cannot serve a projection.
cat >"$SCRATCH/fake/search.json" <<'JSON'
[
 {"number":1001,"state":"closed","createdAt":"2026-07-01T06:00:00Z",
  "closedAt":"2026-07-01T14:00:00Z","labels":[]}
]
JSON
cat >"$SCRATCH/fake/tl-1001.json" <<'JSON'
[
 {"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T08:00:00Z"},
 {"event":"closed","created_at":"2026-07-01T12:00:00Z"}
]
JSON
printf '%s\n' '{"comments":[]}' >"$SCRATCH/fake/issue-1001.json"
printf '%s\n' '[]' >"$SCRATCH/fake/prlist-1001.json"

# Baseline run without a prior: movement reports the omission, never a section
# shaped like a comparison.
if ! run_collector 'status:movement'; then
	cat "$SCRATCH/stderr" >&2
	fail 'movement baseline scenario unexpectedly failed'
fi
assert_doc 'no prior argument omits the movement section' \
	'.schema_version == "1.6"
	and .metrics.movement == {status:"omitted", reason:"no-prior"}'

# A comparable prior: cycle median 10 over 3 issues, lead median 20, and one
# family whose median never resolved — that family must be absent from the
# comparison, not zero-filled against nothing.
cat >"$SCRATCH/prior-comparable.json" <<'JSON'
{"schema_version":"1.5","selector":"status:movement","mode":"label-set",
 "generated_at":"2026-07-20T00:00:00Z","truncated":false,
 "population":{"count":3,"issues":[2001,2002,2003]},
 "metrics":{"aggregate":{
   "cycle_hours":{"count":3,"median":10,"min":8,"max":12},
   "lead_time_hours":{"count":3,"median":20,"min":18,"max":22},
   "pr_lifespan_hours":{"count":0}}}}
JSON
if ! run_collector 'status:movement' "$SCRATCH/prior-comparable.json"; then
	cat "$SCRATCH/stderr" >&2
	fail 'movement compared scenario unexpectedly failed'
fi
assert_doc 'compared movement carries signed deltas at one decimal' \
	'.metrics.movement == {status:"compared",
		against:{selector:"status:movement", generated_at:"2026-07-20T00:00:00Z"},
		families:{
			cycle_hours:{previous_median:10, current_median:4,
				delta_median:-6, previous_count:3, current_count:1},
			lead_time_hours:{previous_median:20, current_median:8,
				delta_median:-12, previous_count:3, current_count:1}}}'
assert_doc 'a family unresolved on either side is absent from the comparison' \
	'(.metrics.movement.families | has("pr_lifespan_hours") | not)'
assert_count 'a comparable prior adds no gh read' '^gh ' "$SCRATCH/calls" 5

prior_case() { # description jq-filter fixture-file
	jq "$2" "$SCRATCH/prior-comparable.json" >"$SCRATCH/prior-case.json"
	if ! run_collector 'status:movement' "$SCRATCH/prior-case.json"; then
		cat "$SCRATCH/stderr" >&2
		fail "$1 scenario unexpectedly failed"
	fi
	assert_doc "$1" ".metrics.movement == $3"
}
prior_case 'a different selector is omitted, never compared against nothing' \
	'.selector = "status:other"' \
	'{status:"omitted", reason:"selector-mismatch"}'
prior_case 'an unknown prior schema major refuses to compare' \
	'.schema_version = "2.0"' \
	'{status:"omitted", reason:"unknown-prior-schema"}'
prior_case 'a truncated prior poisons the comparison' \
	'.truncated = true' \
	'{status:"incomparable", reason:"truncated-prior"}'

prior_case 'a non-object aggregate degrades to an omission' \
	'.metrics.aggregate = false' \
	'{status:"omitted", reason:"unreadable-prior"}'

# A family whose counts do not both measure up is absent from the comparison
# entirely — a count is never defaulted to zero beside a real median.
jq '.metrics.aggregate.cycle_hours.count = "three"' \
	"$SCRATCH/prior-comparable.json" >"$SCRATCH/prior-case.json"
if ! run_collector 'status:movement' "$SCRATCH/prior-case.json"; then
	cat "$SCRATCH/stderr" >&2
	fail 'string-count prior scenario unexpectedly failed'
fi
assert_doc 'a non-numeric prior count refuses its family' \
	'.metrics.movement.status == "compared"
	and (.metrics.movement.families | has("cycle_hours") | not)
	and (.metrics.movement.families.lead_time_hours.previous_median == 20)'

printf 'not json at all\n' >"$SCRATCH/prior-case.json"
if ! run_collector 'status:movement' "$SCRATCH/prior-case.json"; then
	cat "$SCRATCH/stderr" >&2
	fail 'unreadable-prior scenario unexpectedly failed'
fi
assert_doc 'an unparseable prior degrades to an omission' \
	'.metrics.movement == {status:"omitted", reason:"unreadable-prior"}'
if ! run_collector 'status:movement' "$SCRATCH/prior-missing.json"; then
	cat "$SCRATCH/stderr" >&2
	fail 'missing-prior scenario unexpectedly failed'
fi
assert_doc 'a missing prior path degrades to an omission' \
	'.metrics.movement == {status:"omitted", reason:"unreadable-prior"}'

# --- scenario: selection failure aborts ----------------------------------------
rm -f "$SCRATCH/fake/search.json"
PATH="$SCRATCH/bin:$PATH" FAKE_DIR="$SCRATCH/fake" CALL_LOG="$SCRATCH/calls" \
	"$collector" 'status:ready' >"$SCRATCH/stdout" 2>"$SCRATCH/stderr" &&
	fail 'a failed selection read must exit non-zero'
if jq -e . >/dev/null 2>&1 <"$SCRATCH/stdout"; then
	fail 'an aborted collection emitted a parseable document'
fi
assert_contains 'selection read failed' "$SCRATCH/stderr"
# One-way is not enough: the bound wording must be absent here, or the two hard
# stops would share a prefix and prove nothing about telling them apart.
assert_contains 'selection read failed (gh exit ' "$SCRATCH/stderr"
if rg --no-config -qF 'exceeded its network bound' "$SCRATCH/stderr"; then
	fail 'a gh nonzero exit must not be reported as a bound exceeded'
fi

# --- scenario: bounded reads ---------------------------------------------------
# The overrides put the timeout path within a second, so the hang the fake
# supplies is observed rather than waited out. The scenario above removed
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

# A timed-out comments read reaches error by a different route, and that route
# is the single line in bounded_call which empties the stdout capture on 124.
# These eight positions are guarded by `[[ -s $blob ]]` and fall through to
# unknown defaults, not to error.
#
# The hang therefore writes a truncated response before blocking, which is what
# a real gh killed mid-stream leaves behind. Without the emptying line that
# prefix stays on disk, `[[ -s $blob ]]` is true, and the collector mines a
# partial capture -- reporting a timeout as a genuinely absent source, which is
# the defect the convention exists to prevent. A hang that wrote nothing would
# leave the capture empty either way and prove nothing about that line.
#
# The timeline read answers normally here, so cycle_hours is the control.
rm -f "$SCRATCH"/fake/tl-*.json "$SCRATCH"/fake/issue-*.json \
	"$SCRATCH"/fake/prlist-*.json "$SCRATCH"/fake/pr-*.json
jq -nc '[{number: 302, state: "closed", createdAt: "2026-07-01T09:00:00Z",
	closedAt: "2026-07-01T14:00:00Z", labels: []}]' >"$SCRATCH/fake/search.json"
jq -nc '[{event: "labeled", label: {name: "status:in-progress"},
	created_at: "2026-07-01T10:00:00Z"},
	{event: "closed", created_at: "2026-07-01T14:00:00Z"}]' >"$SCRATCH/fake/tl-302.json"
printf '%s\n' '[]' >"$SCRATCH/fake/prlist-302.json"
FAKE_GH_HANG=issue
FAKE_GH_PARTIAL='{"comments":[{"body":"<!-- WORK:SCOPE -->\ncomplexity: L'
COLLECT_TELEMETRY_BOUND_ONE_REQUEST=1
COLLECT_TELEMETRY_BOUND_MANY_REQUESTS=1
if ! run_collector 'status:ready'; then
	cat "$SCRATCH/stderr" >&2
	fail 'a timed-out comments read must not abort the run'
fi
FAKE_GH_HANG=
FAKE_GH_PARTIAL=
COLLECT_TELEMETRY_BOUND_ONE_REQUEST=
COLLECT_TELEMETRY_BOUND_MANY_REQUESTS=
assert_doc 'every position a timed-out comments read feeds is error, never unknown' \
	'([.metrics.issues[] | select(.number == 302)][0]) |
	[.scope_estimate, .scope_complete, .trajectory_phase, .trajectory_branch,
	 .trajectory_pr, .trajectory_guardrails, .trajectory_surprises,
	 .divination_complexity] | all(. == "error")'
assert_doc 'the timeline read that did answer keeps its value' \
	'([.metrics.issues[] | select(.number == 302)][0].cycle_hours) == 4'

# The two PR-side reads. Both arrive at the fake as `pr`, so they are selected
# as two-word hangs. Their metric positions are already covered by non-timeout
# failures elsewhere in this suite -- what these two cases hold is the wiring:
# without them, reverting either fetch function to its old unbounded form
# leaves the whole suite green.
rm -f "$SCRATCH"/fake/tl-*.json "$SCRATCH"/fake/issue-*.json \
	"$SCRATCH"/fake/prlist-*.json "$SCRATCH"/fake/pr-*.json
jq -nc '[{number: 303, state: "closed", createdAt: "2026-07-01T09:00:00Z",
	closedAt: "2026-07-01T14:00:00Z", labels: []}]' >"$SCRATCH/fake/search.json"
printf '%s\n' '[]' >"$SCRATCH/fake/tl-303.json"
printf '%s\n' '{"comments":[]}' >"$SCRATCH/fake/issue-303.json"
FAKE_GH_HANG='pr list'
COLLECT_TELEMETRY_BOUND_ONE_REQUEST=1
COLLECT_TELEMETRY_BOUND_MANY_REQUESTS=1
if ! run_collector 'status:ready'; then
	cat "$SCRATCH/stderr" >&2
	fail 'a timed-out PR candidate read must not abort the run'
fi
FAKE_GH_HANG=
COLLECT_TELEMETRY_BOUND_ONE_REQUEST=
COLLECT_TELEMETRY_BOUND_MANY_REQUESTS=
assert_doc 'a timed-out PR candidate read leaves the PR-derived positions at error' \
	'([.metrics.issues[] | select(.number == 303)][0]) |
	[.pr, .review_iterations, .loc_actual, .pr_lifespan_hours,
	 .ci_wall_hours] | all(. == "error")'
assert_contains 'exceeded its 1s network bound' "$SCRATCH/stderr"

printf '%s\n' '[{"number":404,"body":"closes #303"}]' >"$SCRATCH/fake/prlist-303.json"
FAKE_GH_HANG='pr view'
COLLECT_TELEMETRY_BOUND_ONE_REQUEST=1
COLLECT_TELEMETRY_BOUND_MANY_REQUESTS=1
if ! run_collector 'status:ready'; then
	cat "$SCRATCH/stderr" >&2
	fail 'a timed-out PR metadata read must not abort the run'
fi
FAKE_GH_HANG=
COLLECT_TELEMETRY_BOUND_ONE_REQUEST=
COLLECT_TELEMETRY_BOUND_MANY_REQUESTS=
assert_doc 'a timed-out PR metadata read resolves the PR but errors every span it feeds' \
	'([.metrics.issues[] | select(.number == 303)][0]) |
	.pr == 404 and ([.review_iterations, .loc_actual, .pr_lifespan_hours,
	 .merge_lag_hours, .build_private_hours, .ci_wall_hours]
	 | all(. == "error"))'
assert_contains 'exceeded its 1s network bound' "$SCRATCH/stderr"

# The three refusals, each a value that would otherwise change the bound
# silently rather than be rejected: a non-digit that $(( )) would evaluate, a
# leading zero it would read as octal, and a six-digit value above the cap.
printf '%s\n' '[]' >"$SCRATCH/fake/search.json"
for bad in abc 08 100000; do
	PATH="$SCRATCH/bin:$PATH" FAKE_DIR="$SCRATCH/fake" CALL_LOG="$SCRATCH/calls" \
		COLLECT_TELEMETRY_BOUND_ONE_REQUEST="$bad" \
		"$collector" 'status:ready' >"$SCRATCH/stdout" 2>"$SCRATCH/stderr" &&
		fail "a bound override of '$bad' must exit non-zero"
	assert_contains 'COLLECT_TELEMETRY_BOUND_ONE_REQUEST' "$SCRATCH/stderr"
done

# --- usage ----------------------------------------------------------------------
PATH="$SCRATCH/bin:$PATH" "$collector" >"$SCRATCH/stdout" 2>"$SCRATCH/stderr" &&
	fail 'missing selector must exit non-zero'
PATH="$SCRATCH/bin:$PATH" "$collector" a b c >"$SCRATCH/stdout" 2>"$SCRATCH/stderr" &&
	fail 'extra arguments must exit non-zero'

printf 'collect-telemetry-test: ok\n'
