#!/usr/bin/env bash
set -euo pipefail

# `git rev-parse --show-toplevel` exits non-zero for more than "you are not in
# a worktree": dubious ownership under a bind mount or a container UID
# mismatch, an unreadable or damaged .git, an unreadable parent directory. The
# old diagnostic asserted the first of those and discarded git's own line,
# which for dubious ownership carries the exact safe.directory remedy -- and
# this runs from a pre-push hook, so that line is the only one the operator
# would ever see. Report what was established instead: the command and the
# status it returned.
root_status=0
ROOT=$(git rev-parse --show-toplevel) || root_status=$?
if [ "$root_status" -ne 0 ]; then
	printf 'verify-push: could not resolve the worktree root (git rev-parse --show-toplevel exit %s)\n' \
		"$root_status" >&2
	exit 2
fi
# Empty output at exit 0 gets the same treatment the local-env-vars read gets
# below, and matters more here: `git -C ""` is a no-op that resolves in the
# current directory, so an empty ROOT would send every command below -- two of
# them mutating, `worktree add` and `worktree remove` -- at whatever repository
# the ambient cwd and GIT_DIR select. No real `git rev-parse --show-toplevel`
# was found to answer this way (a bare repository, a run inside .git, and an
# empty GIT_WORK_TREE all exit 128), so this guards a substituted or future git
# rather than a demonstrated path.
[ -n "$ROOT" ] || {
	printf 'verify-push: git reported no worktree root\n' >&2
	exit 2
}

# Hooks export selectors for their source worktree. Root discovery above needs
# those values; every later command must resolve inside the detached worktree.
#
# Captured rather than read from a process substitution, which reports the
# loop's status and never rev-parse's: a rev-parse that could not answer leaves
# the loop reading nothing, nothing unset, and every command below resolving
# against the hook's repository instead of this one -- a scan that could not run
# read as one that found nothing (ADR 0005). clear_git_env in
# scripts/test-fixture-helpers.sh is the same fix at the same call.
local_env_vars=$(git -C "$ROOT" rev-parse --local-env-vars) || {
	printf 'verify-push: cannot read git local env vars\n' >&2
	exit 2
}
# Empty output is the same failure wearing a zero exit status: git has always
# named at least GIT_DIR here, so nothing to clear means the answer did not
# arrive rather than that there was nothing to do.
[ -n "$local_env_vars" ] || {
	printf 'verify-push: git reported no local env vars\n' >&2
	exit 2
}
while IFS= read -r variable; do
	[ -n "$variable" ] || continue
	unset "$variable"
done <<<"$local_env_vars"
ZERO_OID=$(git -C "$ROOT" hash-object --stdin </dev/null)
ZERO_OID=${ZERO_OID//[0123456789abcdef]/0}

die() {
	printf 'verify-push: %s\n' "$1" >&2
	exit 1
}

add_object() {
	local candidate=$1 object
	for object in "${objects[@]:-}"; do
		[[ $object == "$candidate" ]] && return
	done
	objects+=("$candidate")
}

objects=()
while IFS=' ' read -r local_ref local_oid remote_ref remote_oid extra; do
	[[ -n ${local_ref:-} && -n ${local_oid:-} && -n ${remote_ref:-} && -n ${remote_oid:-} &&
		-n ${extra:-} ]] && die 'malformed ref update'
	[[ -n ${local_ref:-} && -n ${local_oid:-} && -n ${remote_ref:-} && -n ${remote_oid:-} ]] ||
		die 'malformed ref update'
	[[ $remote_ref == refs/heads/* ]] || continue
	if [[ $local_ref == '(delete)' ]]; then
		[[ $local_oid == "$ZERO_OID" ]] || die 'invalid branch deletion object'
		continue
	fi
	# ADR 0005 decision 2 rules `git cat-file -e` inadmissible as a witness,
	# and this was the last site still using it as one. It exits 128 for an oid
	# this repository does not have, for an oid that is not a commit, for a
	# GIT_DIR pointing at nothing, and for an object store it could not read;
	# `2>/dev/null` then discarded the only line separating those, leaving the
	# operator a cause -- "invalid branch object" -- the script had not
	# established.
	#
	# `git rev-parse --verify` alone does not fix that: it too exits 128 in all
	# four cases. `--quiet` is what makes it admissible, because it demotes the
	# verify failure to exit 1 and leaves 128 for the errors that stop git
	# before it can open the repository at all. So 1 is a verdict about the
	# push and 2 reports a check that could not run, matching the worktree-root
	# probe above. `dir_in_ref` in the record gate witnesses a ref the same way.
	#
	# Only 0 passes, so the one documented part of that contract -- "exit with
	# non-zero status silently" -- carries the whole guard; a git that answered
	# a bad revision with some status other than 1 would be reported as a check
	# that could not run rather than let a push through. stderr stays open
	# either way: at 128 git's own fatal line is the only clue an operator
	# gets, and this runs from a pre-push hook.
	object_status=0
	git rev-parse --verify --quiet "$local_oid^{commit}" >/dev/null || object_status=$?
	case $object_status in
	0) ;;
	1) die "branch object is not a commit in this repository: $local_oid" ;;
	*)
		printf 'verify-push: could not verify the branch object %s (git rev-parse --verify exit %s)\n' \
			"$local_oid" "$object_status" >&2
		exit 2
		;;
	esac
	add_object "$local_oid"
done

((${#objects[@]} <= 1)) || die 'multiple distinct branch objects'
((${#objects[@]} == 1)) || exit 0

TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/verify-push.XXXXXX") || die 'could not create cleanup path'
WORKTREE="$TEMP_ROOT/worktree"
worktree_added=0
retain_cleanup=0

cleanup() {
	local status=$? cleanup_failed=0 final_status
	if ((retain_cleanup)); then
		printf 'verify-push: retained cleanup path: %s\n' "$TEMP_ROOT" >&2 || :
		exit "$status"
	fi
	if ((worktree_added)) && ! git -C "$ROOT" worktree remove --force "$WORKTREE"; then
		cleanup_failed=1
	elif ! rm -R "$TEMP_ROOT"; then
		cleanup_failed=1
	fi
	final_status=$status
	if ((status == 0 && cleanup_failed)); then
		final_status=2
	fi
	if ((cleanup_failed)); then
		printf 'verify-push: retained cleanup path: %s\n' "$TEMP_ROOT" >&2 || :
	fi
	exit "$final_status"
}
trap cleanup EXIT

if ! git -C "$ROOT" worktree add --detach "$WORKTREE" "${objects[0]}"; then
	retain_cleanup=1
	die 'could not create isolated worktree'
fi
worktree_added=1
(cd "$WORKTREE" && just ci)
