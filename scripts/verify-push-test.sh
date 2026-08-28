#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/test-fixture-helpers.sh
. "$script_dir/test-fixture-helpers.sh"

# Hooks export repository-local selectors that override every fixture's `git -C`.
# Clear Git's reported set before this suite creates or inspects a disposable repository.
clear_git_env
fixture_init verify-push-test

ROOT=$(cd "$script_dir/.." && pwd)
VERIFIER="$ROOT/scripts/verify-push.sh"
REPO="$SCRATCH/repo"
BIN="$SCRATCH/bin"
LOG="$SCRATCH/just.log"
JUST_REAL=$(command -v just)

assert_hook_env_isolation() {
	local hook_repo hook_index child_status
	hook_repo="$SCRATCH/hook-repository"
	mkdir -p "$hook_repo"
	git -C "$hook_repo" init --quiet
	git -C "$hook_repo" config user.email hook@example.test
	git -C "$hook_repo" config user.name Hook
	printf 'hook\n' >"$hook_repo/README.md"
	git -C "$hook_repo" add README.md
	git -C "$hook_repo" commit --quiet -m hook
	hook_index="$(git -C "$hook_repo" rev-parse --absolute-git-dir)/index"
	git -C "$hook_repo" ls-files --stage >"$SCRATCH/hook-index-before"
	set +e
	GIT_DIR="$(git -C "$hook_repo" rev-parse --absolute-git-dir)" \
	GIT_COMMON_DIR="$(git -C "$hook_repo" rev-parse --git-common-dir)" \
	GIT_WORK_TREE="$hook_repo" \
	GIT_INDEX_FILE="$hook_index" \
	GIT_CONFIG="$(git -C "$hook_repo" rev-parse --git-path config)" \
	VERIFY_PUSH_TEST_HOOK_CHILD=1 "$0" >"$SCRATCH/hook-output" 2>&1
	child_status=$?
	set -e
	if [[ $child_status -ne 0 ]]; then
		printf 'not ok - verifier fixture should run under hook-local Git state\n' >&2
		sed -n '1,80p' "$SCRATCH/hook-output" >&2
		exit 1
	fi
	git -C "$hook_repo" ls-files --stage >"$SCRATCH/hook-index-after"
	if ! cmp -s "$SCRATCH/hook-index-before" "$SCRATCH/hook-index-after"; then
		printf 'not ok - verifier fixture changed hook-local index\n' >&2
		diff -u "$SCRATCH/hook-index-before" "$SCRATCH/hook-index-after" >&2 || :
		exit 1
	fi
}

if [[ ${VERIFY_PUSH_TEST_HOOK_CHILD:-} != 1 ]]; then
	assert_hook_env_isolation
fi

new_repo() {
	rm -R "$REPO" 2>/dev/null || :
	mkdir -p "$REPO"
	git -C "$REPO" init --quiet -b main
	git -C "$REPO" config user.email push@example.test
	git -C "$REPO" config user.name Push
	printf 'immutable\n' >"$REPO/marker"
	git -C "$REPO" add marker
	git -C "$REPO" commit --quiet -m base
	OBJECT=$(git -C "$REPO" rev-parse HEAD)
	: >"$LOG"
}

run_verifier() {
	local input=$1
	printf '%b' "$input" | (
		cd "$REPO"
		PATH="$BIN:$PATH" JUST_LOG="$LOG" SOURCE_REPO="$REPO" "$VERIFIER"
	)
}

run_verifier_with_git() {
	local input=$1 git_bin=$2
	printf '%b' "$input" | (
		cd "$REPO"
		PATH="$git_bin:$BIN:$PATH" JUST_LOG="$LOG" SOURCE_REPO="$REPO" "$VERIFIER"
	)
}

run_verifier_with_hook_env() {
	local input=$1 git_dir index config
	git_dir=$(git -C "$REPO" rev-parse --absolute-git-dir)
	index="$git_dir/index"
	config=$(git -C "$REPO" rev-parse --git-path config)
	printf '%b' "$input" | (
		cd "$REPO"
		GIT_DIR="$git_dir" GIT_COMMON_DIR="$git_dir" GIT_WORK_TREE="$REPO" \
			GIT_INDEX_FILE="$index" GIT_CONFIG="$config" PATH="$BIN:$PATH" \
			JUST_LOG="$LOG" SOURCE_REPO="$REPO" "$VERIFIER"
	)
}

assert_no_ci() {
	[[ ! -s $LOG ]] || fail "$1 invoked ci"
}

assert_fails() {
	local name=$1 input=$2 expected=$3 status=0 output
	output=$(run_verifier "$input" 2>&1) || status=$?
	[[ $status -ne 0 ]] || fail "$name unexpectedly passed"
	[[ $output == *"$expected"* ]] || fail "$name missing diagnostic: $output"
	assert_no_ci "$name"
}

mkdir -p "$BIN"
cat >"$BIN/just" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == ci ]] || exit 91
printf '%s\t%s\t%s\n' "$PWD" "$(git rev-parse HEAD)" "$(cat marker)" >>"$JUST_LOG"
[[ ${FAIL_CI:-0} == 1 ]] && exit 73
printf 'source mutation\n' >"$SOURCE_REPO/marker"
EOF
chmod +x "$BIN/just"

new_repo
run_verifier "refs/heads/main $OBJECT refs/heads/main 0000000000000000000000000000000000000000\n"
[[ $(wc -l <"$LOG" | tr -d ' ') == 1 ]] || fail 'one branch object should invoke ci once'
IFS=$'\t' read -r ci_root ci_object ci_marker <"$LOG"
SOURCE_ROOT=$(cd "$REPO" && pwd -P)
[[ $ci_root != "$SOURCE_ROOT" && $ci_object == "$OBJECT" && $ci_marker == immutable ]] ||
	fail 'ci should run from the immutable detached worktree'
[[ $(cat "$REPO/marker") == 'source mutation' ]] || fail 'fake ci should mutate source worktree'

new_repo
printf 'source head\n' >"$REPO/marker"
git -C "$REPO" add marker
git -C "$REPO" commit --quiet -m source-head
run_verifier_with_hook_env \
	"refs/heads/main $OBJECT refs/heads/main 0000000000000000000000000000000000000000\n"
IFS=$'\t' read -r ci_root ci_object ci_marker <"$LOG"
[[ $ci_object == "$OBJECT" && $ci_marker == immutable ]] ||
	fail 'hook-local Git selectors should not escape the detached worktree'

new_repo
run_verifier "refs/heads/main $OBJECT refs/heads/one 0000000000000000000000000000000000000000\nrefs/heads/main $OBJECT refs/heads/two 0000000000000000000000000000000000000000\n"
[[ $(wc -l <"$LOG" | tr -d ' ') == 1 ]] || fail 'same object refs should invoke ci once'

new_repo
run_verifier "(delete) 0000000000000000000000000000000000000000 refs/heads/main $OBJECT\n"
assert_no_ci 'branch deletion'

SHA256_REPO="$SCRATCH/sha256"
if git init --quiet --object-format=sha256 "$SHA256_REPO" 2>/dev/null; then
	git -C "$SHA256_REPO" config user.email push@example.test
	git -C "$SHA256_REPO" config user.name Push
	printf 'sha256\n' >"$SHA256_REPO/marker"
	git -C "$SHA256_REPO" add marker
	git -C "$SHA256_REPO" commit --quiet -m sha256
	SHA256_OBJECT=$(git -C "$SHA256_REPO" rev-parse HEAD)
	SHA256_ZERO=$(printf '%064d' 0)
	: >"$LOG"
	printf '(delete) %s refs/heads/main %s\n' "$SHA256_ZERO" "$SHA256_OBJECT" | (
		cd "$SHA256_REPO"
		PATH="$BIN:$PATH" JUST_LOG="$LOG" SOURCE_REPO="$SHA256_REPO" "$VERIFIER"
	)
	assert_no_ci 'SHA-256 branch deletion'
else
	printf 'note: Git lacks SHA-256 repository support; skipped deletion regression\n'
fi

new_repo
run_verifier "refs/tags/v1 $OBJECT refs/tags/v1 0000000000000000000000000000000000000000\n"
assert_no_ci 'non-branch ref'

new_repo
assert_fails 'malformed input' 'only three fields\n' 'malformed ref update'
# The two causes the object witness may legitimately reject a push for. Both
# reach `git rev-parse --verify --quiet` at exit 1 -- the status that says git
# answered and the answer was no -- and must be told apart from the exit 2 the
# stubbed-fault case below asserts.
assert_fails 'absent object' \
	'refs/heads/main deadbeef refs/heads/main 0000000000000000000000000000000000000000\n' \
	'branch object is not a commit in this repository'
BLOB=$(git -C "$REPO" rev-parse HEAD:marker)
assert_fails 'non-commit object' \
	"refs/heads/main $BLOB refs/heads/main 0000000000000000000000000000000000000000\n" \
	'branch object is not a commit in this repository'

new_repo
printf 'second\n' >"$REPO/marker"
git -C "$REPO" add marker
git -C "$REPO" commit --quiet -m second
SECOND=$(git -C "$REPO" rev-parse HEAD)
assert_fails 'multiple branch objects' \
	"refs/heads/main $OBJECT refs/heads/main 0000000000000000000000000000000000000000\nrefs/heads/main $SECOND refs/heads/next 0000000000000000000000000000000000000000\n" \
	'multiple distinct branch objects'

GIT_REAL=$(command -v git)
FAIL_BIN="$SCRATCH/failing-git"
mkdir -p "$FAIL_BIN"
cat >"$FAIL_BIN/git" <<EOF
#!/usr/bin/env bash
if [[ \${1:-} == -C && \${3:-} == worktree && \${4:-} == add ]]; then
  exit 74
fi
exec "$GIT_REAL" "\$@"
EOF
chmod +x "$FAIL_BIN/git"
new_repo
set +e
setup_output=$(run_verifier_with_git \
	"refs/heads/main $OBJECT refs/heads/main 0000000000000000000000000000000000000000\\n" "$FAIL_BIN" 2>&1)
setup_status=$?
set -e
[[ $setup_status -ne 0 && $setup_output == *'retained cleanup path'* ]] ||
	fail 'worktree setup failure should retain and report cleanup path'

cat >"$FAIL_BIN/git" <<EOF
#!/usr/bin/env bash
if [[ \${1:-} == -C && \${3:-} == worktree && \${4:-} == remove ]]; then
  exit 75
fi
exec "$GIT_REAL" "\$@"
EOF
chmod +x "$FAIL_BIN/git"
new_repo
set +e
cleanup_output=$(run_verifier_with_git \
	"refs/heads/main $OBJECT refs/heads/main 0000000000000000000000000000000000000000\\n" "$FAIL_BIN" 2>&1)
cleanup_status=$?
set -e
[[ $cleanup_status -eq 2 && $cleanup_output == *'retained cleanup path'* ]] ||
	fail 'worktree cleanup failure should retain and report cleanup path'

new_repo
set +e
export FAIL_CI=1
failure_output=$(run_verifier_with_git \
	"refs/heads/main $OBJECT refs/heads/main 0000000000000000000000000000000000000000\\n" "$FAIL_BIN" 2>&1)
failure_status=$?
unset FAIL_CI
set -e
[[ $failure_status == 73 && $failure_output == *'retained cleanup path'* ]] ||
	fail 'cleanup failure should preserve the ci failure status'

RM_FAIL_BIN=$SCRATCH/failing-rm
mkdir -p "$RM_FAIL_BIN"
printf '#!/usr/bin/env bash\nexit 1\n' >"$RM_FAIL_BIN/rm"
chmod +x "$RM_FAIL_BIN/rm"

run_verifier_with_rm() {
	local input=$1
	printf '%b' "$input" | (
		cd "$REPO"
		PATH="$RM_FAIL_BIN:$BIN:$PATH" TMPDIR="$SCRATCH" JUST_LOG="$LOG" \
			SOURCE_REPO="$REPO" "$VERIFIER"
	)
}

new_repo
rm_cleanup_status=0
rm_cleanup_output=$(run_verifier_with_rm \
	"refs/heads/main $OBJECT refs/heads/main 0000000000000000000000000000000000000000\n" \
	2>&1) || rm_cleanup_status=$?
[[ $rm_cleanup_status -eq 2 &&
	$rm_cleanup_output == *"verify-push: retained cleanup path: $SCRATCH/verify-push."* ]] ||
	fail "scratch removal failure should exit 2 and name its path: $rm_cleanup_output"

new_repo
export FAIL_CI=1
rm_failure_status=0
rm_failure_output=$(run_verifier_with_rm \
	"refs/heads/main $OBJECT refs/heads/main 0000000000000000000000000000000000000000\n" \
	2>&1) || rm_failure_status=$?
unset FAIL_CI
[[ $rm_failure_status -eq 73 &&
	$rm_failure_output == *"verify-push: retained cleanup path: $SCRATCH/verify-push."* ]] ||
	fail "scratch removal failure should preserve CI exit 73: $rm_failure_output"

# A failed retained-path diagnostic must not become the cleanup verdict. Closed
# stderr constructs that path without depending on platform-specific I/O faults.
new_repo
rm_closed_status=0
run_verifier_with_rm \
	"refs/heads/main $OBJECT refs/heads/main 0000000000000000000000000000000000000000\n" \
	2>&- || rm_closed_status=$?
[[ $rm_closed_status -eq 2 ]] ||
	fail "closed cleanup diagnostic should keep exit 2, got $rm_closed_status"

new_repo
export FAIL_CI=1
rm_closed_failure_status=0
run_verifier_with_rm \
	"refs/heads/main $OBJECT refs/heads/main 0000000000000000000000000000000000000000\n" \
	2>&- || rm_closed_failure_status=$?
unset FAIL_CI
[[ $rm_closed_failure_status -eq 73 ]] ||
	fail "closed cleanup diagnostic should preserve CI exit 73, got $rm_closed_failure_status"

# The verifier clears Git's repository-local selectors before it resolves
# anything inside the detached worktree. Read through a process substitution
# that loop reported its own status and never rev-parse's, so a rev-parse that
# could not answer left nothing unset and every later command resolving against
# the hook's repository instead of this one. Both shapes of that failure -- a
# non-zero status, and the same silence wearing a zero one -- must stop the run
# before ci is reached.
cat >"$FAIL_BIN/git" <<EOF
#!/usr/bin/env bash
if [[ \${1:-} == -C && \${3:-} == rev-parse && \${4:-} == --local-env-vars ]]; then
  printf 'stub git: cannot report the local env vars\n' >&2
  exit 128
fi
exec "$GIT_REAL" "\$@"
EOF
chmod +x "$FAIL_BIN/git"
new_repo
set +e
env_fault_output=$(run_verifier_with_git \
	"refs/heads/main $OBJECT refs/heads/main 0000000000000000000000000000000000000000\\n" "$FAIL_BIN" 2>&1)
env_fault_status=$?
set -e
[[ $env_fault_status -eq 2 && $env_fault_output == *'cannot read git local env vars'* ]] ||
	fail "unreadable local env vars should stop the run: $env_fault_output"
assert_no_ci 'unreadable local env vars'

cat >"$FAIL_BIN/git" <<EOF
#!/usr/bin/env bash
if [[ \${1:-} == -C && \${3:-} == rev-parse && \${4:-} == --local-env-vars ]]; then
  exit 0
fi
exec "$GIT_REAL" "\$@"
EOF
chmod +x "$FAIL_BIN/git"
new_repo
set +e
env_empty_output=$(run_verifier_with_git \
	"refs/heads/main $OBJECT refs/heads/main 0000000000000000000000000000000000000000\\n" "$FAIL_BIN" 2>&1)
env_empty_status=$?
set -e
[[ $env_empty_status -eq 2 && $env_empty_output == *'reported no local env vars'* ]] ||
	fail "an empty local env var list should stop the run: $env_empty_output"
assert_no_ci 'empty local env vars'

# The worktree-root probe is the sibling read in the same file and gets the same
# two cases. A non-zero status must carry git's own line through rather than
# assert a cause the script did not establish, and empty output at exit 0 must
# stop the run rather than let `git -C ""` resolve against the ambient
# repository.
cat >"$FAIL_BIN/git" <<EOF
#!/usr/bin/env bash
if [[ \${1:-} == rev-parse && \${2:-} == --show-toplevel ]]; then
  printf 'stub git: cannot resolve the worktree root\n' >&2
  exit 128
fi
exec "$GIT_REAL" "\$@"
EOF
chmod +x "$FAIL_BIN/git"
new_repo
set +e
root_fault_output=$(run_verifier_with_git \
	"refs/heads/main $OBJECT refs/heads/main 0000000000000000000000000000000000000000\\n" "$FAIL_BIN" 2>&1)
root_fault_status=$?
set -e
[[ $root_fault_status -eq 2 && $root_fault_output == *'could not resolve the worktree root'* &&
	$root_fault_output == *'stub git: cannot resolve the worktree root'* ]] ||
	fail "an unresolvable worktree root should stop the run and keep git's line: $root_fault_output"
assert_no_ci 'unresolvable worktree root'

cat >"$FAIL_BIN/git" <<EOF
#!/usr/bin/env bash
if [[ \${1:-} == rev-parse && \${2:-} == --show-toplevel ]]; then
  exit 0
fi
exec "$GIT_REAL" "\$@"
EOF
chmod +x "$FAIL_BIN/git"
new_repo
set +e
root_empty_output=$(run_verifier_with_git \
	"refs/heads/main $OBJECT refs/heads/main 0000000000000000000000000000000000000000\\n" "$FAIL_BIN" 2>&1)
root_empty_status=$?
set -e
[[ $root_empty_status -eq 2 && $root_empty_output == *'reported no worktree root'* ]] ||
	fail "an empty worktree root should stop the run: $root_empty_output"
assert_no_ci 'empty worktree root'

# The branch-object witness is the third read in this file that must separate a
# push it rejected from a check it could not run. `git cat-file -e` could not:
# it exits 128 for an absent oid, a non-commit oid, a GIT_DIR pointing at
# nothing and an unreadable object store alike, so a repository git could not
# read was reported as a bad push. Under `git rev-parse --verify --quiet` a
# witness that could not answer exits 128, and the verifier must report that as
# a check that could not run -- exit 2, naming the command and its status --
# and keep git's own line, which is all the operator gets from a pre-push hook.
cat >"$FAIL_BIN/git" <<EOF
#!/usr/bin/env bash
if [[ \${1:-} == rev-parse && \${2:-} == --verify ]]; then
  printf 'stub git: not a git repository\n' >&2
  exit 128
fi
exec "$GIT_REAL" "\$@"
EOF
chmod +x "$FAIL_BIN/git"
new_repo
set +e
object_fault_output=$(run_verifier_with_git \
	"refs/heads/main $OBJECT refs/heads/main 0000000000000000000000000000000000000000\\n" "$FAIL_BIN" 2>&1)
object_fault_status=$?
set -e
[[ $object_fault_status -eq 2 &&
	$object_fault_output == *"could not verify the branch object $OBJECT"* &&
	$object_fault_output == *'git rev-parse --verify exit 128'* &&
	$object_fault_output == *'stub git: not a git repository'* ]] ||
	fail "an unverifiable branch object should stop the run and keep git's line: $object_fault_output"
assert_no_ci 'unverifiable branch object'

HOOK_REPO="$SCRATCH/hook-repo"
HOOK_BIN="$SCRATCH/hook-bin"
mkdir -p "$HOOK_BIN"
cat >"$HOOK_BIN/prek" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$HOOK_BIN/prek"

new_hook_repo() {
	rm -R "$HOOK_REPO" 2>/dev/null || :
	mkdir -p "$HOOK_REPO/scripts"
	cp "$ROOT/scripts/pre-push-hook" "$HOOK_REPO/scripts/pre-push-hook"
	cp "$ROOT/scripts/verify-push.sh" "$HOOK_REPO/scripts/verify-push.sh"
	git -C "$HOOK_REPO" init --quiet -b main
	git -C "$HOOK_REPO" config user.email push@example.test
	git -C "$HOOK_REPO" config user.name Push
	git -C "$HOOK_REPO" add scripts
	git -C "$HOOK_REPO" commit --quiet -m hook
}

run_hooks() {
	(
		cd "$HOOK_REPO"
		PATH="$HOOK_BIN:$PATH" "$JUST_REAL" --working-directory "$HOOK_REPO" --justfile "$ROOT/Justfile" hooks
	)
}

run_hooks_with_ripgrep_config() {
	local config=$1
	(
		cd "$HOOK_REPO"
		PATH="$HOOK_BIN:$PATH" RIPGREP_CONFIG_PATH="$config" \
			"$JUST_REAL" --working-directory "$HOOK_REPO" --justfile "$ROOT/Justfile" hooks
	)
}

hook_path() {
	git -C "$HOOK_REPO" rev-parse --path-format=absolute --git-path hooks/pre-push
}

new_hook_repo
run_hooks
HOOK_PATH=$(hook_path)
cmp -s "$ROOT/scripts/pre-push-hook" "$HOOK_PATH" || fail 'missing hook install'
HOOK_INPUT="$SCRATCH/hook-input"
cat >"$HOOK_BIN/just" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$HOOK_JUST_ARGS"
cat >"$HOOK_JUST_INPUT"
EOF
chmod +x "$HOOK_BIN/just"
printf 'local object refs/heads/main remote object\n' | (
	cd "$HOOK_REPO"
	PATH="$HOOK_BIN:$PATH" HOOK_JUST_ARGS="$SCRATCH/hook-args" \
		HOOK_JUST_INPUT="$HOOK_INPUT" "$HOOK_PATH"
)
[[ $(cat "$SCRATCH/hook-args") == push-check ]] || fail 'hook should invoke push-check'
[[ $(cat "$HOOK_INPUT") == 'local object refs/heads/main remote object' ]] ||
	fail 'hook should preserve standard input'

HOOK_OBJECT=$(git -C "$HOOK_REPO" rev-parse HEAD)
cat >"$HOOK_BIN/just" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case ${1:-} in
push-check) exec "$PWD/scripts/verify-push.sh" ;;
ci) printf '%s\t%s\n' "$PWD" "$(git rev-parse HEAD)" >>"$HOOK_CI_LOG" ;;
*) exit 91 ;;
esac
EOF
chmod +x "$HOOK_BIN/just"
: >"$SCRATCH/hook-ci.log"
printf 'refs/heads/main %s refs/heads/one %s\nrefs/heads/main %s refs/heads/two %s\n' \
	"$HOOK_OBJECT" "$HOOK_OBJECT" "$HOOK_OBJECT" "$HOOK_OBJECT" | (
	cd "$HOOK_REPO"
	PATH="$HOOK_BIN:$PATH" HOOK_CI_LOG="$SCRATCH/hook-ci.log" "$HOOK_PATH"
)
[[ $(wc -l <"$SCRATCH/hook-ci.log" | tr -d ' ') == 1 ]] ||
	fail 'native pre-push should reach ci once for one object'
IFS=$'\t' read -r hook_ci_root hook_ci_object <"$SCRATCH/hook-ci.log"
HOOK_SOURCE_ROOT=$(cd "$HOOK_REPO" && pwd -P)
[[ $hook_ci_root != "$HOOK_SOURCE_ROOT" && $hook_ci_object == "$HOOK_OBJECT" ]] ||
	fail 'native pre-push should verify the isolated pushed object'

# The hook resolves the worktree root before anything else can report, so its
# diagnostic is the only one an operator sees. A non-zero rev-parse must carry
# git's own line through -- for dubious ownership that line holds the
# safe.directory remedy -- rather than assert a "not in a worktree" cause the
# hook did not establish.
HOOK_FAIL_BIN="$SCRATCH/hook-failing-git"
mkdir -p "$HOOK_FAIL_BIN"
cat >"$HOOK_FAIL_BIN/git" <<EOF
#!/usr/bin/env bash
if [[ \${1:-} == rev-parse && \${2:-} == --show-toplevel ]]; then
  printf 'stub git: detected dubious ownership in repository\n' >&2
  exit 128
fi
exec "$GIT_REAL" "\$@"
EOF
chmod +x "$HOOK_FAIL_BIN/git"
: >"$SCRATCH/hook-ci.log"
set +e
hook_root_output=$(printf 'refs/heads/main %s refs/heads/main %s\n' "$HOOK_OBJECT" "$HOOK_OBJECT" | (
	cd "$HOOK_REPO"
	PATH="$HOOK_FAIL_BIN:$HOOK_BIN:$PATH" HOOK_CI_LOG="$SCRATCH/hook-ci.log" "$HOOK_PATH"
) 2>&1)
hook_root_status=$?
set -e
[[ $hook_root_status -eq 2 && $hook_root_output == *'could not resolve the worktree root'* &&
	$hook_root_output == *'stub git: detected dubious ownership in repository'* ]] ||
	fail "an unresolvable worktree root should stop the hook and keep git's line: $hook_root_output"
[[ ! -s $SCRATCH/hook-ci.log ]] || fail 'unresolvable worktree root reached ci'

printf '%s\nold\n' '# adept: managed pre-push hook' >"$HOOK_PATH"
run_hooks
cmp -s "$ROOT/scripts/pre-push-hook" "$HOOK_PATH" || fail 'owned hook was not replaced'

printf 'foreign hook\n' >"$HOOK_PATH"
cp "$HOOK_PATH" "$SCRATCH/foreign-hook-before"
set +e
foreign_output=$(run_hooks 2>&1)
foreign_status=$?
set -e
[[ $foreign_status -ne 0 && $foreign_output == *'foreign pre-push hook'* ]] ||
	fail 'foreign hook should block installation'
cmp -s "$SCRATCH/foreign-hook-before" "$HOOK_PATH" || fail 'foreign hook changed'

# Pins Justfile:19's `--no-config` on the `rg` call that decides foreign-hook
# refusal. Without it, `RIPGREP_CONFIG_PATH` applies its contents as arguments
# ahead of the call's own flags, and `--invert-match` there flips the marker
# check: a foreign hook (no marker line) now reads as a match, the refusal
# never fires, and the recipe overwrites a hand-written hook. This test does
# not touch the developer's real hook directory or ripgrep config -- both the
# hostile config file and the hook destination live under $SCRATCH.
HOSTILE_RIPGREP_CONFIG="$SCRATCH/hostile-ripgreprc"
printf -- '--invert-match\n' >"$HOSTILE_RIPGREP_CONFIG"
cp "$HOOK_PATH" "$SCRATCH/foreign-hook-hostile-before"
set +e
hostile_output=$(run_hooks_with_ripgrep_config "$HOSTILE_RIPGREP_CONFIG" 2>&1)
hostile_status=$?
set -e
[[ $hostile_status -ne 0 && $hostile_output == *'foreign pre-push hook'* ]] ||
	fail 'foreign hook should block installation under a hostile RIPGREP_CONFIG_PATH'
cmp -s "$SCRATCH/foreign-hook-hostile-before" "$HOOK_PATH" ||
	fail 'foreign hook changed under a hostile RIPGREP_CONFIG_PATH'

rm -f "$HOOK_PATH"
ln -s target "$HOOK_PATH"
set +e
symlink_output=$(run_hooks 2>&1)
symlink_status=$?
set -e
[[ $symlink_status -ne 0 && $symlink_output == *'unsafe pre-push destination'* ]] ||
	fail 'symlink hook should block installation'
rm "$HOOK_PATH"
mkdir "$HOOK_PATH"
set +e
directory_output=$(run_hooks 2>&1)
directory_status=$?
set -e
[[ $directory_status -ne 0 && $directory_output == *'unsafe pre-push destination'* ]] ||
	fail 'directory hook should block installation'

new_hook_repo
CUSTOM_HOOKS="$SCRATCH/custom-hooks"
git -C "$HOOK_REPO" config core.hooksPath "$CUSTOM_HOOKS"
run_hooks
cmp -s "$ROOT/scripts/pre-push-hook" "$CUSTOM_HOOKS/pre-push" ||
	fail 'core.hooksPath hook install failed'

new_hook_repo
cat >"$HOOK_BIN/mv" <<'EOF'
#!/usr/bin/env bash
exit 77
EOF
chmod +x "$HOOK_BIN/mv"
set +e
run_hooks >/dev/null 2>&1
temporary_status=$?
set -e
rm "$HOOK_BIN/mv"
[[ $temporary_status -ne 0 ]] || fail 'interrupted hook replacement should fail'
HOOK_DIR=$(git -C "$HOOK_REPO" rev-parse --path-format=absolute --git-path hooks)
if compgen -G "$HOOK_DIR/.pre-push.*" >/dev/null; then
	fail 'interrupted hook replacement left a temporary file'
fi

printf 'verify-push-test: ok\n'
