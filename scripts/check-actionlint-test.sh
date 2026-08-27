#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=SCRIPTDIR/test-fixture-helpers.sh
. "$script_dir/test-fixture-helpers.sh"

fixture_init check-actionlint-test

gate=$script_dir/check-actionlint.sh
stub_dir=$SCRATCH/bin
mkdir -p "$stub_dir"

cat >"$stub_dir/actionlint" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$ACTIONLINT_LOG"
exit "${ACTIONLINT_STATUS:-0}"
STUB
chmod +x "$stub_dir/actionlint"

cat >"$stub_dir/shellcheck" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
script=''
for argument in "$@"; do
	script=$argument
done
printf '%s\n' "$*" >>"$SHELLCHECK_LOG"
cat "$script" >>"$SHELLCHECK_CONTENT"
printf '\n-- next script --\n' >>"$SHELLCHECK_CONTENT"
if grep -q 'shellcheck-failure' "$script"; then
	exit 1
fi
STUB
chmod +x "$stub_dir/shellcheck"

assert_status() { # label expected actual
	[[ $2 -eq $3 ]] || fail "$1: expected exit $2, got $3"
}

assert_contains() { # label needle file
	rg --no-config -F -- "$2" "$3" >/dev/null ||
		fail "$1: missing '$2' in $3"
}

assert_empty() { # label file
	[[ ! -s $2 ]] || fail "$1: expected $2 to be empty"
}

write_workflow() { # directory name body
	mkdir -p "$1"
	printf '%s\n' "$2" >"$1/$3"
}

run_gate() { # workflow-dir [actionlint-status]
	local workflows=$1 status=${2:-0}
	ACTIONLINT_LOG=$SCRATCH/actionlint.log
	SHELLCHECK_LOG=$SCRATCH/shellcheck.log
	SHELLCHECK_CONTENT=$SCRATCH/shellcheck-content
	: >"$ACTIONLINT_LOG"
	: >"$SHELLCHECK_LOG"
	: >"$SHELLCHECK_CONTENT"
	RUN_STATUS=0
	RUN_OUTPUT=$(PATH="$stub_dir:$PATH" \
		ACTIONLINT_LOG="$ACTIONLINT_LOG" \
		ACTIONLINT_STATUS="$status" \
		SHELLCHECK_LOG="$SHELLCHECK_LOG" \
		SHELLCHECK_CONTENT="$SHELLCHECK_CONTENT" \
		"$gate" "$workflows" 2>&1) || RUN_STATUS=$?
}

green=$SCRATCH/green
write_workflow "$green" 'name: green
on: push
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo first
      - run: |-
          printf '"'"'%s\\n'"'"' second' green.yml
run_gate "$green"
assert_status 'literal run blocks' 0 "$RUN_STATUS"
[[ $(wc -l <"$ACTIONLINT_LOG") -eq 1 ]] ||
	fail 'actionlint should run exactly once'
[[ $(cat "$ACTIONLINT_LOG") == "-shellcheck= $green/green.yml" ]] ||
	fail "actionlint must disable integrated ShellCheck: $(cat "$ACTIONLINT_LOG")"
[[ $(wc -l <"$SHELLCHECK_LOG") -eq 2 ]] ||
	fail 'every literal run block must reach ShellCheck'
[[ $(rg --no-config -x -- '-s bash .*' "$SHELLCHECK_LOG" | wc -l) -eq 2 ]] ||
	fail 'ShellCheck must receive the explicit bash dialect for every run block'
assert_contains 'first run block' 'echo first' "$SHELLCHECK_CONTENT"
assert_contains 'second run block' 'second' "$SHELLCHECK_CONTENT"

matrix=$SCRATCH/matrix
# shellcheck disable=SC2016 # fixture preserves the literal Actions expression
write_workflow "$matrix" 'name: matrix
on: push
jobs:
  check:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - run: |
          echo matrix' matrix.yml
run_gate "$matrix"
assert_status 'static Unix matrix' 0 "$RUN_STATUS"
[[ $(wc -l <"$SHELLCHECK_LOG") -eq 1 ]] ||
	fail 'the static Unix matrix run block must reach ShellCheck'

matrix_leak=$SCRATCH/matrix-leak
# shellcheck disable=SC2016 # fixture preserves the literal Actions expression
write_workflow "$matrix_leak" 'name: matrix leak
on: push
jobs:
  earlier:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - run: |
          echo earlier
  later:
    runs-on: ${{ matrix.os }}
    steps:
      - run: |
          echo later' matrix-leak.yml
run_gate "$matrix_leak"
assert_status 'matrix state cannot leak between jobs' 2 "$RUN_STATUS"
case $RUN_OUTPUT in
*'cannot independently ShellCheck matrix.os'*) ;;
*) fail "matrix state leak: unexpected output: $RUN_OUTPUT" ;;
esac
assert_empty 'dynamic matrix runner did not reach ShellCheck' "$SHELLCHECK_LOG"

commented_jobs=$SCRATCH/commented-jobs
write_workflow "$commented_jobs" 'name: commented jobs
on: push
jobs: # supported comment
  check:
    runs-on: windows-latest
    steps:
      - run: |
          Write-Output unsupported' commented-jobs.yml
run_gate "$commented_jobs"
assert_status 'commented jobs runner rejection' 2 "$RUN_STATUS"
case $RUN_OUTPUT in
*'cannot independently ShellCheck runner'*) ;;
*) fail "commented jobs runner rejection: unexpected output: $RUN_OUTPUT" ;;
esac
assert_empty 'commented jobs did not reach ShellCheck' "$SHELLCHECK_LOG"

quoted_jobs=$SCRATCH/quoted-jobs
write_workflow "$quoted_jobs" 'name: quoted jobs
on: push
"jobs":
  check:
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo unsupported' quoted-jobs.yml
run_gate "$quoted_jobs"
assert_status 'quoted jobs rejection' 2 "$RUN_STATUS"
case $RUN_OUTPUT in
*'unrecognized jobs declaration'*) ;;
*) fail "quoted jobs rejection: unexpected output: $RUN_OUTPUT" ;;
esac
assert_empty 'quoted jobs did not reach ShellCheck' "$SHELLCHECK_LOG"

step_shell=$SCRATCH/step-shell
step_shell=$SCRATCH/step-shell
write_workflow "$step_shell" 'name: step shell
on: push
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo unsupported
        shell: bash' step-shell.yml
run_gate "$step_shell"
assert_status 'step shell rejection' 2 "$RUN_STATUS"
case $RUN_OUTPUT in
*'shell overrides are unsupported'*) ;;
*) fail "step shell rejection: unexpected output: $RUN_OUTPUT" ;;
esac
assert_empty 'step shell did not reach ShellCheck' "$SHELLCHECK_LOG"

workflow_default=$SCRATCH/workflow-default
write_workflow "$workflow_default" 'name: workflow default
on: push
defaults:
  run:
    shell: bash
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo unsupported' workflow-default.yml
run_gate "$workflow_default"
assert_status 'workflow default rejection' 2 "$RUN_STATUS"
case $RUN_OUTPUT in
*'shell overrides are unsupported'*) ;;
*) fail "workflow default rejection: unexpected output: $RUN_OUTPUT" ;;
esac
assert_empty 'workflow default did not reach ShellCheck' "$SHELLCHECK_LOG"

job_default=$SCRATCH/job-default
write_workflow "$job_default" 'name: job default
on: push
jobs:
  check:
    runs-on: ubuntu-latest
    defaults:
      run:
        shell: bash
    steps:
      - run: |
          echo unsupported' job-default.yml
run_gate "$job_default"
assert_status 'job default rejection' 2 "$RUN_STATUS"
case $RUN_OUTPUT in
*'shell overrides are unsupported'*) ;;
*) fail "job default rejection: unexpected output: $RUN_OUTPUT" ;;
esac
assert_empty 'job default did not reach ShellCheck' "$SHELLCHECK_LOG"

shellcheck_red=$SCRATCH/shellcheck-red
write_workflow "$shellcheck_red" 'name: shellcheck red
on: push
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - run: |
          shellcheck-failure' shellcheck-red.yml
run_gate "$shellcheck_red"
assert_status 'ShellCheck failure' 1 "$RUN_STATUS"
assert_contains 'ShellCheck failure reaches the gate' 'shellcheck-failure' "$SHELLCHECK_CONTENT"

inline=$SCRATCH/inline
write_workflow "$inline" 'name: inline
on: push
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - run: echo unsupported' inline.yml
run_gate "$inline"
assert_status 'inline run rejection' 2 "$RUN_STATUS"
case $RUN_OUTPUT in
*'must use a literal block scalar'*) ;;
*) fail "inline run rejection: unexpected output: $RUN_OUTPUT" ;;
esac
assert_empty 'inline run did not reach ShellCheck' "$SHELLCHECK_LOG"

windows=$SCRATCH/windows
write_workflow "$windows" 'name: windows
on: push
jobs:
  check:
    runs-on: windows-latest
    steps:
      - run: |
          Write-Output unsupported' windows.yml
run_gate "$windows"
assert_status 'non-Bash runner rejection' 2 "$RUN_STATUS"
case $RUN_OUTPUT in
*'cannot independently ShellCheck runner'*) ;;
*) fail "non-Bash runner rejection: unexpected output: $RUN_OUTPUT" ;;
esac
assert_empty 'non-Bash runner did not reach ShellCheck' "$SHELLCHECK_LOG"

unresolved=$SCRATCH/unresolved
# shellcheck disable=SC2016 # fixture preserves the literal Actions expression
write_workflow "$unresolved" 'name: unresolved
on: push
jobs:
  check:
    runs-on: ${{ matrix.os }}
    steps:
      - run: |
          echo unsupported' unresolved.yml
run_gate "$unresolved"
assert_status 'unresolved runner rejection' 2 "$RUN_STATUS"
case $RUN_OUTPUT in
*'cannot independently ShellCheck matrix.os'*) ;;
*) fail "unresolved runner rejection: unexpected output: $RUN_OUTPUT" ;;
esac
assert_empty 'unresolved runner did not reach ShellCheck' "$SHELLCHECK_LOG"

actionlint_red=$SCRATCH/actionlint-red
write_workflow "$actionlint_red" 'name: actionlint red
on: push
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo unreachable' actionlint-red.yml
run_gate "$actionlint_red" 9
assert_status 'actionlint failure' 9 "$RUN_STATUS"
assert_empty 'actionlint failure short-circuits ShellCheck' "$SHELLCHECK_LOG"

printf 'check-actionlint-test: all assertions passed\n'
