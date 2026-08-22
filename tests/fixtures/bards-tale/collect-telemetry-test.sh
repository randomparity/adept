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
# empty timeline); one that does not exist makes the read fail with exit 1,
# which is how the tri-state and rate-limit cases model a failed gh read.
mkdir -p "$SCRATCH/bin"
printf '%s\n' '#!/usr/bin/env bash' >"$SCRATCH/bin/gh"
cat >>"$SCRATCH/bin/gh" <<'FAKE_GH'
set -euo pipefail
printf 'gh %s\n' "$*" >>"${CALL_LOG:?}"
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
	# gh api repos/<owner>/<name>/issues/<N>/timeline --paginate --jq '.[]'
	for arg in "$@"; do
		case $arg in
		*/issues/*) path_arg=$arg ;;
		esac
	done
	number=${path_arg##*/issues/}
	number=${number%%/*}
	serve "${FAKE_DIR:?}/tl-$number.jsonl"
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

run_collector() { # selector
	CALL_LOG="$SCRATCH/calls"
	FAKE_DIR="$SCRATCH/fake"
	: >"$CALL_LOG"
	mkdir -p "$FAKE_DIR"
	DOC=$(
		PATH="$SCRATCH/bin:$PATH" \
			CALL_LOG="$CALL_LOG" \
			FAKE_DIR="$FAKE_DIR" \
			"$collector" "$1" 2>"$SCRATCH/stderr"
	) || return 1
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
# instrumented and closed, one open and in flight.
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
cat >"$SCRATCH/fake/tl-101.jsonl" <<'JSONL'
{"event":"labeled","label":{"name":"status:ready"},"created_at":"2026-07-01T09:00:00Z"}
{"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T10:00:00Z"}
{"event":"labeled","label":{"name":"status:blocked"},"created_at":"2026-07-01T10:30:00Z"}
{"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T11:00:00Z"}
{"event":"labeled","label":{"name":"status:in-review"},"created_at":"2026-07-01T11:00:00Z"}
{"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T12:00:00Z"}
{"event":"labeled","label":{"name":"status:in-review"},"created_at":"2026-07-01T12:30:00Z"}
{"event":"reopened","created_at":"2026-07-01T12:45:00Z"}
{"event":"labeled","label":{"name":"status:awaiting-merge"},"created_at":"2026-07-01T13:30:00Z"}
{"event":"closed","created_at":"2026-07-01T14:00:00Z"}
JSONL
cat >"$SCRATCH/fake/tl-103.jsonl" <<'JSONL'
{"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T09:00:00Z"}
JSONL
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
	'.schema_version == "1.4"
	and .selector == "status:ready"
	and .mode == "label-set"
	and (.generated_at | type == "string")
	and .truncated == false
	and .population.count == 2
	and .population.issues == [101, 103]
	and (.metrics | type == "object")
	and (has("rate_limited") | not)'

assert_doc 'epic excluded from population' \
	'([.population.issues[] | select(. == 102)] | length) == 0'

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

assert_doc 'uninstrumented issue reports unknown, never zero' \
	'([.metrics.issues[] | select(.number == 103)][0]) |
	.pr == "unknown(no-closer)"
	and .review_iterations == "unknown(no-closer)"
	and .loc_actual == "unknown(no-closer)"
	and .scope_estimate == "unknown"
	and .review_verdict == "unknown"
	and .security == "unknown"
	and .exit == "unknown"'
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

assert_doc 'aggregate median and range over value-state cycles.' \
	'.metrics.aggregate.cycle_hours.count == 2
	and .metrics.aggregate.cycle_hours.min == 4
	and (.metrics.aggregate.cycle_hours.median | type == "number")
	and (.metrics.aggregate.cycle_hours.max | type == "number")
	and .metrics.aggregate.cycle_hours.max > .metrics.aggregate.cycle_hours.min'
assert_doc 'aggregates exist per span family over the value-state entries' \
	'.metrics.aggregate.lead_time_hours == {count: 1, median: 6, min: 6, max: 6}
	and .metrics.aggregate.reopen_count.count == 2
	and (.metrics.aggregate.ci_wall_hours.median | type == "number")
	and .metrics.aggregate.blocked_dwell_hours == {count: 2, median: 0.25, min: 0, max: 0.5}
	and .metrics.aggregate.rework_bounces.count == 2
	and .metrics.aggregate.triage_latency_hours.count == 1
	and .metrics.aggregate.human_response_hours == {count: 1, median: 0.1, min: 0.1, max: 0.1}'
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
	: >"$SCRATCH/fake/tl-$n.jsonl"
	printf '%s\n' '{"comments":[]}' >"$SCRATCH/fake/issue-$n.json"
	printf '%s\n' '[]' >"$SCRATCH/fake/prlist-$n.json"
done
if ! run_collector 'status:ready'; then
	cat "$SCRATCH/stderr" >&2
	fail 'truncation scenario unexpectedly failed'
fi
assert_doc 'limit-equal population marks truncated' '.truncated == true'

# --- scenario: tri-state errors and the rate-limit cutoff ----------------------
# Seven selected issues. The first five timeline reads fail; the collector stops
# after five consecutive errored issues and emits a partial document carrying
# rate_limited, leaving issues 206 and 207 unprocessed.
rm -f "$SCRATCH"/fake/tl-*.jsonl "$SCRATCH"/fake/issue-*.json \
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
	: >"$SCRATCH/fake/tl-$n.jsonl"
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
: >"$SCRATCH/fake/tl-301.jsonl"
printf '%s\n' '{"comments":[]}' >"$SCRATCH/fake/issue-301.json"
cat >"$SCRATCH/fake/prlist-301.json" <<'JSON'
[
 {"number":401,"body":"Fixes #301"},
 {"number":402,"body":"Resolves #301"}
]
JSON
# 302: timeline ok, but the pr-list read fails (missing prlist file).
cat >"$SCRATCH/fake/tl-302.jsonl" <<'JSONL'
{"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T10:00:00Z"}
{"event":"closed","created_at":"2026-07-02T20:00:00Z"}
JSONL
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
	: >"$SCRATCH/fake/tl-$n.jsonl"
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
cat >"$SCRATCH/fake/tl-501.jsonl" <<'JSONL'
{"event":"labeled","label":{"name":"status:ready"},"created_at":"2026-07-01T07:00:00Z"}
{"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T08:00:00Z"}
{"event":"labeled","label":{"name":"status:in-review"},"created_at":"2026-07-01T08:30:00Z"}
{"event":"labeled","label":{"name":"status:awaiting-merge"},"created_at":"2026-07-01T09:00:00Z"}
{"event":"labeled","label":{"name":"status:blocked"},"created_at":"2026-07-01T10:00:00Z"}
{"event":"unlabeled","label":{"name":"status:blocked"},"created_at":"2026-07-01T11:00:00Z"}
{"event":"closed","created_at":"2026-07-01T18:00:00Z"}
JSONL
cat >"$SCRATCH/fake/tl-503.jsonl" <<'JSONL'
{"event":"labeled","label":{"name":"status:blocked"},"created_at":"2026-07-01T10:00:00Z"}
{"event":"unlabeled","label":{"name":"status:blocked"},"created_at":"2026-07-01T09:00:00Z"}
{"event":"closed","created_at":"2026-07-01T14:00:00Z"}
JSONL
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
jq -n '{comments:[],additions:10,deletions:2,changedFiles:2,
	createdAt:"2026-07-01T07:00:00Z",mergedAt:"2026-07-01T07:30:00Z",
	commits:[{committedDate:"2026-07-01T06:45:00Z"}],statusCheckRollup:[]}' \
	>"$SCRATCH/fake/pr-422.json"
cat >"$SCRATCH/fake/tl-502.jsonl" <<'JSONL'
{"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T05:00:00Z"}
{"event":"labeled","label":{"name":"status:ready"},"created_at":"2026-07-01T06:30:00Z"}
{"event":"labeled","label":{"name":"status:awaiting-merge"},"created_at":"2026-07-01T08:00:00Z"}
{"event":"labeled","label":{"name":"status:blocked"},"created_at":"2026-07-01T09:00:00Z"}
JSONL
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
	: >"$SCRATCH/fake/tl-$n.jsonl"
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
for n in 801 802 803 804 805 806; do
	cat >"$SCRATCH/fake/tl-$n.jsonl" <<'JSONL'
{"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T08:00:00Z"}
{"event":"closed","created_at":"2026-07-01T10:00:00Z"}
JSONL
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
assert_doc 'multi-match risk labels take the most restrictive band' \
	'([.metrics.issues[] | select(.number == 806)][0].risk_band) == "daytime-only"'
assert_doc 'a stable segment reports its distribution' \
	'.metrics.risk_band_cycle_hours["night-safe"]
	== {count: 5, median: 2, min: 2, max: 2}'
assert_doc 'thin segments report only their count' \
	'.metrics.risk_band_cycle_hours["daytime-only"].count == 1
	and .metrics.risk_band_cycle_hours["daytime-only"].median
		== "unknown(instability-rule)"
	and .metrics.risk_band_cycle_hours["unjudged"].count == 0
	and .metrics.risk_band_cycle_hours["unjudged"].max
		== "unknown(instability-rule)"'
# --- scenario: selection failure aborts ----------------------------------------
rm -f "$SCRATCH/fake/search.json"
PATH="$SCRATCH/bin:$PATH" FAKE_DIR="$SCRATCH/fake" CALL_LOG="$SCRATCH/calls" \
	"$collector" 'status:ready' >"$SCRATCH/stdout" 2>"$SCRATCH/stderr" &&
	fail 'a failed selection read must exit non-zero'
if jq -e . >/dev/null 2>&1 <"$SCRATCH/stdout"; then
	fail 'an aborted collection emitted a parseable document'
fi
assert_contains 'selection read failed' "$SCRATCH/stderr"

# --- usage ----------------------------------------------------------------------
PATH="$SCRATCH/bin:$PATH" "$collector" >"$SCRATCH/stdout" 2>"$SCRATCH/stderr" &&
	fail 'missing selector must exit non-zero'
PATH="$SCRATCH/bin:$PATH" "$collector" a b >"$SCRATCH/stdout" 2>"$SCRATCH/stderr" &&
	fail 'extra arguments must exit non-zero'

printf 'collect-telemetry-test: ok\n'
