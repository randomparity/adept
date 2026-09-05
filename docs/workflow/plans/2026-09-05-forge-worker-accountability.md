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

**Expected implementation size: 405–515 changed lines (M) — summed from the file map below: the
script and its behaviour suite are the bulk, and the suite is sized against its three siblings in
`tests/fixtures/forge/`, which run 325–366 lines each.**

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

assert_clean() { # label
	local pending
	pending=$(git -C "$REPO" status --porcelain)
	[ -z "$pending" ] || fail "$1: tree not restored: $pending"
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
#   3  precondition failure   dirty tree, unresolvable ref, empty range, untouched --test path
#   4  red-not-separable      every changed path is a named test path; nothing to revert
#   5  restoration failure    the tree is not back at HEAD; nothing may proceed
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

# Refusing a modified tree is what makes the reversion below safe: everything this script
# restores it restores from a commit, so uncommitted work in the same paths would be lost.
pending=$(git status --porcelain) || precondition 'could not read the working tree status'
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
		elif [ -e "$path" ] && ! rm -f -- "$path"; then
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
	elif [ -e "$path" ] && ! rm -f -- "$path"; then
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

pending=$(git status --porcelain) || restoration_failed 'could not read the working tree status'
[ -z "$pending" ] || restoration_failed "the tree still differs:
$pending"

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
- Every exit code in the Interfaces table is asserted by at least one case in the suite.
- After every case that reaches the command, `git status --porcelain` in the fixture is empty.
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

The agent-behavior evaluation cases `EV-1` through `EV-7` in the design's *AI surface* section
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
   `<BASE>..<BRANCH_NAME>` must carry the dispatch identity you issued:

       git log --format='%H %(trailers:key=Forge-Dispatch,valueonly,separator=%x2C)' <BASE>..<BRANCH_NAME>

   A commit with no value, or with a value other than the one this dispatch was
   given, is the same stop-and-reconcile as a stray commit. The identity is what
   makes a late report racing a replacement reconcilable — without it, deciding
   which worker wrote which commit is an inference over ledger ordering.
```

**2.4 — Add the red re-derivation to step 6 of the same loop.** Step 6 currently reads the report
and verifies one entry per planned contract. Append to it:

```
   A focused entry's red half is then re-derived rather than read. From the
   assigned worktree, for each focused entry:

       scripts/verify-red --base <BASE> --head <HEAD> --test <the entry's test file> -- <the entry's exact red command>

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

**2.6 — Add the dispatch identity to *What goes in a dispatch*.** In the bulleted list of what
every implementer prompt must include, extend the placement-contract bullet so the third value is
mandatory alongside the other two:

```
- the **placement contract** — the assigned worktree as an absolute path, the
  exact branch name the worker commits to, and the dispatch identity
  `task-<N>.<attempt>` it stamps on every commit. A dispatch missing any of the
  three values is invalid: do not send it, and stop with `NEEDS_CONTEXT` if you
  receive one. The implementer template turns them into a precondition the
  worker verifies before its first edit, failing closed on a mismatch
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

**2.8 — Carry the identity into the fix dispatch.** In the paragraph beginning "Every fix dispatch
carries the implementer contract, placement included", change "the assigned worktree path and
branch name" to "the assigned worktree path, branch name, and the `review-fix.<attempt>` dispatch
identity".

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
- `skills/forge/SKILL.md` step 5 verifies the trailer over the task's range; step 6 invokes
  `verify-red` per focused entry and routes all six exit codes; neither substitutes the green
  command for the red one.
- The task-complete ledger line is stated identically in step 8 and in *Durable progress*.
- `.claude-plugin/plugin.json` reads `4.1.0`.
- `just verify` exits 0.
- `EV-1` through `EV-7` run against the changed instructions and match their observable routes.

## Rollback

Both tasks are additive. Reverting Task 2's commit returns the loop to reading the report;
reverting Task 1's removes an executable nothing else references. Neither leaves persisted state:
`verify-red` writes only inside the worktree it restores, and the trailer is commit metadata no
gate reads.

## Deferrals

None recorded yet. Entries from the design review land here.
