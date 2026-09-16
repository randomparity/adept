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

# Seconds. 30 for a call that issues one request, 120 for one that may issue
# more; references/network-bounds.md carries the rule and ADR 0068 the record.
# `:=` rather than `=` because the behaviour suite's direct-execution leg exports
# these into a subprocess, and an unconditional assignment here would overwrite
# the exported value before any call read it.
: "${cleared_dependency_bound_single:=30}"
: "${cleared_dependency_bound_multi:=120}"

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
# The two scratch files are allocated and removed per call rather than held
# across the run by an EXIT trap: this file is sourced, so a trap installed here
# would take the slot from whichever skill sourced it. A host that cannot
# allocate one reports through the same diagnostic as a gh call that did not
# answer, which is the honest reading -- the lookup did not happen, and none of
# the four points has written anything yet. The removal is guarded because a
# caller running under `set -e` would otherwise end on a failed rm after a lookup
# that succeeded.

# Run a command under a bound. Returns the command's own status, or 124 when the
# bound was exceeded. Trap-free: this file is sourced, so it cannot take the EXIT
# trap slot from whichever skill sourced it, and the mechanism needs none.
# Transcribed from references/network-bounds.md; ADR 0068 carries the reasoning.
cleared_dependency_bounded_call() { # seconds out-file err-file command...
	# rc, not status: under zsh `status` is a read-only special parameter, and a
	# `local status=0` in a sourced body once killed a caller's whole session --
	# cleared-dependencies.sh:5-16 carries that record.
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

cleared_dependency_run() { # bound gh-args...
	local bound=$1 subcommand=$2 out err rc=0
	cleared_dependency_out=
	cleared_dependency_err=
	shift
	# Validated before it reaches $((bound * 10)): bash evaluates an arithmetic
	# operand as an expression, so a value carrying a command substitution would
	# run it. Digits alone are not enough for that destination -- bash reads 010
	# as octal 8, so a site would run under a bound nobody chose, and 08 is an
	# arithmetic error. Measured on bash 3.2.57: that error lands in the bounded
	# call's `while` condition, where `set -e` is suspended, so it does not abort
	# -- the poll is abandoned, the function returns 0 with an empty capture, and
	# the child it launched survives. The caller then reads a successful call that
	# answered nothing, which is exactly the reading this convention exists to
	# prevent, with the orphan the bound exists to reap. The length cap keeps the
	# multiplication clear of 64-bit overflow. This is the only entry point, so
	# one guard covers every call.
	case $bound in
	'' | *[!0-9]* | 0?*)
		cleared_dependency_err='the tracker command bound is not a whole number of seconds without a leading zero'
		return 1
		;;
	esac
	if [ "${#bound}" -gt 7 ]; then
		cleared_dependency_err='the tracker command bound is implausibly large'
		return 1
	fi
	out=$(mktemp) || {
		cleared_dependency_err='no scratch file for the tracker command'
		return 1
	}
	err=$(mktemp) || {
		rm -f -- "$out" ||
			printf 'retained scratch path: %s\n' "$out" >&2
		cleared_dependency_err='no scratch file for the tracker command'
		return 1
	}
	cleared_dependency_bounded_call "$bound" "$out" "$err" gh "$@" || rc=$?
	if [ "$rc" -eq 124 ]; then
		# The stdout capture is void and the stderr capture is a fragment of
		# whatever gh had written when it was signalled. An authored diagnostic
		# says what actually happened, and cannot accidentally carry the
		# 'not found' substring that the blocker read treats as an answer.
		cleared_dependency_err="gh $subcommand exceeded its ${bound}s bound and did not answer"
	else
		cleared_dependency_out=$(<"$out")
		cleared_dependency_err=$(<"$err")
	fi
	rm -f -- "$out" "$err" ||
		printf 'retained scratch paths: %s %s\n' "$out" "$err" >&2
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
	if cleared_dependency_run "$cleared_dependency_bound_single" issue view "$blocker" \
		--repo "$repo" --json state --jq .state; then
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
		if [[ $line =~ ^Blocked\ by\ \#([0-9]+)(\ —\ [^[:space:]].*)?$ ]]; then
			blockers+=("${BASH_REMATCH[1]}")
		elif [[ $line == 'Blocked by #'* ]]; then
			cleared_dependency_reason="malformed reference on #$number;"
			cleared_dependency_reason+=" expected Blocked by #N or Blocked by #N — explanation"
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
	local repo=$1 rc=0 merged safe
	cleared_dependency_run "$cleared_dependency_bound_single" label create 'status:ready' \
		--repo "$repo" --color 0e8a16 \
		--description 'triaged, eligible for work' || rc=$?
	case $rc in
	0) return 0 ;;
	124)
		# A bound does not make a write atomic. Report indeterminacy, never
		# failure, and never retry.
		printf 'creating status:ready exceeded its %ss bound; the label may or may not exist\n' \
			"$cleared_dependency_bound_single" >&2
		return 1
		;;
	esac
	# This call captures a diagnostic and discards it on success, so its streams
	# are merged after the call rather than in a 2>&1 redirect.
	merged=$cleared_dependency_out$cleared_dependency_err
	[[ $merged == *'already exists'* ]] && return 0
	safe=$(printf '%s' "$merged" | cleared_dependency_safe_text)
	printf 'cannot create status:ready: %s — grant label-write scope\n' "$safe" >&2
	return 1
}

restore_cleared_dependency_blocked() { # repo number issue-json reason
	local repo=$1 number=$2 issue=$3 reason=$4 label safe rc=0 merged
	local -a remove_args=()
	while IFS= read -r label; do
		remove_args+=(--remove-label "$label")
	done < <(jq -r '.labels[].name | select(startswith("status:"))' <<<"$issue")
	cleared_dependency_run "$cleared_dependency_bound_multi" issue edit "$number" \
		--repo "$repo" "${remove_args[@]}" --add-label 'status:blocked' || rc=$?
	case $rc in
	0) ;;
	124)
		printf 'restoring #%s to status:blocked after %s exceeded its %ss bound; its labels may or may not have been changed\n' \
			"$number" "$reason" "$cleared_dependency_bound_multi" >&2
		return 1
		;;
	*)
		merged=$cleared_dependency_out$cleared_dependency_err
		safe=$(printf '%s' "$merged" | cleared_dependency_safe_text)
		printf 'cannot restore #%s to status:blocked after %s: %s\n' \
			"$number" "$reason" "$safe" >&2
		return 1
		;;
	esac
	printf 'restored #%s to status:blocked after %s\n' "$number" "$reason" >&2
}

apply_cleared_dependency() { # repo issue-json
	local repo=$1 initial=$2 number current body final label status_labels
	local initial_snapshot current_snapshot snapshot_filter safe rc
	local -a remove_args=()
	number=$(jq -r .number <<<"$initial")
	if ! cleared_dependency_run "$cleared_dependency_bound_single" issue view "$number" \
		--repo "$repo" --json number,state,body,labels; then
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
	rc=0
	cleared_dependency_run "$cleared_dependency_bound_multi" issue edit "$number" \
		--repo "$repo" "${remove_args[@]}" --add-label 'status:ready' || rc=$?
	case $rc in
	0) ;;
	124)
		printf 'label update for #%s exceeded its %ss bound; the labels may or may not have been changed; inspect its status labels\n' \
			"$number" "$cleared_dependency_bound_multi" >&2
		return 1
		;;
	*)
		safe=$(printf '%s' "$cleared_dependency_out$cleared_dependency_err" |
			cleared_dependency_safe_text)
		printf 'label update failed for #%s: %s; inspect its status labels\n' \
			"$number" "$safe" >&2
		return 1
		;;
	esac
	if ! cleared_dependency_run "$cleared_dependency_bound_single" issue view "$number" \
		--repo "$repo" --json number,state,body,labels; then
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
	# 120 s bounds the whole paginated call rather than each request: gh exposes
	# no per-request timeout, so the effective per-page allowance shrinks as the
	# repository's open-issue count grows.
	cleared_dependency_run "$cleared_dependency_bound_multi" api --paginate --slurp -X GET \
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
