#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
	printf 'verify-push: must run inside a Git worktree\n' >&2
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
	git cat-file -e "$local_oid^{commit}" 2>/dev/null || die 'invalid branch object'
	add_object "$local_oid"
done

((${#objects[@]} <= 1)) || die 'multiple distinct branch objects'
((${#objects[@]} == 1)) || exit 0

TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/verify-push.XXXXXX") || die 'could not create cleanup path'
WORKTREE="$TEMP_ROOT/worktree"
worktree_added=0
retain_cleanup=0

cleanup() {
	local status=$? cleanup_failed=0
	if ((retain_cleanup)); then
		printf 'verify-push: retained cleanup path: %s\n' "$TEMP_ROOT" >&2
		exit "$status"
	fi
	if ((worktree_added)) && ! git -C "$ROOT" worktree remove --force "$WORKTREE"; then
		printf 'verify-push: retained cleanup path: %s\n' "$TEMP_ROOT" >&2
		cleanup_failed=1
	else
		rm -R "$TEMP_ROOT"
	fi
	if ((status != 0)); then
		exit "$status"
	fi
	((cleanup_failed == 0)) || exit 1
}
trap cleanup EXIT

if ! git -C "$ROOT" worktree add --detach "$WORKTREE" "${objects[0]}"; then
	retain_cleanup=1
	die 'could not create isolated worktree'
fi
worktree_added=1
(cd "$WORKTREE" && just ci)
