#!/usr/bin/env bash
set -euo pipefail

# ripgrep applies RIPGREP_CONFIG_PATH's contents as arguments ahead of the ones
# passed below, so a personal ripgreprc would otherwise steer this suite's own
# assertions.
unset RIPGREP_CONFIG_PATH

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=SCRIPTDIR/../../../scripts/test-fixture-helpers.sh
. "$script_dir/../../../scripts/test-fixture-helpers.sh"

# The suite lives in tests/fixtures/ so it is excluded from the installed
# payload. Everything it exercises does ship, so resolve those from the skill
# root once rather than counting `..` at each use.
skill_root=$(cd -- "$script_dir/../../../skills/bounty" && pwd -P)
helper="$skill_root/scripts/create-verified-issue.sh"
fixture_init create-verified-issue-test

assert_contains() {
	local needle=$1 file=$2
	rg -F -- "$needle" "$file" >/dev/null || fail "missing '$needle' in $file"
}

assert_count() {
	local expected=$1 pattern=$2 file=$3 actual
	actual=$(rg -c -- "$pattern" "$file" || true)
	actual=${actual:-0}
	[[ $actual == "$expected" ]] ||
		fail "expected $expected matches for '$pattern' in $file, got $actual"
}

mkdir -p "$SCRATCH/bin"
printf '%s\n' '#!/usr/bin/env bash' >"$SCRATCH/bin/gh"
cat >>"$SCRATCH/bin/gh" <<'FAKE_GH'
set -euo pipefail
printf '%q ' "$@" >>"$GH_CALL_LOG"
printf '\n' >>"$GH_CALL_LOG"

if [[ $1 == repo && $2 == view ]]; then
  if [[ ${GH_SCENARIO:-success} == target-url-error ]]; then
    printf 'HTTP 403 lookup denied\n' >&2
    exit 1
  fi
  host=github.com
  [[ ${GH_SCENARIO:-success} == ghes ]] && host=ghe.example.com
  printf 'https://%s/example/repo\n' "$host"
  exit 0
fi

if [[ $1 == issue && $2 == create ]]; then
  if [[ ${GH_SCENARIO:-success} == unresolved-create ]]; then
    printf 'created\n'
  else
    host=github.com
    [[ ${GH_SCENARIO:-success} == ghes ]] && host=ghe.example.com
    [[ ${GH_SCENARIO:-success} == wrong-create-host ]] && host=ghe.example.com
    printf 'https://%s/example/repo/issues/%s\n' "$host" "${GH_ISSUE_NUMBER:-101}"
    if [[ ${GH_SCENARIO:-success} == create-error-with-url ]]; then
      exit 1
    fi
  fi
  exit 0
fi

if [[ $1 == issue && $2 == view ]]; then
  if [[ ${GH_SCENARIO:-success} == view-error ]]; then
    printf 'read failed\n' >&2
    exit 1
  fi
  case ${GH_SCENARIO:-success} in
    empty-body)
      body=''
      ;;
    missing-section | combined)
      body=$'## Problem\nP\n## Evidence\nE\n## Expected\nX'
      ;;
    malformed-json)
      printf '{bad json\n'
      exit 0
      ;;
    *)
      body=$'## Problem\nP\n## Evidence\nE\n## Expected\nX\n## Proposed approach\nA'
      ;;
  esac
  title='Confirmed title'
  labels='[{"name":"bug"},{"name":"status:ready"}]'
  parent='{"number":42}'
  case ${GH_SCENARIO:-success} in
    wrong-title | combined) title='Observed title' ;;
    control-title) title=$'Observed\n::error::forged' ;;
  esac
  case ${GH_SCENARIO:-success} in
    missing-label | combined) labels='[{"name":"bug"}]' ;;
    malformed-label) labels='["bad"]' ;;
  esac
  case ${GH_SCENARIO:-success} in
    wrong-parent | combined) parent='{"number":41}' ;;
    malformed-parent) parent='"bad"' ;;
  esac
  host=github.com
  [[ ${GH_SCENARIO:-success} == ghes ]] && host=ghe.example.com
  [[ ${GH_SCENARIO:-success} == wrong-host ]] && host=ghe.example.com
  response_number=${GH_ISSUE_NUMBER:-101}
  [[ ${GH_SCENARIO:-success} == wrong-number ]] && response_number=102
  response_repo=example/repo
  [[ ${GH_SCENARIO:-success} == wrong-url ]] && response_repo=other/repo
  url_suffix=''
  [[ ${GH_SCENARIO:-success} == control-url ]] && url_suffix=$'\n::error::forged'
  jq -cn \
    --argjson number "$response_number" \
    --arg title "$title" \
    --arg body "$body" \
    --argjson labels "$labels" \
    --argjson parent "$parent" \
    --arg host "$host" \
    --arg response_repo "$response_repo" \
    --arg url_suffix "$url_suffix" \
    '{
      number:$number,
      title:$title,
      body:$body,
      labels:$labels,
      parent:$parent,
      state:"OPEN",
      url:("https://"+$host+"/"+$response_repo+"/issues/"+($number|tostring)+$url_suffix)
    }'
  exit 0
fi

printf 'unexpected gh call: %s\n' "$*" >&2
exit 2
FAKE_GH
chmod +x "$SCRATCH/bin/gh"

body_file="$SCRATCH/body.md"
cat >"$body_file" <<'BODY'
## Problem
P
## Evidence
E
## Expected
X
## Proposed approach
A
BODY

run_case() {
	local scenario=$1
	: >"$SCRATCH/calls"
	GH_SCENARIO=$scenario GH_CALL_LOG="$SCRATCH/calls" PATH="$SCRATCH/bin:$PATH" \
		"$helper" --repo example/repo --title 'Confirmed title' --body-file "$body_file" \
		--label bug --label status:ready --parent 42 >"$SCRATCH/stdout" 2>"$SCRATCH/stderr"
}

run_ordinary_case() {
	local scenario=$1
	: >"$SCRATCH/calls"
	GH_SCENARIO=$scenario GH_CALL_LOG="$SCRATCH/calls" PATH="$SCRATCH/bin:$PATH" \
		"$helper" --repo example/repo --title 'Confirmed title' --body-file "$body_file" \
		--label bug --label status:ready >"$SCRATCH/stdout" 2>"$SCRATCH/stderr"
}

if run_case success; then
	assert_contains 'https://github.com/example/repo/issues/101' "$SCRATCH/stdout"
	assert_count 1 '^issue create ' "$SCRATCH/calls"
	assert_count 1 '^issue view ' "$SCRATCH/calls"
	assert_contains '--body-file' "$SCRATCH/calls"
	[[ -s $body_file ]] || fail 'populated body file was not retained'
else
	fail 'success scenario failed'
fi

if run_case ghes; then
	assert_contains 'https://ghe.example.com/example/repo/issues/101' "$SCRATCH/stdout"
else
	fail 'GHES scenario failed'
fi

failure_scenarios=(
	empty-body missing-section malformed-json wrong-title missing-label wrong-parent
	malformed-label malformed-parent
)
for scenario in "${failure_scenarios[@]}"; do
	if run_case "$scenario"; then
		fail "$scenario unexpectedly passed"
	fi
	assert_contains 'https://github.com/example/repo/issues/101' "$SCRATCH/stderr"
	assert_count 1 '^issue create ' "$SCRATCH/calls"
	assert_count 1 '^issue view ' "$SCRATCH/calls"
done

if run_ordinary_case malformed-parent; then
	fail 'ordinary malformed parent unexpectedly passed'
fi
assert_contains 'https://github.com/example/repo/issues/101' "$SCRATCH/stderr"
assert_contains 'malformed or incomplete JSON' "$SCRATCH/stderr"

for scenario in wrong-host wrong-url wrong-number; do
	if run_case "$scenario"; then
		fail "$scenario unexpectedly passed"
	fi
	assert_contains 'https://github.com/example/repo/issues/101' "$SCRATCH/stderr"
	assert_count 1 '^issue create ' "$SCRATCH/calls"
	assert_count 1 '^issue view ' "$SCRATCH/calls"
done
run_case wrong-host || true
expected='url: expected "https://github.com/example/repo/issues/101",'
expected+=' observed "https://ghe.example.com/example/repo/issues/101"'
assert_contains "$expected" "$SCRATCH/stderr"
run_case wrong-url || true
expected='url: expected "https://github.com/example/repo/issues/101",'
expected+=' observed "https://github.com/other/repo/issues/101"'
assert_contains "$expected" "$SCRATCH/stderr"
run_case wrong-number || true
assert_contains 'number: expected #101, observed #102' "$SCRATCH/stderr"

if run_case wrong-create-host; then
	fail 'wrong create host unexpectedly passed'
fi
assert_contains 'does not match canonical repository URL' "$SCRATCH/stderr"
assert_count 0 '^issue view ' "$SCRATCH/calls"

if run_case create-error-with-url; then
	fail 'failed create with URL unexpectedly passed'
fi
assert_contains 'https://github.com/example/repo/issues/101' "$SCRATCH/stderr"
assert_contains 'creation command failed with exit 1; creation was not retried' "$SCRATCH/stderr"
assert_count 1 '^issue create ' "$SCRATCH/calls"
assert_count 0 '^issue view ' "$SCRATCH/calls"

if run_case control-title; then
	fail 'control-character title unexpectedly passed'
fi
assert_contains 'observed "Observed\n::error::forged"' "$SCRATCH/stderr"
if rg -n '^::error::forged$' "$SCRATCH/stderr" >/dev/null; then
	fail 'title control characters reached diagnostics'
fi

if run_case control-url; then
	fail 'control-character URL unexpectedly passed'
fi
expected='observed "https://github.com/example/repo/issues/101\n::error::forged"'
assert_contains "$expected" "$SCRATCH/stderr"
if rg -n '^::error::forged$' "$SCRATCH/stderr" >/dev/null; then
	fail 'URL control characters reached diagnostics'
fi

if run_case combined; then
	fail 'combined mismatch unexpectedly passed'
fi
assert_contains 'title: expected "Confirmed title", observed "Observed title"' "$SCRATCH/stderr"
assert_contains "body: missing section 'Proposed approach'" "$SCRATCH/stderr"
assert_contains 'label: missing "status:ready"' "$SCRATCH/stderr"
assert_contains 'parent: expected #42, observed #41' "$SCRATCH/stderr"

if run_case view-error; then
	fail 'view error unexpectedly passed'
fi
assert_contains 'https://github.com/example/repo/issues/101' "$SCRATCH/stderr"
assert_contains 'read-back failed' "$SCRATCH/stderr"
assert_count 1 '^issue create ' "$SCRATCH/calls"
assert_count 1 '^issue view ' "$SCRATCH/calls"

if run_case unresolved-create; then
	fail 'unresolved create unexpectedly passed'
fi
assert_contains 'durable issue URL could not be resolved' "$SCRATCH/stderr"
assert_count 1 '^issue create ' "$SCRATCH/calls"
assert_count 0 '^issue view ' "$SCRATCH/calls"

if "$helper" --repo example/repo --title 'Confirmed title' --body-file "$SCRATCH/missing" \
	>"$SCRATCH/stdout" 2>"$SCRATCH/stderr"; then
	fail 'missing body file unexpectedly passed'
fi
assert_contains 'body file must be a populated regular file' "$SCRATCH/stderr"

# Four SKILL.md phrase assertions and a forbidden-pattern scan stood here.
# Nothing automated in this repo asserts on prose: pinning a document's wording
# makes every improvement to it a test failure. The script's actual refusal to
# create an unverified issue is covered by the cases above, which is the
# behaviour that mattered.

: >"$SCRATCH/decompose-calls"
: >"$SCRATCH/decompose-report"
for entry in '101:success' '102:wrong-title' '103:success'; do
	issue_number=${entry%%:*}
	scenario=${entry#*:}
	if ! GH_ISSUE_NUMBER=$issue_number GH_SCENARIO=$scenario \
		GH_CALL_LOG="$SCRATCH/decompose-calls" PATH="$SCRATCH/bin:$PATH" \
		"$helper" --repo example/repo --title 'Confirmed title' --body-file "$body_file" \
		--label bug --label status:ready --parent 42 >>"$SCRATCH/decompose-report" 2>&1; then
		break
	fi
done
assert_count 2 '^issue create ' "$SCRATCH/decompose-calls"
assert_contains 'https://github.com/example/repo/issues/102' "$SCRATCH/decompose-report"
expected='title: expected "Confirmed title", observed "Observed title"'
assert_contains "$expected" "$SCRATCH/decompose-report"

# --- resolving the canonical repository URL ----------------------------------
# `target-url` reads a value, so the engine's stdout is that value and its
# stderr is not. The engine's reason for failing still has to reach the
# operator, so it is captured separately and named in the diagnostic rather than
# discarded -- which is what merging the streams and then dropping the value did.
if run_case target-url-error; then
	fail 'an unresolvable repository URL unexpectedly passed'
fi
assert_contains 'canonical repository URL could not be resolved' "$SCRATCH/stderr"
assert_contains 'HTTP 403 lookup denied' "$SCRATCH/stderr"
assert_count 0 '^issue create ' "$SCRATCH/calls"

# Nothing has been created when the resolution scratch file is allocated, so a
# host that cannot allocate one is an ordinary failure and says so. That is the
# opposite of the read-back scratch file below, whose every exit has a live
# issue behind it. The shim keys off an empty call log because this allocation
# precedes every `gh` call in the run, including the engine's own.
mkdir -p "$SCRATCH/mktemp-early-bin"
cat >"$SCRATCH/mktemp-early-bin/mktemp" <<STUB
#!/usr/bin/env bash
set -euo pipefail
if [[ ! -s \$GH_CALL_LOG ]]; then
	printf 'mktemp-stub: no usable temp directory\n' >&2
	exit 1
fi
exec $(command -v mktemp) "\$@"
STUB
chmod +x "$SCRATCH/mktemp-early-bin/mktemp"

: >"$SCRATCH/calls"
if GH_SCENARIO=success GH_CALL_LOG="$SCRATCH/calls" \
	PATH="$SCRATCH/mktemp-early-bin:$SCRATCH/bin:$PATH" \
	"$helper" --repo example/repo --title 'Confirmed title' --body-file "$body_file" \
	--label bug --label status:ready --parent 42 \
	>"$SCRATCH/stdout" 2>"$SCRATCH/stderr"; then
	fail 'an unallocatable resolution scratch file unexpectedly passed'
fi
assert_contains 'canonical repository URL could not be resolved' "$SCRATCH/stderr"
assert_contains 'no scratch file' "$SCRATCH/stderr"
assert_count 0 '^repo view ' "$SCRATCH/calls"
assert_count 0 '^issue create ' "$SCRATCH/calls"

# --- the read-back scratch file ----------------------------------------------
# Everything past the URL check has already created a live issue, so an exit
# that says nothing is the one outcome this script exists to prevent: the
# caller's remedy for a silent failure is the re-run that files a duplicate.
# Both halves of the scratch file could produce one -- an unguarded `mktemp`
# exiting on its own status, and an unguarded EXIT trap returning rm's -- and
# they end differently on purpose, which is what these two cases pin.
#
# The mktemp shim keys off the call log rather than a call count: tracker.sh
# allocates its own scratch file before every `gh` invocation, so a shim that
# simply failed would stop the run at the repository lookup and never reach the
# line under test. `issue create` in the log is the fixture's own marker that
# the write has happened and the next allocation is the helper's.
mkdir -p "$SCRATCH/mktemp-bin"
cat >"$SCRATCH/mktemp-bin/mktemp" <<STUB
#!/usr/bin/env bash
set -euo pipefail
if rg -q '^issue create ' "\$GH_CALL_LOG"; then
	printf 'mktemp-stub: no usable temp directory\n' >&2
	exit 1
fi
exec $(command -v mktemp) "\$@"
STUB
chmod +x "$SCRATCH/mktemp-bin/mktemp"

: >"$SCRATCH/calls"
if GH_SCENARIO=success GH_CALL_LOG="$SCRATCH/calls" \
	PATH="$SCRATCH/mktemp-bin:$SCRATCH/bin:$PATH" \
	"$helper" --repo example/repo --title 'Confirmed title' --body-file "$body_file" \
	--label bug --label status:ready --parent 42 \
	>"$SCRATCH/stdout" 2>"$SCRATCH/stderr"; then
	fail 'an unallocatable read-back scratch file unexpectedly passed'
fi
# The issue number is what proves the run got past creation: a diagnostic
# without it would mean the shim stopped the run somewhere harmless instead.
assert_contains 'https://github.com/example/repo/issues/101' "$SCRATCH/stderr"
assert_contains 'read-back could not be attempted' "$SCRATCH/stderr"
assert_contains 'creation was not retried' "$SCRATCH/stderr"
assert_count 1 '^issue create ' "$SCRATCH/calls"
assert_count 0 '^issue view ' "$SCRATCH/calls"

# The other half. The issue was created and every field verified, so a scratch
# file that will not go away has broken nothing -- and reporting it as a failure
# would invite the duplicate-creating re-run to reclaim a temp file. The path is
# named and the status stays 0. The shim removes the file for real before
# reporting failure, so a suite run leaks nothing into the per-user temp
# directory that a bare `mktemp` resolves through on macOS whatever TMPDIR says.
#
# It is also chatty, and that is the second thing this case pins. The shim
# covers every rm in the run, including the tracker engine's own scratch
# cleanup, whose line therefore lands on the engine's stderr during the
# repository lookup. While that lookup merged the engine's streams the line
# became part of the URL and the run died calling a repository that is fine
# malformed -- so a chatty shim reddened here before it ever reached the
# removal-status half below. A failing `rm` is only the cheapest way to make the
# engine talk; a gh release-update notice does it on a wholly successful call.
mkdir -p "$SCRATCH/rm-bin"
cat >"$SCRATCH/rm-bin/rm" <<STUB
#!/usr/bin/env bash
$(command -v rm) "\$@" || :
printf 'rm-stub: refusing to remove\n' >&2
exit 1
STUB
chmod +x "$SCRATCH/rm-bin/rm"

: >"$SCRATCH/calls"
GH_SCENARIO=success GH_CALL_LOG="$SCRATCH/calls" \
	PATH="$SCRATCH/rm-bin:$SCRATCH/bin:$PATH" \
	"$helper" --repo example/repo --title 'Confirmed title' --body-file "$body_file" \
	--label bug --label status:ready --parent 42 \
	>"$SCRATCH/stdout" 2>"$SCRATCH/stderr" ||
	fail 'a failed scratch removal turned a verified creation into a failure'
assert_contains 'https://github.com/example/repo/issues/101' "$SCRATCH/stdout"
assert_contains 'retained scratch path' "$SCRATCH/stderr"
if rg -q 'malformed or does not match' "$SCRATCH/stderr"; then
	fail 'a stray line on the engine stderr was read as the canonical repository URL'
fi

printf 'create-verified-issue-test: ok\n'
