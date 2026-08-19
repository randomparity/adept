#!/usr/bin/env bash
set -euo pipefail

# ripgrep applies RIPGREP_CONFIG_PATH's contents as arguments ahead of the ones
# passed below, so a personal ripgreprc would otherwise steer this suite's own
# assertions.
unset RIPGREP_CONFIG_PATH

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/../../../scripts/test-fixture-helpers.sh
. "$script_dir/../../../scripts/test-fixture-helpers.sh"

fixture_init cleared-dependencies-test
# The recipe ships as an asset under skills/; lint and format gates cover it
# directly now that it is a file rather than a block embedded in SKILL.md.
# shellcheck source=/dev/null
source "$script_dir/../../../skills/quest-log/assets/cleared-dependencies.sh"

gh_log=$SCRATCH/gh.log
blocker_log=$SCRATCH/blockers.log
ready_state=$SCRATCH/ready
fake_mode=normal

gh() {
	# gh writes non-fatal material to stderr while exiting 0, and a
	# release-update notice is the common one. Every mode below can carry it,
	# because the defect it reproduces is not in any one call: it is in reading a
	# capture whose stdout is a value with the streams merged.
	if [[ $fake_mode == chatty ]]; then
		printf 'A new release of gh is available: 2.63.0 -> 2.65.0\n' >&2
	fi
	if [[ $1 == api ]]; then
		if [[ $fake_mode == api-fail ]]; then
			printf 'API \033[31mdenied\n' >&2
			return 1
		fi
		printf '%s\n' '[[{"number":101,"state":"open","body":"Blocked by #1","labels":[{"name":"status:blocked"},{"name":"status:in-progress"}]},{"number":102,"state":"open","body":"Blocked by #1\nBlocked by #2","labels":[{"name":"status:blocked"}]},{"number":103,"state":"open","body":"Blocked by #abc","labels":[{"name":"status:blocked"}]},{"number":104,"state":"open","body":"Blocked by #1","labels":[{"name":"status:blocked"},{"name":"epic"}]}],[{"number":106,"state":"open","body":"Blocked by #1","labels":[{"name":"status:blocked"}]}]]'
		return
	fi
	if [[ $1 == label && $2 == create ]]; then
		[[ $* == *'--repo owner/repo'* ]] || fail 'label create omitted the target repo'
		if [[ $fake_mode == label-fail ]]; then
			printf 'label \033[31mdenied\n' >&2
			return 1
		fi
		return
	fi
	if [[ $1 == issue && $2 == edit ]]; then
		if [[ $fake_mode == edit-fail ]]; then
			printf 'edit \033[31mdenied\n' >&2
			return 1
		fi
		printf '%s\n' "$*" >>"$gh_log"
		if [[ $* == *'--add-label status:blocked'* ]]; then
			rm -f "$ready_state"
		else
			: >"$ready_state"
		fi
		return
	fi
	if [[ $1 == issue && $2 == view ]]; then
		case $3 in
		1)
			printf '1\n' >>"$blocker_log"
			if [[ $fake_mode == race && -e $ready_state ]]; then
				printf 'OPEN\n'
			else
				printf 'CLOSED\n'
			fi
			;;
		2)
			printf '2\n' >>"$blocker_log"
			printf 'OPEN\n'
			;;
		404)
			printf 'not found\n' >&2
			return 1
			;;
		500)
			printf 'permission \033[31mdenied\n' >&2
			return 1
			;;
		101)
			if [[ $fake_mode == postread-fail && -e $ready_state ]]; then
				printf 'read \033[31mdenied\n' >&2
				return 1
			elif [[ $* == *'--json number,state,body,labels'* && -e $ready_state ]]; then
				if [[ $fake_mode == conflict ]]; then
					printf '%s\n' '{"number":101,"state":"OPEN","body":"Blocked by #1","labels":[{"name":"status:ready"},{"name":"status:blocked"}]}'
				else
					printf '%s\n' '{"number":101,"state":"OPEN","body":"Blocked by #1","labels":[{"name":"status:ready"}]}'
				fi
			elif [[ $* == *'--json labels'* ]]; then
				if [[ $fake_mode == conflict ]]; then
					printf '%s\n' '{"labels":[{"name":"status:ready"},{"name":"status:blocked"}]}'
				else
					printf '%s\n' '{"labels":[{"name":"status:ready"}]}'
				fi
			elif [[ $fake_mode == stale ]]; then
				printf '%s\n' '{"number":101,"state":"OPEN","body":"Blocked by #1","labels":[{"name":"status:ready"}]}'
			elif [[ $fake_mode == changed-body ]]; then
				printf '%s\n' '{"number":101,"state":"OPEN","body":"Blocked by #2","labels":[{"name":"status:blocked"},{"name":"status:in-progress"}]}'
			else
				printf '%s\n' '{"number":101,"state":"OPEN","body":"Blocked by #1","labels":[{"name":"status:blocked"},{"name":"status:in-progress"}]}'
			fi
			;;
		*) fail "unexpected fake gh call: $*" ;;
		esac
		return
	fi
	fail "unexpected fake gh call: $*"
}

reset_cleared_dependency_cache
: >"$blocker_log"
cleared_dependency_body_verdict owner/repo 10 $'Blocked by #1\nBlocked by #1' ||
	fail 'multiple closed canonical blockers should clear'
[[ $(wc -l <"$blocker_log") -eq 1 ]] || fail 'duplicate blockers were not deduplicated'
if cleared_dependency_body_verdict owner/repo 10 $'Blocked by #1\nBlocked by #2'; then
	fail 'an open blocker must retain the dependent'
fi
# Assigned by the sourced canonical recipe.
# shellcheck disable=SC2154
[[ $cleared_dependency_reason == 'open blocker #2 retains #10' ]] ||
	fail 'open-blocker report is not actionable'
for fixture in 'Blocked by #404' 'Blocked by #500' 'Blocked by #abc' ' Blocked by #1'; do
	if cleared_dependency_body_verdict owner/repo 10 "$fixture"; then
		fail "invalid dependency record cleared: $fixture"
	fi
done
reset_cleared_dependency_cache
cleared_dependency_body_verdict owner/repo 10 'Blocked by #500' || :
[[ $cleared_dependency_reason != *$'\033'* ]] || fail 'diagnostic leaked a control character'
reset_cleared_dependency_cache
cleared_dependency_max_lookups=1
if cleared_dependency_body_verdict owner/repo 10 $'Blocked by #1\nBlocked by #2'; then
	fail 'lookup budget overflow must retain the dependent'
fi
[[ $cleared_dependency_reason == *'rerun with issue-number batches'* ]] ||
	fail 'lookup overflow was not resumable'
# Consumed by the sourced canonical recipe on later calls.
# shellcheck disable=SC2034
cleared_dependency_max_lookups=500

plan_errors=$SCRATCH/plan-errors
set +e
plan_output=$(reconcile_cleared_dependencies plan owner/repo 2>"$plan_errors")
plan_status=$?
set -e
[[ $plan_status -eq 1 ]] || fail 'degraded dependents must produce partial-failure status'
[[ $plan_output == $'ready #101\nready #106' ]] ||
	fail "plan mode selected the wrong dependents: $plan_output"
[[ ! -s $gh_log ]] || fail 'plan mode wrote labels'
rg -q 'open blocker #2 retains #102' "$plan_errors" || fail 'open blocker was not reported'
rg -q 'malformed reference on #103' "$plan_errors" || fail 'malformed line was not reported'

initial='{"number":101,"state":"OPEN","body":"Blocked by #1","labels":[{"name":"status:blocked"},{"name":"status:in-progress"}]}'
rm -f "$ready_state"
: >"$gh_log"
reconcile_cleared_dependencies apply owner/repo 101 >/dev/null
[[ $(wc -l <"$gh_log") -eq 1 ]] || fail 'REST-to-GraphQL state normalization failed'
: >"$gh_log"
rm -f "$ready_state"
apply_cleared_dependency owner/repo "$initial" >/dev/null
edit=$(<"$gh_log")
[[ $edit == *'--remove-label status:blocked'* ]] || fail 'blocked label was not removed'
[[ $edit == *'--remove-label status:in-progress'* ]] || fail 'second status was not removed'
[[ $edit == *'--add-label status:ready'* ]] || fail 'ready label was not added'
[[ $(wc -l <"$gh_log") -eq 1 ]] || fail 'status swap used more than one edit call'

# --- a non-fatal notice beside a value ---------------------------------------
# The four captures whose stdout is a value take stdout alone. While they merged
# the streams, a notice joined the value: a closed blocker read as open, and the
# corrupted word was cached, so one notice retained every dependent of that
# blocker for the rest of the run. The two payload captures and the listing fed
# the notice to jq, which then blamed a race that had not happened. All four
# sites are covered below.
fake_mode=chatty
reset_cleared_dependency_cache
cleared_dependency_body_verdict owner/repo 10 'Blocked by #1' ||
	fail "a notice beside a blocker state retained #10: $cleared_dependency_reason"
# Assigned by the sourced canonical recipe.
# shellcheck disable=SC2154
[[ ${cleared_dependency_blocker_states[0]} == CLOSED ]] ||
	fail "the blocker cache kept a notice: ${cleared_dependency_blocker_states[0]}"

reset_cleared_dependency_cache
set +e
chatty_plan=$(reconcile_cleared_dependencies plan owner/repo 2>"$SCRATCH/chatty-plan")
chatty_status=$?
set -e
[[ $chatty_status -eq 1 ]] || fail 'a notice changed plan mode partial-failure status'
[[ $chatty_plan == $'ready #101\nready #106' ]] ||
	fail "a notice on the issue listing changed the plan: $chatty_plan"
if rg -q 'cannot parse open dependents' "$SCRATCH/chatty-plan"; then
	fail 'a notice reached the issue-listing payload'
fi

reset_cleared_dependency_cache
rm -f "$ready_state"
: >"$gh_log"
apply_cleared_dependency owner/repo "$initial" >/dev/null 2>"$SCRATCH/chatty-apply" ||
	fail "a notice on a dependent payload cancelled the transition: $(<"$SCRATCH/chatty-apply")"
rg -q -- '--add-label status:ready' "$gh_log" ||
	fail 'the chatty apply path did not ready the dependent'

# A host that cannot allocate the scratch file reports through the same
# diagnostic as a gh call that did not answer: the lookup did not happen, and
# nothing has been written at any of the four sites. Shimmed as a function
# because the recipe is sourced into this shell rather than run as a subprocess.
fake_mode=normal
reset_cleared_dependency_cache
# shellcheck disable=SC2329 # called by the sourced recipe, not from this file
mktemp() { return 1; }
if cleared_dependency_body_verdict owner/repo 10 'Blocked by #1'; then
	fail 'an unallocatable scratch file cleared a dependent'
fi
unset -f mktemp
[[ $cleared_dependency_reason == *'no scratch file'* ]] ||
	fail "unallocatable scratch was not named: $cleared_dependency_reason"
reset_cleared_dependency_cache

fake_mode=stale
rm -f "$ready_state"
if apply_cleared_dependency owner/repo "$initial" >/dev/null 2>"$SCRATCH/stale"; then
	fail 'stale dependent snapshot must cancel the transition'
fi
rg -q 'stale evaluation' "$SCRATCH/stale" || fail 'stale snapshot was not reported'

fake_mode=changed-body
rm -f "$ready_state"
if apply_cleared_dependency owner/repo "$initial" >/dev/null 2>"$SCRATCH/changed"; then
	fail 'changed dependency body must cancel the transition'
fi
rg -q 'dependency snapshot changed' "$SCRATCH/changed" ||
	fail 'changed dependency body was not reported'

fake_mode=conflict
rm -f "$ready_state"
if apply_cleared_dependency owner/repo "$initial" >/dev/null 2>"$SCRATCH/conflict"; then
	fail 'conflicting post-write status must be reported'
fi
rg -q 'conflicting status write' "$SCRATCH/conflict" || fail 'conflict was not actionable'

fake_mode=race
rm -f "$ready_state"
: >"$gh_log"
if apply_cleared_dependency owner/repo "$initial" >/dev/null 2>"$SCRATCH/race"; then
	fail 'a blocker reopened during the edit must restore blocked status'
fi
rg -q 'restored #101 to status:blocked' "$SCRATCH/race" ||
	fail 'post-write blocker race was not restored'
rg -q -- '--add-label status:blocked' "$gh_log" || fail 'race did not restore blocked label'

for failure_mode in label-fail edit-fail postread-fail; do
	fake_mode=$failure_mode
	rm -f "$ready_state"
	if apply_cleared_dependency owner/repo "$initial" >/dev/null \
		2>"$SCRATCH/$failure_mode"; then
		fail "$failure_mode must fail closed"
	fi
	if LC_ALL=C rg -q $'\033' "$SCRATCH/$failure_mode"; then
		fail "$failure_mode leaked a control character"
	fi
done
fake_mode=api-fail
if reconcile_cleared_dependencies plan owner/repo >/dev/null 2>"$SCRATCH/api-fail"; then
	fail 'unreadable issue listing must fail closed'
fi
if LC_ALL=C rg -q $'\033' "$SCRATCH/api-fail"; then
	fail 'issue-list error leaked a control character'
fi

printf 'cleared-dependencies-test: pass\n'
