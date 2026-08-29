#!/usr/bin/env bash

# Executed, this file is the canonical cleared-dependency recipe: the main
# guard at the foot of the file dispatches to reconcile_cleared_dependencies,
# so one command's exit status is the verdict and nothing lands in the caller's
# shell. Sourced, it stays a library -- the behaviour suite takes the function
# bodies from it that way -- and a sourcing caller's shell is not always bash.
# The function bodies below use bash-only forms (`${!array[@]}`,
# `BASH_REMATCH`), and one was worse than a failed call:
# `cleared_dependency_run` declared `local status=0`, which under zsh assigns
# the read-only special parameter `status` and killed the caller's whole
# session. That declaration is `rc` now; the guard is what keeps every body
# unreachable from a shell that cannot run it. `return`, never `exit`: an exit
# inside a sourced file takes down the very session this guard exists to
# protect, which is the failure mode itself. When bash executes or sources the
# file, BASH_VERSION is always set and the guard does not fire.
[ -n "${BASH_VERSION:-}" ] || {
	printf 'cleared-dependencies.sh requires bash; source it from bash\n' >&2
	return 1
}

cleared_dependency_reason=
cleared_dependency_error=false
cleared_dependency_max_lookups=500
cleared_dependency_lookup_count=0
cleared_dependency_blocker_ids=()
cleared_dependency_blocker_states=()
cleared_dependency_state=
cleared_dependency_out=
cleared_dependency_err=

reset_cleared_dependency_cache() {
	cleared_dependency_lookup_count=0
	clear_cleared_dependency_results
}

clear_cleared_dependency_results() {
	cleared_dependency_blocker_ids=()
	cleared_dependency_blocker_states=()
}

cleared_dependency_safe_text() {
	LC_ALL=C tr -cd '[:print:]' | cut -c1-200
}

# Four calls in this file read a value out of gh's stdout: a blocker's state
# word, two issue payloads, and the open-issue page set. gh writes non-fatal
# material to stderr while exiting 0 -- a release-update notice is the common
# one -- so capturing those with the streams merged made that line part of the
# value, and the recipe then decided labels from it. A closed blocker read as
# open and the reason reported was false; worse, the blocker cache kept the
# corrupted word, so one notice retained every dependent of that blocker for the
# rest of the run. The payload captures fed the notice to jq, which then blamed
# a race that had not happened.
#
# Stderr goes to a scratch file instead, and is read only to build the failure
# diagnostic, so `unreadable blocker`, `unreadable dependent` and `cannot list
# open dependents` keep naming a real reason. The merges on the `gh label
# create` and `gh issue edit` calls below are a different thing and stay: those
# capture a diagnostic and discard it on success.
#
# The value comes back in a variable rather than on stdout because a caller
# capturing stdout would run this function in a subshell, and the stderr it
# recorded would be discarded along with it.
#
# The scratch file is allocated and removed per call rather than held across the
# run by an EXIT trap: this file is sourced, so a trap installed here would take
# the slot from whichever skill sourced it. A host that cannot allocate one
# reports through the same diagnostic as a gh call that did not answer, which is
# the honest reading -- the lookup did not happen, and none of the four points
# has written anything yet. The removal is guarded because a caller running
# under `set -e` would otherwise end on a failed rm after a lookup that
# succeeded.
cleared_dependency_run() { # gh-args...
	local scratch rc=0
	cleared_dependency_out=
	cleared_dependency_err=
	scratch=$(mktemp) || {
		cleared_dependency_err='no scratch file for the tracker command'
		return 1
	}
	cleared_dependency_out=$(gh "$@" 2>"$scratch") || rc=$?
	cleared_dependency_err=$(<"$scratch")
	rm -f -- "$scratch" ||
		printf 'retained scratch path: %s\n' "$scratch" >&2
	return "$rc"
}

cleared_dependency_blocker_state() { # repo blocker dependent
	local repo=$1 blocker=$2 dependent=$3 index state safe
	for index in "${!cleared_dependency_blocker_ids[@]}"; do
		if [[ ${cleared_dependency_blocker_ids[$index]} == "$blocker" ]]; then
			cleared_dependency_state=${cleared_dependency_blocker_states[$index]}
			return
		fi
	done
	if ((cleared_dependency_lookup_count >= cleared_dependency_max_lookups)); then
		cleared_dependency_state="OVERFLOW:$dependent"
		return
	fi
	((cleared_dependency_lookup_count += 1))
	if cleared_dependency_run issue view "$blocker" --repo "$repo" \
		--json state --jq .state; then
		state=$cleared_dependency_out
	else
		safe=$(printf '%s' "$cleared_dependency_err" | cleared_dependency_safe_text)
		if [[ $cleared_dependency_err == *'not found'* ||
			$cleared_dependency_err == *'Could not resolve'* ]]; then
			state=MISSING
		else
			state="UNREADABLE:$safe"
		fi
	fi
	cleared_dependency_blocker_ids+=("$blocker")
	cleared_dependency_blocker_states+=("$state")
	cleared_dependency_state=$state
}

cleared_dependency_body_verdict() { # repo number body
	local repo=$1 number=$2 body=$3 line blocker state
	local -a blockers=()
	cleared_dependency_reason=
	cleared_dependency_error=false
	while IFS= read -r line; do
		if [[ $line =~ ^Blocked\ by\ \#([0-9]+)$ ]]; then
			blockers+=("${BASH_REMATCH[1]}")
		elif [[ $line == 'Blocked by #'* ]]; then
			cleared_dependency_reason="malformed reference on #$number; expected Blocked by #N"
			cleared_dependency_error=true
			return 1
		fi
	done <<<"$body"
	if ((${#blockers[@]} == 0)); then
		cleared_dependency_reason="no canonical references on #$number"
		return 1
	fi
	for blocker in "${blockers[@]}"; do
		cleared_dependency_blocker_state "$repo" "$blocker" "$number"
		state=$cleared_dependency_state
		if [[ $state == MISSING ]]; then
			cleared_dependency_reason="missing blocker #$blocker for #$number"
			cleared_dependency_error=true
			return 1
		elif [[ $state == UNREADABLE:* ]]; then
			cleared_dependency_reason="unreadable blocker #$blocker for #$number: ${state#*:}"
			cleared_dependency_error=true
			return 1
		elif [[ $state == OVERFLOW:* ]]; then
			cleared_dependency_reason="lookup budget exhausted at #$number; rerun with issue-number batches"
			cleared_dependency_error=true
			return 1
		fi
		if [[ $state != CLOSED ]]; then
			cleared_dependency_reason="open blocker #$blocker retains #$number"
			return 1
		fi
	done
}

cleared_dependency_candidate() { # issue-json
	jq -e '
    (.state | ascii_upcase) == "OPEN" and
    (any(.labels[]?.name; . == "status:blocked")) and
    (all(.labels[]?.name; . != "epic"))
  ' >/dev/null <<<"$1"
}

ensure_cleared_dependency_label() { # repo
	local repo=$1 err safe
	if ! err=$(gh label create 'status:ready' --repo "$repo" --color 0e8a16 \
		--description 'triaged, eligible for work' 2>&1); then
		[[ $err == *'already exists'* ]] && return 0
		safe=$(printf '%s' "$err" | cleared_dependency_safe_text)
		printf 'cannot create status:ready: %s — grant label-write scope\n' "$safe" >&2
		return 1
	fi
}

restore_cleared_dependency_blocked() { # repo number issue-json reason
	local repo=$1 number=$2 issue=$3 reason=$4 label err safe
	local -a remove_args=()
	while IFS= read -r label; do
		remove_args+=(--remove-label "$label")
	done < <(jq -r '.labels[].name | select(startswith("status:"))' <<<"$issue")
	if ! err=$(gh issue edit "$number" --repo "$repo" "${remove_args[@]}" \
		--add-label 'status:blocked' 2>&1); then
		safe=$(printf '%s' "$err" | cleared_dependency_safe_text)
		printf 'cannot restore #%s to status:blocked after %s: %s\n' \
			"$number" "$reason" "$safe" >&2
		return 1
	fi
	printf 'restored #%s to status:blocked after %s\n' "$number" "$reason" >&2
}

apply_cleared_dependency() { # repo issue-json
	local repo=$1 initial=$2 number current body final label status_labels
	local initial_snapshot current_snapshot snapshot_filter err safe
	local -a remove_args=()
	number=$(jq -r .number <<<"$initial")
	if ! cleared_dependency_run issue view "$number" --repo "$repo" \
		--json number,state,body,labels; then
		safe=$(printf '%s' "$cleared_dependency_err" | cleared_dependency_safe_text)
		printf 'unreadable dependent #%s: %s; kept blocked\n' "$number" "$safe" >&2
		return 1
	fi
	current=$cleared_dependency_out
	if ! cleared_dependency_candidate "$current"; then
		printf 'stale evaluation for #%s; state, labels, or epic status changed\n' \
			"$number" >&2
		return 1
	fi
	snapshot_filter='{
    state: (.state | ascii_upcase),
    body,
    status: ([.labels[].name | select(startswith("status:"))] | sort),
    epic: any(.labels[].name; . == "epic")
  }'
	initial_snapshot=$(jq -Sc "$snapshot_filter" <<<"$initial")
	current_snapshot=$(jq -Sc "$snapshot_filter" <<<"$current")
	if [[ $initial_snapshot != "$current_snapshot" ]]; then
		printf 'stale evaluation for #%s; dependency snapshot changed\n' "$number" >&2
		return 1
	fi
	body=$(jq -r '.body // ""' <<<"$current")
	if ! cleared_dependency_body_verdict "$repo" "$number" "$body"; then
		printf '%s\n' "$cleared_dependency_reason" >&2
		return 1
	fi
	while IFS= read -r label; do
		remove_args+=(--remove-label "$label")
	done < <(jq -r '.labels[].name | select(startswith("status:"))' <<<"$current")
	ensure_cleared_dependency_label "$repo" || return 1
	if ! err=$(gh issue edit "$number" --repo "$repo" "${remove_args[@]}" \
		--add-label 'status:ready' 2>&1); then
		safe=$(printf '%s' "$err" | cleared_dependency_safe_text)
		printf 'label update failed for #%s: %s; inspect its status labels\n' \
			"$number" "$safe" >&2
		return 1
	fi
	if ! cleared_dependency_run issue view "$number" --repo "$repo" \
		--json number,state,body,labels; then
		safe=$(printf '%s' "$cleared_dependency_err" | cleared_dependency_safe_text)
		printf 'verification unreadable for #%s: %s; inspect its status labels\n' \
			"$number" "$safe" >&2
		return 1
	fi
	final=$cleared_dependency_out
	if ! status_labels=$(jq -c \
		'[.labels[].name | select(startswith("status:"))]' <<<"$final" 2>&1); then
		safe=$(printf '%s' "$status_labels" | cleared_dependency_safe_text)
		printf 'verification unreadable for #%s: %s; inspect its status labels\n' \
			"$number" "$safe" >&2
		return 1
	fi
	if [[ $status_labels != '["status:ready"]' ]]; then
		restore_cleared_dependency_blocked "$repo" "$number" "$final" \
			'a conflicting status write' || : # scan-fault: deliberate — best-effort restore; primary error already reported
		return 1
	fi
	if ! jq -e '(.state | ascii_upcase) == "OPEN" and
    (all(.labels[].name; . != "epic"))' >/dev/null <<<"$final"; then
		restore_cleared_dependency_blocked "$repo" "$number" "$final" \
			'post-write state changed' || : # scan-fault: deliberate — best-effort restore; primary error already reported
		return 1
	fi
	clear_cleared_dependency_results
	body=$(jq -r '.body // ""' <<<"$final")
	if ! cleared_dependency_body_verdict "$repo" "$number" "$body"; then
		restore_cleared_dependency_blocked "$repo" "$number" "$final" \
			"$cleared_dependency_reason" || : # scan-fault: deliberate — best-effort restore; primary error already reported
		return 1
	fi
	printf 'readied #%s\n' "$number"
}

reconcile_cleared_dependencies() { # plan|apply owner/name
	local mode=$1 repo=$2 pages issues issue number body target selected safe failures=0
	local -a targets=()
	shift 2
	targets=("$@")
	reset_cleared_dependency_cache
	[[ $mode == plan || $mode == apply ]] || {
		printf 'usage: reconcile_cleared_dependencies plan|apply owner/name\n' >&2
		return 2
	}
	cleared_dependency_run api --paginate --slurp -X GET \
		"repos/$repo/issues?state=open&per_page=100" || {
		safe=$(printf '%s' "$cleared_dependency_err" | cleared_dependency_safe_text)
		printf 'cannot list open dependents: %s; no labels changed\n' "$safe" >&2
		return 1
	}
	pages=$cleared_dependency_out
	if ! issues=$(jq -ce '[.[][] | select(has("pull_request") | not)]' \
		<<<"$pages" 2>&1); then
		issues=$(printf '%s' "$issues" | cleared_dependency_safe_text)
		printf 'cannot parse open dependents: %s; no labels changed\n' "$issues" >&2
		return 1
	fi
	while IFS= read -r issue; do
		cleared_dependency_candidate "$issue" || continue # scan-fault: deliberate — in-memory jq predicate, ADR 0032 decision 4
		number=$(jq -r .number <<<"$issue")
		if ((${#targets[@]} > 0)); then
			selected=false
			for target in "${targets[@]}"; do
				[[ $number == "$target" ]] && selected=true
			done
			[[ $selected == true ]] || continue
		fi
		body=$(jq -r '.body // ""' <<<"$issue")
		if [[ $mode == plan ]]; then
			if cleared_dependency_body_verdict "$repo" "$number" "$body"; then
				printf 'ready #%s\n' "$number"
			else
				printf '%s\n' "$cleared_dependency_reason" >&2
				[[ $cleared_dependency_error == true ]] && failures=1
			fi
		else
			apply_cleared_dependency "$repo" "$issue" || failures=1
		fi
	done < <(jq -c '.[]' <<<"$issues")
	return "$failures"
}

# Executed rather than sourced, this file is the command the quest-log,
# resurrection, and return-to-town recipes invoke; the dispatch makes the
# command's exit status the verdict (0 clean, 1 degraded or partial, 2 usage).
# Without the guard, executing a functions-only library was a silent no-op --
# the shape issue #199 records.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	reconcile_cleared_dependencies "$@"
fi
