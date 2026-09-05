# Forge party worker accountability — implementation plan

Derived from [the design](../specs/2026-09-05-forge-worker-accountability-design.md) and
[ADR 0055](../../adr/0055-party-derives-red-and-names-its-committer.md).

**Goal.** Make two claims in a `$forge` party implementer's report derived by the orchestrator
instead of read from it: the red half of every `focused-test` contract, and which dispatch
produced each commit.

**Architecture.** One new executable, `skills/forge/scripts/verify-red`, reverts a task's
non-test paths to the task base inside the party worktree, runs a focused entry's red command,
requires a non-zero exit, and restores the tree under a trap. Contract text in
`skills/forge/SKILL.md` puts that invocation into the per-task loop and adds a `Forge-Dispatch`
trailer check beside the existing ancestry check; `skills/forge/implementer-prompt.md` makes the
trailer a placement value the worker verifies and emits.

**Tech stack.** Bash and Markdown. No dependencies, no build step. Gates are `just verify`.

**Expected implementation size: 470–580 changed lines (M) — summed from the file map below: the
script and its behaviour suite are the bulk, and the suite is sized against its three siblings in
`tests/fixtures/forge/`, which run 325–366 lines each.**

The design-to-implementation ratio sits in the note band. It is deliverable-driven rather than
argument-driven: this repository's plans carry complete code in every step that changes code, so
the script and the suite appear here in full and again in the tree. Recorded rather than cut —
trimming the embedded deliverable to move a ratio would remove the thing that makes the plan
executable by a context-free implementer.

## Global constraints

- **Bash 3.2 is the floor.** macOS ships 3.2.57. No `mapfile`, no `readarray`, no associative
  arrays. Indexed arrays are fine; `"${arr[@]}"` on an empty array is fatal under `set -u`, so
  guard every expansion of a possibly-empty array with its `${#arr[@]}` count first.
- Shell files start `#!/usr/bin/env bash` and `set -euo pipefail`, and indent with tabs.
- Capture a command's exit status explicitly rather than trailing `|| true`. A check that could
  not run must never read as a check that found nothing.
- Run gates bare. No pipes that swallow an exit code.
- `git diff --name-only` quotes unusual paths unless `-z` is passed. Every path list this plan
  builds uses `-z` and NUL-delimited reads.
- **No git version floor is declared.** This repository declares none today, and a toolchain
  floor is not this change's to set. The one modern construct used —
  `--format='%(trailers:key=Forge-Dispatch,valueonly,separator=%x2C)'` — was verified working on
  git 2.50.1 (Apple Git-155). If an older git is found to reject it, that is a finding for the
  operator, not a floor to add here.
- Anatomy rule 4: nothing automated asserts on prose. `verify-red` decides separability from path
  sets, never from file contents, and judges red by exit status, never by message text.
- The repository is public. No absolute checkout paths in committed text; plans and specs name
  the checkout root as `$WORK`.

## File map

| Path | Action | Answerable for |
|---|---|---|
| `skills/forge/scripts/verify-red` | create | reverting, running, restoring, and reporting one focused entry's red outcome |
| `tests/fixtures/forge/verify-red-test.sh` | create | every exit code and every restoration path of that script |
| `skills/forge/SKILL.md` | modify | when the orchestrator invokes it, how each outcome routes, the trailer check, the dispatch value |
| `skills/forge/implementer-prompt.md` | modify | the trailer as a placement value the worker verifies and emits |
| `.claude-plugin/plugin.json` | modify | version bump |

---

## Task 1 — `verify-red` and its behaviour suite

Creates `skills/forge/scripts/verify-red` and `tests/fixtures/forge/verify-red-test.sh`. Nothing
in this task edits a skill's instructions; Task 2 wires the script into the loop.

### Interfaces

Consumed from earlier tasks: nothing, this is the first task.

Provided to Task 2, relied on there verbatim:

```
verify-red --base SHA --head SHA --test PATH [--test PATH]... -- COMMAND [ARG...]
```

Exit codes, which are the interface Task 2 routes on:

| Exit | Verdict line printed on stdout |
|---:|---|
| 0 | `verify-red: red-confirmed (command exit N)` |
| 1 | `verify-red: red-not-reproduced (command exit 0 with N implementation path(s) at SHORTSHA)` |
| 2 | usage, printed on stderr |
| 3 | precondition failure, printed on stderr |
| 4 | `verify-red: red-not-separable (every path changed in BASE..HEAD is a named test path)` |
| 5 | restoration failure, printed on stderr |

### Verification

- `focused-test` — `tests/fixtures/forge/verify-red-test.sh`. Expected red: the suite fails
  because the script does not exist. Green command: `just test verify-red`.

### Steps

**1.1 — Write the failing suite.** Create `tests/fixtures/forge/verify-red-test.sh` with this
content, then `chmod +x` it and `git add` it (`just test` discovers suites with `git ls-files -z
-- '*-test.sh'`, so an untracked suite does not run).

```bash
#!/usr/bin/env bash
# Behaviour suite for skills/forge/scripts/verify-red.
#
# Every case builds a throwaway git repository holding one implementation file and one test
# file, commits a base and then a task commit, and drives the script across that range. The
# assertions are on exit status and on the tree being exactly at HEAD afterwards -- the two
# things the orchestrator relies on -- never on message wording.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/../../../scripts/test-fixture-helpers.sh
. "$SCRIPT_DIR/../../../scripts/test-fixture-helpers.sh"

# Hooks export repository-local Git variables that override `git -C`. Clear
# Git's complete reported set before any fixture repository is discovered.
clear_git_env

fixture_init verify-red-test

# The suite lives in tests/fixtures/ so it is excluded from the installed
# payload; the script it exercises ships under skills/.
SCRIPT="$SCRIPT_DIR/../../../skills/forge/scripts/verify-red"
[ -x "$SCRIPT" ] || fail "not executable: $SCRIPT"

# Builds a repository in a fresh directory and reports it in REPO, with BASE and HEAD set.
# impl.sh holds the implementation, impl-test.sh the test. The task commit rewrites impl.sh so
# that reverting it makes impl-test.sh fail.
make_repo() {
	REPO=$(mktemp -d "$SCRATCH/repo.XXXXXX")
	git -C "$REPO" init -q
	git -C "$REPO" config user.email fixture@example.invalid
	git -C "$REPO" config user.name Fixture
	printf 'old\n' >"$REPO/impl.sh"
	git -C "$REPO" add -A
	git -C "$REPO" commit -qm base
	BASE=$(git -C "$REPO" rev-parse HEAD)
	printf 'new\n' >"$REPO/impl.sh"
	printf '#!/usr/bin/env bash\ngrep -q new impl.sh\n' >"$REPO/impl-test.sh"
	git -C "$REPO" add -A
	git -C "$REPO" commit -qm task
	HEAD_SHA=$(git -C "$REPO" rev-parse HEAD)
}

# Runs the script inside REPO, recording its status in STATUS. Never lets a non-zero status end
# the suite -- every case here asserts on a specific code.
run_script() {
	STATUS=0
	(cd "$REPO" && "$SCRIPT" "$@") >"$SCRATCH/out" 2>"$SCRATCH/err" || STATUS=$?
}

assert_status() { # expected, label
	[ "$STATUS" -eq "$1" ] || fail "$2: expected exit $1, got $STATUS: $(cat "$SCRATCH/err")"
}

# Tracked state only, matching what the script promises: it is answerable for the paths it
# reverted, not for whatever the red command left lying around.
assert_clean() { # label
	local pending
	pending=$(git -C "$REPO" status --porcelain --untracked-files=no)
	[ -z "$pending" ] || fail "$1: tracked tree not restored: $pending"
}

# --- usage ---------------------------------------------------------------

make_repo
run_script
assert_status 2 "no arguments"

run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh
assert_status 2 "no -- separator"

run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh --
assert_status 2 "empty command"

run_script --base "$BASE" --test impl-test.sh -- true
assert_status 2 "missing --head"

# --- preconditions -------------------------------------------------------

run_script --base "$BASE" --head deadbeefdeadbeefdeadbeefdeadbeefdeadbeef \
	--test impl-test.sh -- true
assert_status 3 "unresolvable head"

run_script --base "$BASE" --head "$HEAD_SHA" --test nosuch-test.sh -- true
assert_status 3 "--test path outside the range"

printf 'dirty\n' >>"$REPO/impl.sh"
run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh -- true
assert_status 3 "modified tree"
git -C "$REPO" checkout -- impl.sh

# --head must be the checked-out commit. Restoration puts every reverted path back to it, so a
# stale value would restore the tree to a commit it was never on -- and the check has to happen
# before any mutation, not after.
make_repo
printf 'later\n' >>"$REPO/impl.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm later
run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh -- true
assert_status 3 "stale --head"
assert_clean "stale --head"

# An untracked file is neither the script's doing nor its business: it must not refuse to start,
# and it must not delete it.
make_repo
printf 'scratch\n' >"$REPO/notes.txt"
run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh -- bash impl-test.sh
assert_status 0 "untracked file present"
[ -f "$REPO/notes.txt" ] || fail "untracked file present: the script removed it"

# --- verdicts ------------------------------------------------------------

make_repo
run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh -- bash impl-test.sh
assert_status 0 "red confirmed"
assert_clean "red confirmed"
grep -q 'red-confirmed' "$SCRATCH/out" || fail "red confirmed: no verdict line"

make_repo
run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh -- true
assert_status 1 "red not reproduced"
assert_clean "red not reproduced"

# Only the test file moves, so there is no implementation to revert.
make_repo
printf '#!/usr/bin/env bash\ntrue\n' >"$REPO/second-test.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm tests-only
ONLY_BASE=$HEAD_SHA
ONLY_HEAD=$(git -C "$REPO" rev-parse HEAD)
run_script --base "$ONLY_BASE" --head "$ONLY_HEAD" --test second-test.sh -- true
assert_status 4 "not separable"
assert_clean "not separable"

# --- restoration ---------------------------------------------------------

# An implementation file the task created must be removed for the run and put back after.
make_repo
printf 'helper\n' >"$REPO/added.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm add-impl
ADD_HEAD=$(git -C "$REPO" rev-parse HEAD)
run_script --base "$BASE" --head "$ADD_HEAD" --test impl-test.sh -- bash impl-test.sh
assert_status 0 "created implementation file"
assert_clean "created implementation file"
[ -f "$REPO/added.sh" ] || fail "created implementation file: not restored"

# An implementation file the task deleted must come back for the run and be removed after.
make_repo
git -C "$REPO" rm -q impl.sh
printf '#!/usr/bin/env bash\n! test -f impl.sh\n' >"$REPO/impl-test.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm delete-impl
DEL_HEAD=$(git -C "$REPO" rev-parse HEAD)
run_script --base "$HEAD_SHA" --head "$DEL_HEAD" --test impl-test.sh -- bash impl-test.sh
assert_status 0 "deleted implementation file"
assert_clean "deleted implementation file"
[ ! -f "$REPO/impl.sh" ] || fail "deleted implementation file: not removed again"

# A path containing a space survives the NUL-delimited read.
make_repo
printf 'old\n' >"$REPO/with space.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm spaced-base
SPACE_BASE=$(git -C "$REPO" rev-parse HEAD)
printf 'new\n' >"$REPO/with space.sh"
printf '#!/usr/bin/env bash\ngrep -q new "with space.sh"\n' >"$REPO/impl-test.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm spaced-task
SPACE_HEAD=$(git -C "$REPO" rev-parse HEAD)
run_script --base "$SPACE_BASE" --head "$SPACE_HEAD" --test impl-test.sh -- bash impl-test.sh
assert_status 0 "path with a space"
assert_clean "path with a space"

# A rename is a delete and an add inside one range, so both halves have to come back.
make_repo
git -C "$REPO" mv impl.sh renamed.sh
printf '#!/usr/bin/env bash\ngrep -q new renamed.sh\n' >"$REPO/impl-test.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm rename-impl
REN_HEAD=$(git -C "$REPO" rev-parse HEAD)
run_script --base "$HEAD_SHA" --head "$REN_HEAD" --test impl-test.sh -- bash impl-test.sh
assert_status 0 "renamed implementation file"
assert_clean "renamed implementation file"
[ -f "$REPO/renamed.sh" ] || fail "renamed implementation file: not restored"
[ ! -f "$REPO/impl.sh" ] || fail "renamed implementation file: old path left behind"

# A red command that writes an artifact must still report the verdict, not an unrestored tree.
make_repo
run_script --base "$BASE" --head "$HEAD_SHA" --test impl-test.sh -- \
	bash -c 'mkdir -p .cache && : >.cache/x && bash impl-test.sh'
assert_status 0 "command wrote an untracked artifact"
assert_clean "command wrote an untracked artifact"

# Two --test paths, where only one of them is what the command actually reads.
make_repo
printf '#!/usr/bin/env bash\ntrue\n' >"$REPO/extra-test.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm second-test
TWO_HEAD=$(git -C "$REPO" rev-parse HEAD)
run_script --base "$BASE" --head "$TWO_HEAD" --test impl-test.sh --test extra-test.sh \
	-- bash impl-test.sh
assert_status 0 "two --test paths"
assert_clean "two --test paths"

# Exit 5 is constructed, not waited for: once restoration is scoped to the reverted paths no
# benign fixture reaches it, and an exit code with no case is how the loudest stop in the
# contract ships untested. The red command makes the implementation's directory unwritable, so
# restoration cannot put the file back.
make_repo
mkdir -p "$REPO/pkg"
git -C "$REPO" mv impl.sh pkg/impl.sh
printf '#!/usr/bin/env bash\ngrep -q new pkg/impl.sh\n' >"$REPO/impl-test.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm move-into-pkg
PKG_BASE=$(git -C "$REPO" rev-parse HEAD)
printf 'newer\n' >"$REPO/pkg/impl.sh"
# The named test file has to move inside the range under test, or the run stops at the
# untouched---test precondition before it ever reaches restoration.
printf '#!/usr/bin/env bash\ngrep -q newer pkg/impl.sh\n' >"$REPO/impl-test.sh"
git -C "$REPO" add -A
git -C "$REPO" commit -qm change-in-pkg
PKG_HEAD=$(git -C "$REPO" rev-parse HEAD)
run_script --base "$PKG_BASE" --head "$PKG_HEAD" --test impl-test.sh -- \
	bash -c 'chmod 0500 pkg; exit 1'
chmod 0700 "$REPO/pkg"
assert_status 5 "restoration blocked"
grep -q 'could not restore' "$SCRATCH/err" ||
	fail "restoration blocked: no restoration diagnostic on stderr"

printf 'verify-red-test: all cases passed\n'
```

**1.2 — Run it and confirm it fails.**

```
just test verify-red
```

Expect a non-zero exit with `verify-red-test: not executable:` naming the missing script. That is
the red state: the suite runs and the script is absent.

**1.3 — Write the script.** Create `skills/forge/scripts/verify-red` with this content and
`chmod +x` it.

```bash
#!/usr/bin/env bash
# Re-derive the red half of one focused-test contract.
#
# The implementer's report says a named test failed before the implementation existed. This runs
# that claim instead of reading it: revert the task's non-test paths to the task base, run the
# entry's exact command, and require it to fail. The tree is restored either way.
#
# Usage: verify-red --base SHA --head SHA --test PATH [--test PATH]... -- COMMAND [ARG...]
#
# Exit codes are the interface -- the orchestrator routes on them:
#   0  red-confirmed          the command failed with the implementation reverted
#   1  red-not-reproduced     it passed anyway; the red claim is not supported
#   2  usage error
#   3  precondition failure   unresolvable ref, a --head that is not the checked-out commit,
#                             pending tracked modifications, empty range, untouched --test path
#   4  red-not-separable      every changed path is a named test path; nothing to revert
#   5  restoration failure    a reverted path is not back at HEAD; nothing may proceed
#
# A command containing shell operators must be passed as `bash -c '<command>'`: the argument
# vector after `--` is executed directly, not through a shell.
set -euo pipefail

usage() {
	printf 'usage: verify-red --base SHA --head SHA --test PATH [--test PATH]... -- COMMAND [ARG...]\n' >&2
	exit 2
}

base=
head=
test_paths=()
saw_separator=0

while [ $# -gt 0 ]; do
	case $1 in
	--base)
		[ $# -ge 2 ] || usage
		base=$2
		shift 2
		;;
	--head)
		[ $# -ge 2 ] || usage
		head=$2
		shift 2
		;;
	--test)
		[ $# -ge 2 ] || usage
		test_paths[${#test_paths[@]}]=$2
		shift 2
		;;
	--)
		saw_separator=1
		shift
		break
		;;
	*) usage ;;
	esac
done

[ "$saw_separator" -eq 1 ] || usage
[ $# -gt 0 ] || usage
[ -n "$base" ] || usage
[ -n "$head" ] || usage
[ "${#test_paths[@]}" -gt 0 ] || usage

precondition() {
	printf 'verify-red: %s\n' "$1" >&2
	exit 3
}

git rev-parse --git-dir >/dev/null 2>&1 || precondition 'not inside a git working tree'

base_sha=$(git rev-parse --verify --quiet "$base^{commit}") ||
	precondition "$base does not name a commit here"
head_sha=$(git rev-parse --verify --quiet "$head^{commit}") ||
	precondition "$head does not name a commit here"

# Restoration puts every reverted path back to $head_sha, so a $head that is not what is
# actually checked out would "restore" the tree to a commit it was never at -- silently, since
# the reverted paths would then differ from the real HEAD and the proof below would fail after
# the damage rather than before it. Checked here, ahead of every mutation.
current_head=$(git rev-parse --verify --quiet HEAD) ||
	precondition 'HEAD does not resolve; no commit is checked out here'
[ "$head_sha" = "$current_head" ] ||
	precondition "--head $head is not the checked-out commit ($current_head)"

# Refusing pending tracked modifications is what makes the reversion below safe: everything this
# script restores it restores from a commit, so uncommitted work in the same paths would be lost.
# Untracked files are deliberately not counted -- they are neither this script's doing nor its
# business, and counting them would refuse to start in any tree holding a stray scratch file.
pending=$(git status --porcelain --untracked-files=no) ||
	precondition 'could not read the working tree status'
[ -z "$pending" ] || {
	printf 'verify-red: refusing to run against a modified tree:\n%s\n' "$pending" >&2
	exit 3
}

# Through a file rather than a pipeline or command substitution: -z output holds NUL, which a
# shell variable cannot carry, and a process substitution would discard git's exit status --
# leaving a diff that could not run indistinguishable from a range that changed nothing.
listing=$(mktemp "${TMPDIR:-/tmp}/verify-red.XXXXXX") ||
	precondition 'could not create a scratch file for the path list'
if ! git diff -z --name-only "$base_sha" "$head_sha" >"$listing"; then
	rm -f -- "$listing"
	precondition "could not diff $base..$head"
fi

changed=()
while IFS= read -r -d '' path; do
	changed[${#changed[@]}]=$path
done <"$listing"
rm -f -- "$listing"

[ "${#changed[@]}" -gt 0 ] || precondition "$base..$head changes no paths"

contains() { # needle haystack...
	local needle=$1 item
	shift
	for item in "$@"; do
		if [ "$item" = "$needle" ]; then
			return 0
		fi
	done
	return 1
}

# A focused entry naming a file the task never touched is a report that does not describe this
# range. Failing here rather than proceeding keeps a mis-specified entry from producing a verdict.
index=0
while [ "$index" -lt "${#test_paths[@]}" ]; do
	candidate=${test_paths[$index]}
	index=$((index + 1))
	contains "$candidate" "${changed[@]}" ||
		precondition "--test $candidate is not among the paths changed in $base..$head"
done

implementation=()
index=0
while [ "$index" -lt "${#changed[@]}" ]; do
	candidate=${changed[$index]}
	index=$((index + 1))
	if contains "$candidate" "${test_paths[@]}"; then
		continue
	fi
	implementation[${#implementation[@]}]=$candidate
done

# Separability is decided from the path sets alone. Reading a file to judge whether its tests and
# its implementation are entangled would be a prose assertion; an empty implementation set is the
# structural form of the same fact and covers the case that matters -- a language whose unit tests
# live in the file under test.
if [ "${#implementation[@]}" -eq 0 ]; then
	printf 'verify-red: red-not-separable (every path changed in %s..%s is a named test path)\n' \
		"$base" "$head"
	exit 4
fi

restore_status=0
restore_done=0

# Always returns 0: it runs as an EXIT trap, and under `set -e` a trap's non-zero return becomes
# the shell's exit status, which would overwrite the verdict this script exists to report. The
# outcome is carried in restore_status and read by the caller below.
restore() {
	local index=0 path
	[ "$restore_done" -eq 0 ] || return 0
	restore_done=1
	while [ "$index" -lt "${#implementation[@]}" ]; do
		path=${implementation[$index]}
		index=$((index + 1))
		if git cat-file -e "$head_sha:$path" 2>/dev/null; then
			git checkout "$head_sha" -- "$path" || restore_status=1
		elif ! git rm -q -f --ignore-unmatch -- "$path"; then
			# `git rm`, not a bare `rm`: the reversion above used `git checkout`, which
			# writes the index as well as the working tree, so a path the task deleted is
			# staged as an addition by the time we get here. Removing it from the working
			# tree alone leaves that index entry, and the tree reads as unrestored while
			# looking correct on disk. --ignore-unmatch keeps this a no-op for a path the
			# reversion never staged.
			restore_status=1
		fi
	done
	return 0
}

restoration_failed() {
	printf 'verify-red: could not restore the tree to %s -- %s\n' "$head" "$1" >&2
	printf 'verify-red: resolve the working tree before anything else runs here\n' >&2
	exit 5
}

# Installed before the first mutation, so an interrupt between here and the explicit restore
# below still puts the implementation back.
trap restore EXIT

index=0
while [ "$index" -lt "${#implementation[@]}" ]; do
	path=${implementation[$index]}
	index=$((index + 1))
	# cat-file exits non-zero with its own diagnostic when the path is absent at that commit;
	# any non-zero means absent, so the status is not inspected further. A path absent at base
	# is one the task created, and reverting it means removing it.
	if git cat-file -e "$base_sha:$path" 2>/dev/null; then
		git checkout "$base_sha" -- "$path" || {
			restore
			[ "$restore_status" -eq 0 ] || restoration_failed "reverting $path also failed"
			precondition "could not revert $path to $base"
		}
	elif ! git rm -q -f --ignore-unmatch -- "$path"; then
		restore
		[ "$restore_status" -eq 0 ] || restoration_failed "removing $path also failed"
		precondition "could not remove $path, which $base does not have"
	fi
done

# errexit is lifted for exactly one command: a non-zero status here is the result, not a fault.
set +e
"$@"
red_status=$?
set -e

restore
[ "$restore_status" -eq 0 ] || restoration_failed 'one or more paths could not be put back'

# Scoped to the paths this script reverted, and covering index and working tree together --
# `git diff HEAD` sees both. Whatever the red command wrote elsewhere is outside the contract: a
# cache directory or a coverage file is not this script's to police, and a whole-tree check would
# turn an ordinary test run into exit 5, the one outcome nothing may proceed past.
git diff --quiet HEAD -- "${implementation[@]}" ||
	restoration_failed "still differing from $head: $(git diff --name-only HEAD -- "${implementation[@]}" | tr '\n' ' ')"

if [ "$red_status" -ne 0 ]; then
	printf 'verify-red: red-confirmed (command exit %s)\n' "$red_status"
	exit 0
fi

printf 'verify-red: red-not-reproduced (command exit 0 with %s implementation path(s) at %s)\n' \
	"${#implementation[@]}" "$(git rev-parse --short "$base_sha")"
exit 1
```

**1.4 — Run the suite green.**

```
just test verify-red
```

Expect exit 0 and `verify-red-test: all cases passed`.

**1.5 — Run the guardrails and commit.**

```
just verify
```

Expect exit 0. Commit as `feat(forge): re-derive a task's red claim with verify-red`.

### Acceptance criteria

- `skills/forge/scripts/verify-red` exists, is executable, and starts `#!/usr/bin/env bash` with
  `set -euo pipefail`.
- `just test verify-red` exits 0.
- Every exit code in the Interfaces table — 0, 1, 2, 3, 4 and 5 — is asserted by at least one
  case in the suite.
- After every case that reaches the command, `git status --porcelain --untracked-files=no` in the
  fixture is empty. Untracked output the command left is deliberately not asserted away: the
  suite asserts what the script promises, and the script promises the reverted paths.
- `just verify` exits 0.

---

## Task 2 — Wire both checks into the party contract

Modifies `skills/forge/SKILL.md`, `skills/forge/implementer-prompt.md`, and
`.claude-plugin/plugin.json`. No behaviour is executable here; this is the instruction contract
that makes Task 1's script and the trailer part of the loop.

### Interfaces

Consumed from Task 1, used verbatim:

```
verify-red --base SHA --head SHA --test PATH [--test PATH]... -- COMMAND [ARG...]
```

with exit codes 0, 1, 2, 3, 4, 5 as tabulated in Task 1.

Provided to nothing further in this plan.

### Verification

- `task-test-not-applicable` — the changed surface is agent instruction text in `SKILL.md` and
  `implementer-prompt.md`. No executable consumer validates its wording, and the repository's
  fourth anatomy rule forbids a gate that asserts on prose, so no task-specific executable or
  structural observation could fail meaningfully. The structural facts that *are* checkable —
  that the skill still shapes correctly and that every reference link resolves — are covered by
  `just shape-check` inside `just verify`, which this task runs.

The agent-behavior evaluation cases `EV-1` through `EV-9` in the design's *AI surface* section
are run against the changed instructions after this task, with a fresh evaluator, comparing
observable routes to that table.

### Steps

**2.1 — Add the trailer to the placement contract in `skills/forge/implementer-prompt.md`.** In
the `## Placement — verify before your first edit` section, extend the mandatory value list from
two entries to three:

```
    - **Worktree:** [WORKTREE_PATH] (absolute path)
    - **Branch:** [BRANCH_NAME]
    - **Dispatch identity:** [DISPATCH_ID] (e.g. `task-3.1`)
```

and add, after the existing `git branch --show-current` precondition block:

```
    Every commit you make carries [DISPATCH_ID] as a git trailer, on its own line
    at the end of the commit message, separated from the body by a blank line:

        Forge-Dispatch: [DISPATCH_ID]

    Use the value exactly as given. Do not invent one, do not abbreviate it, and
    do not carry one from another task. A dispatch that did not give you a
    Dispatch identity is invalid: stop and report NEEDS_CONTEXT, as with a
    missing worktree or branch.
```

**2.2 — Add the trailer to the report contract in the same file.** In the `## Reporting` section's
short-message list, change the commits bullet from

```
    - the commits you made, short SHA and subject
```

to

```
    - the commits you made, short SHA and subject — every one carrying
      `Forge-Dispatch: [DISPATCH_ID]`, which the orchestrator verifies rather
      than trusting
```

**2.3 — Add the trailer check to step 5 of the per-task loop in `skills/forge/SKILL.md`.** Step 5
currently ends with the stray-commit reasoning. Append to it:

```
   Then verify the same range identifies its author. Every commit in
   `<BASE>..<BRANCH_NAME>` must carry this task's dispatch chain:

       git log --format='%H %(trailers:key=Forge-Dispatch,valueonly,separator=%x2C)' <BASE>..<BRANCH_NAME>

   Verify the **chain**, not the exact value you issued. Every commit must carry
   `task-<N>` for this task's N, with an attempt of 1 or 2:

   - the value you dispatched — ordinary; the commit is this worker's.
   - the same unit at the other attempt — the late report that raced a
     replacement. Record it in the ledger's `dispatch` field and reconcile both
     result sets per dispatch-liveness. **Not a stop.** Stopping here would
     refuse the one case this identity was added to resolve.
   - absent, or a different unit — the same stop-and-reconcile as a stray
     commit.

   A replacement dispatch reuses the original task base, so attempt 1's commits
   stay inside this range rather than falling outside it.
```

**2.4 — Add the red re-derivation to step 6 of the same loop.** Step 6 currently reads the report
and verifies one entry per planned contract. Append to it:

```
   A focused entry's red half is then re-derived rather than read. From the
   assigned worktree, for each focused entry:

       scripts/verify-red --base <BASE> --head <HEAD> --test <the entry's test file> -- <the entry's exact red command>

   `<BASE>` is the task base you noted before the dispatch; `<HEAD>` is the
   branch tip you verified in step 5 (`git rev-parse <BRANCH_NAME>`), which is
   the SHA the ledger line already records. Pass a command containing shell
   operators as `bash -c '<command>'` — the argument vector runs directly, not
   through a shell.

   `--test` takes **files**. Where the entry names a case rather than a file,
   pass the file part — everything before the `::` or the runner's selector
   flag. Where the entry names a test file this task did not change, the check
   does not apply to it: that entry returns to the plan checkpoint, because an
   inventory naming a test the task never touched is a plan defect rather than a
   verdict about red.

   Route on its exit status, which is the interface:

   - **0** (`red-confirmed`) — the entry is closed.
   - **1** (`red-not-reproduced`) — the command passed with the implementation
     reverted, so the report's red claim is unsupported. Stop and reconcile, as
     with a stray commit. Do not re-dispatch and do not accept the entry.
   - **4** (`red-not-separable`) — every path the task changed is a named test
     file, so there was nothing to revert. Record the outcome and continue; the
     entry is not verified and must not be described as though it were.
   - **2**, **3**, or **5** — the check could not run, or the tree is not back
     at HEAD. Stop. A 5 leaves the worktree unresolved and nothing may proceed
     past it, exactly as a reviewer's `CLEANUP_FAILED` does.

   Never substitute the green command here. Running a test that passes proves
   nothing about whether it could ever have failed, which is the whole of what
   this step establishes.
```

**2.5 — Record the outcomes in the ledger line.** In step 8 of the per-task loop and in the
*Durable progress* section, change the task-complete line from

```
Task N: complete (commits <base-sha>..<head-sha>, verification <focused-test|task-test-not-applicable|mixed>)
```

to

```
Task N: complete (commits <base-sha>..<head-sha>, verification <focused-test|task-test-not-applicable|mixed>, red <confirmed=<n>, not-separable=<n>>, dispatch <DISPATCH_ID>)
```

Both occurrences change; they are the same line stated twice and must stay identical.

**2.6 — Add the dispatch identity to *every* statement of the placement contract.**
`skills/forge/SKILL.md` states it four times, and a contract that says "two values" in three
places and "three values" in one is a contract an implementer will satisfy by the count it read
first. All four change together.

(a) At the per-task loop's dispatch step:

```
2. Dispatch an implementer with [implementer-prompt.md](implementer-prompt.md),
   carrying the placement contract from *What goes in a dispatch*: the
   assigned worktree as an absolute path, the exact branch name, and the
   dispatch identity `task-<N>.<attempt>`.
```

(b) In the bulleted list under *What goes in a dispatch*:

```
- the **placement contract** — the assigned worktree as an absolute path, the
  exact branch name the worker commits to, and the dispatch identity
  `task-<N>.<attempt>` it stamps on every commit. A dispatch missing any of the
  three values is invalid: do not send it, and stop with `NEEDS_CONTEXT` if you
  receive one. The implementer template turns them into a precondition the
  worker verifies before its first edit, failing closed on a mismatch
```

(c) In the paragraph beginning "Every fix dispatch carries the implementer contract":

```
Every fix dispatch carries the implementer contract, placement included: the
assigned worktree path, branch name, and the `review-fix.<attempt>` dispatch
identity, verified before the first edit.
```

(d) In the paragraph describing the single fix worker after the final review:

```
It carries the same placement contract as any implementer: the
branch's worktree path, branch name, and the `review-fix.<attempt>` dispatch
identity, verified before the first edit.
```

**2.7 — Mint the identity where the dispatch is described.** In *Silent party workers*, after the
paragraph that assigns the recovery-chain identifier, add:

```
The chain identifier is minted at dispatch on every run, not when a silence
recovery starts. An implementer's is `task-<N>.<attempt>`; the fix worker after
the whole-branch review uses `review-fix.<attempt>`. `task-<N>` is the recovery
chain, and `.<attempt>` is `1` for the original and `2` for the one replacement
this budget permits — so the commits of a worker whose late report raced its
replacement are separable in `git log` rather than by ledger ordering.
```

**2.8 — Verify the fix wave's own range.** In the fix-wave paragraph, after the sentence
requiring the report to carry the command and its output, add:

```
Verify the fix wave's commits the way step 5 verifies a task's: every commit
from the reviewed HEAD to the branch tip must carry `review-fix.<attempt>`.
Absent or a different unit is a stop-and-reconcile. A stamp nobody checks is
attribution the next reconciliation cannot rely on.
```

**2.9 — Bump the version.** In `.claude-plugin/plugin.json`, change `"version": "4.0.2"` to
`"version": "4.1.0"`. MINOR: `$forge` gains a capability and no invocation's contract breaks.

**2.10 — Run the guardrails and commit.**

```
just verify
```

Expect exit 0. Commit as `feat(forge): verify red and dispatch identity in the party loop`.

### Acceptance criteria

- `skills/forge/implementer-prompt.md` names three mandatory placement values, and a dispatch
  missing any one of them is `NEEDS_CONTEXT`.
- All four statements of the placement contract in `skills/forge/SKILL.md` name three values.
  Check by count, the way step 2.5 checks the ledger line's two occurrences: `rg -c` for the
  contract's phrasing must find no statement naming only two.
- `skills/forge/SKILL.md` step 5 verifies the task's range against the **chain** — this unit,
  attempt 1 or 2 — and routes the other-attempt commit to reconciliation rather than to a stop.
- Step 6 invokes `verify-red` per focused entry, routes all six exit codes, and never substitutes
  the green command for the red one.
- The fix wave's range is verified against `review-fix.<attempt>`.
- The task-complete ledger line is stated identically in step 8 and in *Durable progress*.
- `.claude-plugin/plugin.json` reads `4.1.0`.
- `just verify` exits 0.
- `EV-1` through `EV-9` run against the changed instructions and match their observable routes.

## Rollback

Both tasks are additive. Reverting Task 2's commit returns the loop to reading the report;
reverting Task 1's removes an executable nothing else references. Neither leaves persisted state:
`verify-red` writes only inside the worktree it restores, and the trailer is commit metadata no
gate reads.

## Deferrals

None recorded yet. Entries from the design review land here.
