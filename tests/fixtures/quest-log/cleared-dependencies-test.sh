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
	# The hang arms below are bare `exec sleep 30`: exec replaces the subshell the
	# bound backgrounded, so TERM reaches the blocking process directly. No pid is
	# recorded here -- this fake is a shell function, so `$$` inside it is the
	# test's own pid, not the backgrounded subshell's.
	if [[ $1 == api ]]; then
		if [[ $fake_mode == hang-api ]]; then
			exec sleep 30
		fi
		if [[ $fake_mode == api-fail ]]; then
			printf 'API \033[31mdenied\n' >&2
			return 1
		fi
		printf '%s\n' '[[{"number":101,"state":"open","body":"Blocked by #1","labels":[{"name":"status:blocked"},{"name":"status:in-progress"}]},{"number":102,"state":"open","body":"Blocked by #1\nBlocked by #2","labels":[{"name":"status:blocked"}]},{"number":103,"state":"open","body":"Blocked by #abc","labels":[{"name":"status:blocked"}]},{"number":104,"state":"open","body":"Blocked by #1","labels":[{"name":"status:blocked"},{"name":"epic"}]}],[{"number":106,"state":"open","body":"Blocked by #1 — prerequisite lands first","labels":[{"name":"status:blocked"}]}]]'
		return
	fi
	if [[ $1 == label && $2 == create ]]; then
		[[ $* == *'--repo owner/repo'* ]] || fail 'label create omitted the target repo'
		if [[ $fake_mode == hang-label ]]; then
			exec sleep 30
		fi
		if [[ $fake_mode == label-fail ]]; then
			printf 'label \033[31mdenied\n' >&2
			return 1
		fi
		return
	fi
	if [[ $1 == issue && $2 == edit ]]; then
		if [[ $fake_mode == hang-edit ]]; then
			exec sleep 30
		fi
		# hang-restore is conflict everywhere else; here it hangs only on the
		# restoring write, which carries --add-label status:blocked. The readying
		# write does not, which is how this branch already discriminates below.
		if [[ $fake_mode == hang-restore && $* == *'--add-label status:blocked'* ]]; then
			exec sleep 30
		fi
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
			if [[ $fake_mode == hang-blocker ]]; then
				exec sleep 30
			fi
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
			# The pre-write read and the post-write verification read differ only
			# by whether the edit has happened, which is what this arm already
			# keys on.
			if [[ $fake_mode == hang-dependent && ! -e $ready_state ]]; then
				exec sleep 30
			elif [[ $fake_mode == hang-verify && -e $ready_state ]]; then
				exec sleep 30
			elif [[ $fake_mode == postread-fail && -e $ready_state ]]; then
				printf 'read \033[31mdenied\n' >&2
				return 1
			elif [[ $* == *'--json number,state,body,labels'* && -e $ready_state ]]; then
				if [[ $fake_mode == conflict || $fake_mode == hang-restore ]]; then
					printf '%s\n' '{"number":101,"state":"OPEN","body":"Blocked by #1","labels":[{"name":"status:ready"},{"name":"status:blocked"}]}'
				else
					printf '%s\n' '{"number":101,"state":"OPEN","body":"Blocked by #1","labels":[{"name":"status:ready"}]}'
				fi
			elif [[ $* == *'--json labels'* ]]; then
				if [[ $fake_mode == conflict || $fake_mode == hang-restore ]]; then
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
reset_cleared_dependency_cache
: >"$blocker_log"
cleared_dependency_body_verdict owner/repo 10 \
	'Blocked by #1 — required registration point lands first' ||
	fail 'an annotated closed blocker should clear'
[[ $(cat "$blocker_log") == 1 ]] || fail 'annotated record did not resolve its blocker id'
if cleared_dependency_body_verdict owner/repo 10 $'Blocked by #1\nBlocked by #2'; then
	fail 'an open blocker must retain the dependent'
fi
# Assigned by the sourced canonical recipe.
# shellcheck disable=SC2154
[[ $cleared_dependency_reason == 'open blocker #2 retains #10' ]] ||
	fail 'open-blocker report is not actionable'
reset_cleared_dependency_cache
if cleared_dependency_body_verdict owner/repo 10 'Blocked by #2 — prerequisite is pending'; then
	fail 'an annotated open blocker must retain the dependent'
fi
[[ $cleared_dependency_reason == 'open blocker #2 retains #10' ]] ||
	fail 'annotated open-blocker report is not actionable'
for fixture in \
	'Blocked by #404' \
	'Blocked by #500' \
	'Blocked by #abc' \
	' Blocked by #1' \
	'Blocked by #1 explanation without delimiter' \
	'Blocked by #1 —' \
	'Blocked by #1 —  explanation after two spaces'; do
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

# --- a call that did not answer is not an answer -----------------------------
# Every gh call this recipe makes runs under a bound; a bound exceeded is never
# reported as a missing record, an empty listing, or a failed write. The bounds
# drop to one and two seconds around each case so the suite waits a second or two
# rather than thirty, and are restored afterwards -- the fake blocks for thirty
# either way.
#
# The two are deliberately set to *different* values, and every case below asserts
# which number reached its diagnostic. Setting both to one would leave a site that
# passed the single-request bound where the design's table requires the
# multi-request one, or the reverse, indistinguishable: each case would still pass.
# The distinction costs one extra second across the whole block.
fake_mode=hang-blocker
cleared_dependency_bound_single=1 cleared_dependency_bound_multi=2
if cleared_dependency_body_verdict owner/repo 10 'Blocked by #1'; then
	fail 'a blocker read that did not answer cleared a dependent'
fi
cleared_dependency_bound_single=30 cleared_dependency_bound_multi=120
[[ $cleared_dependency_reason == *'unreadable blocker #1'* ]] ||
	fail "an unanswered blocker read was not unreadable: $cleared_dependency_reason"
[[ $cleared_dependency_reason == *'did not answer'* ]] ||
	fail "an unanswered blocker read did not say so: $cleared_dependency_reason"
[[ $cleared_dependency_reason == *'its 1s bound'* ]] ||
	fail "a blocker read did not run under the single-request bound: $cleared_dependency_reason"
[[ $cleared_dependency_reason != *'missing blocker'* ]] ||
	fail "an unanswered blocker read was reported missing: $cleared_dependency_reason"
[[ $cleared_dependency_reason != *CLOSED* ]] ||
	fail "an unanswered blocker read was reported closed: $cleared_dependency_reason"
fake_mode=normal
reset_cleared_dependency_cache

# A bound the arithmetic destination would reject is refused before the call, not
# after it. `08` is the reachable half of that guard and costs nothing to commit:
# bash reads a leading zero as octal, so `$((08 * 10))` is an arithmetic error.
# Measured on bash 3.2.57, that error lands in the bounded call's `while`
# condition, where `set -e` is suspended -- so it does not abort. The poll is
# abandoned, the bounded call returns 0 with an empty capture, and its child
# survives: a call that answered nothing read as one that succeeded, plus the
# orphan the bound exists to reap. The unreachable half is a bound carrying a
# command substitution, which stays untested because observing it means
# committing the payload.
fake_mode=hang-blocker
cleared_dependency_bound_single=08
if cleared_dependency_body_verdict owner/repo 10 'Blocked by #1'; then
	fail 'a bound the arithmetic would reject cleared a dependent'
fi
cleared_dependency_bound_single=30
[[ $cleared_dependency_reason == *'not a whole number of seconds'* ]] ||
	fail "a leading-zero bound was not refused: $cleared_dependency_reason"
[[ $cleared_dependency_reason != *'did not answer'* ]] ||
	fail "a refused bound was reported as a call that did not answer: $cleared_dependency_reason"
fake_mode=normal
reset_cleared_dependency_cache

: >"$gh_log"
fake_mode=hang-api
cleared_dependency_bound_single=1 cleared_dependency_bound_multi=2
set +e
reconcile_cleared_dependencies plan owner/repo >/dev/null 2>"$SCRATCH/hang-api"
hang_api_status=$?
set -e
cleared_dependency_bound_single=30 cleared_dependency_bound_multi=120
fake_mode=normal
[[ $hang_api_status -eq 1 ]] || fail 'an unanswered issue listing must exit 1'
rg -q --no-config 'cannot list open dependents' "$SCRATCH/hang-api" ||
	fail 'an unanswered issue listing was not named'
rg -q --no-config 'did not answer' "$SCRATCH/hang-api" ||
	fail 'an unanswered issue listing did not say so'
rg -q --no-config 'its 2s bound' "$SCRATCH/hang-api" ||
	fail 'the paginated listing did not run under the multi-request bound'
rg -q --no-config 'no labels changed' "$SCRATCH/hang-api" ||
	fail 'an unanswered issue listing did not say no labels changed'
[[ ! -s $gh_log ]] || fail 'an unanswered issue listing changed labels'
reset_cleared_dependency_cache

rm -f "$ready_state"
: >"$gh_log"
fake_mode=hang-label
cleared_dependency_bound_single=1 cleared_dependency_bound_multi=2
if apply_cleared_dependency owner/repo "$initial" >/dev/null 2>"$SCRATCH/hang-label"; then
	fail 'an unanswered label create must fail closed'
fi
cleared_dependency_bound_single=30 cleared_dependency_bound_multi=120
fake_mode=normal
rg -q --no-config 'may or may not exist' "$SCRATCH/hang-label" ||
	fail 'an unanswered label create was reported as a failure, not as indeterminate'
rg -q --no-config 'its 1s bound' "$SCRATCH/hang-label" ||
	fail 'the label create did not run under the single-request bound'
[[ ! -s $gh_log ]] || fail 'an unanswered label create still attempted an edit'
reset_cleared_dependency_cache

rm -f "$ready_state"
: >"$gh_log"
fake_mode=hang-edit
cleared_dependency_bound_single=1 cleared_dependency_bound_multi=2
if apply_cleared_dependency owner/repo "$initial" >/dev/null 2>"$SCRATCH/hang-edit"; then
	fail 'an unanswered label write must fail closed'
fi
cleared_dependency_bound_single=30 cleared_dependency_bound_multi=120
fake_mode=normal
rg -q --no-config 'may or may not have been changed' "$SCRATCH/hang-edit" ||
	fail 'an unanswered label write was reported as a failure, not as indeterminate'
rg -q --no-config 'its 2s bound' "$SCRATCH/hang-edit" ||
	fail 'the label write did not run under the multi-request bound'
if rg -q --no-config -- '--add-label status:blocked' "$gh_log"; then
	fail 'an unanswered label write was followed by a restore'
fi
reset_cleared_dependency_cache

rm -f "$ready_state"
: >"$gh_log"
fake_mode=hang-dependent
cleared_dependency_bound_single=1 cleared_dependency_bound_multi=2
if apply_cleared_dependency owner/repo "$initial" >/dev/null 2>"$SCRATCH/hang-dependent"; then
	fail 'an unanswered dependent read must fail closed'
fi
cleared_dependency_bound_single=30 cleared_dependency_bound_multi=120
fake_mode=normal
rg -q --no-config 'unreadable dependent #101' "$SCRATCH/hang-dependent" ||
	fail 'an unanswered dependent read was not unreadable'
rg -q --no-config 'did not answer' "$SCRATCH/hang-dependent" ||
	fail 'an unanswered dependent read did not say so'
rg -q --no-config 'its 1s bound' "$SCRATCH/hang-dependent" ||
	fail 'the dependent read did not run under the single-request bound'
reset_cleared_dependency_cache

rm -f "$ready_state"
: >"$gh_log"
fake_mode=hang-verify
cleared_dependency_bound_single=1 cleared_dependency_bound_multi=2
if apply_cleared_dependency owner/repo "$initial" >/dev/null 2>"$SCRATCH/hang-verify"; then
	fail 'an unanswered verification read must fail closed'
fi
cleared_dependency_bound_single=30 cleared_dependency_bound_multi=120
fake_mode=normal
rg -q --no-config 'verification unreadable for #101' "$SCRATCH/hang-verify" ||
	fail 'an unanswered verification read was not unreadable'
rg -q --no-config 'did not answer' "$SCRATCH/hang-verify" ||
	fail 'an unanswered verification read did not say so'
rg -q --no-config 'its 1s bound' "$SCRATCH/hang-verify" ||
	fail 'the verification read did not run under the single-request bound'
# A call that did not answer is not evidence the write went wrong.
if rg -q --no-config -- '--add-label status:blocked' "$gh_log"; then
	fail 'an unanswered verification read triggered a restore'
fi
reset_cleared_dependency_cache

rm -f "$ready_state"
: >"$gh_log"
fake_mode=hang-restore
cleared_dependency_bound_single=1 cleared_dependency_bound_multi=2
if apply_cleared_dependency owner/repo "$initial" >/dev/null 2>"$SCRATCH/hang-restore"; then
	fail 'a conflicting write whose restore did not answer must fail closed'
fi
# The last of the restores, and nothing below reads the bounds again, which is
# what shellcheck sees here. The sourced recipe reads them, not this file.
# shellcheck disable=SC2034
cleared_dependency_bound_single=30 cleared_dependency_bound_multi=120
fake_mode=normal
rg -q --no-config 'conflicting status write' "$SCRATCH/hang-restore" ||
	fail 'an unanswered restore masked the primary error'
rg -q --no-config 'restoring #101 to status:blocked' "$SCRATCH/hang-restore" ||
	fail 'an unanswered restore did not name the call'
rg -q --no-config 'may or may not have been changed' "$SCRATCH/hang-restore" ||
	fail 'an unanswered restore was reported as a failure, not as indeterminate'
rg -q --no-config 'its 2s bound' "$SCRATCH/hang-restore" ||
	fail 'the restore did not run under the multi-request bound'
[[ $(wc -l <"$gh_log") -eq 1 ]] ||
	fail 'an unanswered restore wrote more than the readying edit'
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

# --- direct execution mirrors the sourced contract ----------------------------
# The asset was a functions-only library, so executing it was a silent no-op and
# every documented caller had to source it into its own shell -- the shape that
# produced #198. The main guard at the foot of the file dispatches to
# reconcile_cleared_dependencies when bash executes the file instead of sources
# it, so one command's exit status is the verdict. The cases below run the file
# as a subprocess against the same fake gh -- exported with its variables and
# reached through a PATH shim -- and hold it to the same output and statuses as
# the sourced cases above.
fake_bin=$SCRATCH/direct-bin
mkdir -p "$fake_bin"
printf '#!/usr/bin/env bash\ngh "$@"\n' >"$fake_bin/gh"
chmod +x "$fake_bin/gh"
export -f gh fail
export SCRATCH FIXTURE_LABEL fake_mode gh_log ready_state blocker_log

direct_out=$SCRATCH/direct-plan.out
direct_err=$SCRATCH/direct-plan.err
fake_mode=normal
set +e
PATH="$fake_bin:$PATH" \
	bash "$script_dir/../../../skills/quest-log/assets/cleared-dependencies.sh" \
	plan owner/repo >"$direct_out" 2>"$direct_err"
direct_status=$?
set -e
[[ $direct_status -eq 1 ]] || fail 'direct execution lost the partial-failure status'
[[ $(cat "$direct_out") == $'ready #101\nready #106' ]] ||
	fail "direct plan mode selected the wrong dependents: $(cat "$direct_out")"
rg -q --no-config 'open blocker #2 retains #102' "$direct_err" ||
	fail 'direct execution did not report the open blocker'
rg -q --no-config 'malformed reference on #103' "$direct_err" ||
	fail 'direct execution did not report the malformed line'

direct_ok_out=$SCRATCH/direct-plan-target.out
set +e
PATH="$fake_bin:$PATH" \
	bash "$script_dir/../../../skills/quest-log/assets/cleared-dependencies.sh" \
	plan owner/repo 101 >"$direct_ok_out" 2>/dev/null
direct_ok_status=$?
set -e
[[ $direct_ok_status -eq 0 ]] || fail 'a clean targeted direct plan must exit 0'
[[ $(cat "$direct_ok_out") == 'ready #101' ]] ||
	fail "targeted direct plan selected the wrong dependents: $(cat "$direct_ok_out")"

direct_usage_err=$SCRATCH/direct-usage.err
set +e
PATH="$fake_bin:$PATH" \
	bash "$script_dir/../../../skills/quest-log/assets/cleared-dependencies.sh" \
	>"$SCRATCH/direct-usage.out" 2>"$direct_usage_err"
direct_usage_status=$?
set -e
[[ $direct_usage_status -eq 2 ]] || fail 'a direct usage error must exit 2'
rg -q --no-config '^usage:' "$direct_usage_err" ||
	fail 'the direct usage error printed no usage line'

# Executed, a bound exceeded is the same verdict the sourced form reports: exit
# 1, its degraded-or-partial class, never the exit 2 it spends on usage. The
# bound is exported rather than assigned in the file, which is why the file
# assigns its defaults with `:=`.
direct_hang_err=$SCRATCH/direct-hang.err
fake_mode=hang-api
set +e
PATH="$fake_bin:$PATH" cleared_dependency_bound_multi=1 \
	bash "$script_dir/../../../skills/quest-log/assets/cleared-dependencies.sh" \
	plan owner/repo >"$SCRATCH/direct-hang.out" 2>"$direct_hang_err"
direct_hang_status=$?
set -e
fake_mode=normal
[[ $direct_hang_status -eq 1 ]] || fail 'a direct unanswered listing must exit 1'
rg -q --no-config 'cannot list open dependents' "$direct_hang_err" ||
	fail 'direct execution did not report the unanswered listing'

# --- a non-bash interpreter refuses without killing the caller ---------------
# The recipes no longer instruct anyone to source this asset, but sourcing
# stays supported and a sourcing caller's shell is not always bash.
# `cleared_dependency_run` declared `local status=0`, and `status`
# is a read-only special parameter in zsh: reaching the declaration killed the
# caller's whole session, swallowing every command queued behind it until the
# harness timed out. The asset now refuses at the top of the file instead, so
# the probe below asserts the caller survives the refusal. Skipped with a
# printed notice where zsh is not installed -- the ubuntu CI leg carries none
# -- rather than silently passing, which would read as coverage it does not
# have; the macOS leg and any zsh-equipped workstation run it for real.
if command -v zsh >/dev/null; then
	zsh_probe=$SCRATCH/zsh-refusal.sh
	{
		printf 'source %q\n' \
			"$script_dir/../../../skills/quest-log/assets/cleared-dependencies.sh"
		printf 'reconcile_cleared_dependencies plan owner/repo\n'
		printf 'printf "SENTINEL_REACHED\\n"\n'
	} >"$zsh_probe"
	set +e
	zsh "$zsh_probe" >"$SCRATCH/zsh-refusal.out" 2>"$SCRATCH/zsh-refusal.err"
	set -e
	rg -q 'SENTINEL_REACHED' "$SCRATCH/zsh-refusal.out" ||
		fail 'the zsh refusal killed the caller instead of returning'
	rg -q 'requires bash' "$SCRATCH/zsh-refusal.err" ||
		fail 'the zsh refusal did not name bash as the requirement'
	rg -q 'command not found' "$SCRATCH/zsh-refusal.err" ||
		fail 'the guard did not stop the recipe from being defined'
else
	printf 'cleared-dependencies-test: zsh not installed; interpreter-guard case skipped\n'
fi
printf 'cleared-dependencies-test: pass\n'
