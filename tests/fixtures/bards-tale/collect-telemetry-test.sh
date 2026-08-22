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
	printf 'example/repo\n'
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

# --- scenario: success --------------------------------------------------------
# Two selected issues (an epic-labelled third is excluded), one fully
# instrumented and closed, one open and in flight.
cat >"$SCRATCH/fake/search.json" <<'JSON'
[
 {"number":101,"state":"closed","closedAt":"2026-07-01T14:00:00Z","labels":[]},
 {"number":102,"state":"closed","closedAt":"2026-07-01T14:00:00Z","labels":[{"name":"epic"}]},
 {"number":103,"state":"open","closedAt":null,"labels":[]}
]
JSON
cat >"$SCRATCH/fake/tl-101.jsonl" <<'JSONL'
{"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T10:00:00Z"}
{"event":"labeled","label":{"name":"status:in-review"},"created_at":"2026-07-01T11:00:00Z"}
{"event":"labeled","label":{"name":"status:awaiting-merge"},"created_at":"2026-07-01T13:30:00Z"}
{"event":"closed","created_at":"2026-07-01T14:00:00Z"}
JSONL
cat >"$SCRATCH/fake/tl-103.jsonl" <<'JSONL'
{"event":"labeled","label":{"name":"status:in-progress"},"created_at":"2026-07-01T09:00:00Z"}
JSONL
jq -n --arg b "$scope_block_101" '{comments:[{body:$b}]}' >"$SCRATCH/fake/issue-101.json"
printf '%s\n' '{"comments":[]}' >"$SCRATCH/fake/issue-103.json"
cat >"$SCRATCH/fake/prlist-101.json" <<'JSON'
[
 {"number":210,"body":"Part of #101"},
 {"number":211,"body":"Closes #101"}
]
JSON
printf '%s\n' '[]' >"$SCRATCH/fake/prlist-103.json"
jq -n --arg b "$review_block_211" '{comments:[{body:$b}],additions:300,deletions:100,changedFiles:7}' >"$SCRATCH/fake/pr-211.json"

if ! run_collector 'status:ready'; then
	cat "$SCRATCH/stderr" >&2
	fail 'success scenario unexpectedly failed'
fi

assert_doc 'top-level envelope.' \
	'.schema_version == "1.1"
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

assert_doc 'PR resolved to the closing PR' \
	'([.metrics.issues[] | select(.number == 101)][0].pr) == 211'
assert_doc 'review fields parsed from the latest complete block' \
	'([.metrics.issues[] | select(.number == 101)][0]) |
	.review_iterations == 2 and .review_verdict == "approve"
	and .security == "not triggered" and .exit == "none"'
assert_doc 'LOC actual is additions plus deletions' \
	'([.metrics.issues[] | select(.number == 101)][0].loc_actual) == 400'
assert_doc 'scope estimate extracted' \
	'([.metrics.issues[] | select(.number == 101)][0].scope_estimate) == "M"'

assert_doc 'uninstrumented issue reports unknown, never zero' \
	'([.metrics.issues[] | select(.number == 103)][0]) |
	.pr == "unknown(no-closer)"
	and .review_iterations == "unknown(no-closer)"
	and .loc_actual == "unknown(no-closer)"
	and .scope_estimate == "unknown"
	and .review_verdict == "unknown"
	and .security == "unknown"
	and .exit == "unknown"'

assert_doc 'null-free invariant' \
	'[. | .. | select(type == "null")] | length == 0'

assert_doc 'aggregate median and range over value-state cycles.' \
	'.metrics.aggregate.cycle_hours.count == 2
	and .metrics.aggregate.cycle_hours.min == 4
	and (.metrics.aggregate.cycle_hours.median | type == "number")
	and (.metrics.aggregate.cycle_hours.max | type == "number")
	and .metrics.aggregate.cycle_hours.max > .metrics.aggregate.cycle_hours.min'
assert_doc 'coverage counts value-state entries' \
	'.metrics.coverage == {
		cycle_hours: 2, phase_build_hours: 1, phase_review_hours: 1,
		pr: 1, review_iterations: 1, scope_estimate: 1, loc_actual: 1}'

assert_count 'every gh read is logged' '^gh ' "$SCRATCH/calls" 9
if rg --no-config -q 'graphql' "$SCRATCH/calls"; then
	fail 'collector issued a graphql read'
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
assert_doc 'processing stopped after the fifth consecutive error' \
	'([.metrics.issues[] | select(.number == 205)] | length) == 1
	and ([.metrics.issues[] | select(.number == 206)] | length) == 0
	and ([.metrics.issues[] | select(.number == 207)] | length) == 0'

# --- scenario: ambiguity and a failed PR-side read -----------------------------
cat >"$SCRATCH/fake/search.json" <<'JSON'
[
 {"number":301,"state":"closed","closedAt":"2026-07-01T14:00:00Z","labels":[]},
 {"number":302,"state":"closed","closedAt":"2026-07-02T20:00:00Z","labels":[]}
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
printf '%s\n' '{"comments":[]}' >"$SCRATCH/fake/issue-302.json"
if ! run_collector 'priority:P1'; then
	cat "$SCRATCH/stderr" >&2
	fail 'ambiguity scenario unexpectedly failed'
fi
assert_doc 'ambiguous closers stay unknown, never guessed' \
	'([.metrics.issues[] | select(.number == 301)][0]) |
	.pr == "unknown(ambiguous)"
	and .review_iterations == "unknown(ambiguous)"
	and .loc_actual == "unknown(ambiguous)"'
assert_doc 'never-in-progress is a data gap, not an error' \
	'([.metrics.issues[] | select(.number == 301)][0].cycle_hours) == "unknown(never-in-progress)"'
assert_doc 'failed PR-side read is error while issue-side still computes' \
	'([.metrics.issues[] | select(.number == 302)][0]) |
	.pr == "error" and .loc_actual == "error"
	and .review_iterations == "error"
	and (.cycle_hours | type == "number")'
assert_doc '34-hour cycle computes as fractional hours' \
	'([.metrics.issues[] | select(.number == 302)][0].cycle_hours) == 34'

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
