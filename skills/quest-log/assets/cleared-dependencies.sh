#!/usr/bin/env bash

cleared_dependency_reason=
cleared_dependency_error=false
cleared_dependency_max_lookups=500
cleared_dependency_lookup_count=0
cleared_dependency_blocker_ids=()
cleared_dependency_blocker_states=()
cleared_dependency_state=

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
	if ! state=$(gh issue view "$blocker" --repo "$repo" --json state --jq .state \
		2>&1); then
		safe=$(printf '%s' "$state" | cleared_dependency_safe_text)
		if [[ $state == *'not found'* || $state == *'Could not resolve'* ]]; then
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
	if ! current=$(gh issue view "$number" --repo "$repo" \
		--json number,state,body,labels 2>&1); then
		safe=$(printf '%s' "$current" | cleared_dependency_safe_text)
		printf 'unreadable dependent #%s: %s; kept blocked\n' "$number" "$safe" >&2
		return 1
	fi
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
	if ! final=$(gh issue view "$number" --repo "$repo" \
		--json number,state,body,labels 2>&1); then
		safe=$(printf '%s' "$final" | cleared_dependency_safe_text)
		printf 'verification unreadable for #%s: %s; inspect its status labels\n' \
			"$number" "$safe" >&2
		return 1
	fi
	if ! status_labels=$(jq -c \
		'[.labels[].name | select(startswith("status:"))]' <<<"$final" 2>&1); then
		safe=$(printf '%s' "$status_labels" | cleared_dependency_safe_text)
		printf 'verification unreadable for #%s: %s; inspect its status labels\n' \
			"$number" "$safe" >&2
		return 1
	fi
	if [[ $status_labels != '["status:ready"]' ]]; then
		restore_cleared_dependency_blocked "$repo" "$number" "$final" \
			'a conflicting status write' || :
		return 1
	fi
	if ! jq -e '(.state | ascii_upcase) == "OPEN" and
    (all(.labels[].name; . != "epic"))' >/dev/null <<<"$final"; then
		restore_cleared_dependency_blocked "$repo" "$number" "$final" \
			'post-write state changed' || :
		return 1
	fi
	clear_cleared_dependency_results
	body=$(jq -r '.body // ""' <<<"$final")
	if ! cleared_dependency_body_verdict "$repo" "$number" "$body"; then
		restore_cleared_dependency_blocked "$repo" "$number" "$final" \
			"$cleared_dependency_reason" || :
		return 1
	fi
	printf 'readied #%s\n' "$number"
}

reconcile_cleared_dependencies() { # plan|apply owner/name
	local mode=$1 repo=$2 pages issues issue number body target selected failures=0
	local -a targets=()
	shift 2
	targets=("$@")
	reset_cleared_dependency_cache
	[[ $mode == plan || $mode == apply ]] || {
		printf 'usage: reconcile_cleared_dependencies plan|apply owner/name\n' >&2
		return 2
	}
	pages=$(gh api --paginate --slurp -X GET \
		"repos/$repo/issues?state=open&per_page=100" 2>&1) || {
		pages=$(printf '%s' "$pages" | cleared_dependency_safe_text)
		printf 'cannot list open dependents: %s; no labels changed\n' "$pages" >&2
		return 1
	}
	if ! issues=$(jq -ce '[.[][] | select(has("pull_request") | not)]' \
		<<<"$pages" 2>&1); then
		issues=$(printf '%s' "$issues" | cleared_dependency_safe_text)
		printf 'cannot parse open dependents: %s; no labels changed\n' "$issues" >&2
		return 1
	fi
	while IFS= read -r issue; do
		cleared_dependency_candidate "$issue" || continue
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
