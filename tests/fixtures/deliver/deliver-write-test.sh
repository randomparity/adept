#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(CDPATH='' cd -- "${BASH_SOURCE[0]%/*}" && pwd)
# shellcheck source=SCRIPTDIR/../../../scripts/test-fixture-helpers.sh
. "$SCRIPT_DIR/../../../scripts/test-fixture-helpers.sh"
clear_git_env
fixture_init deliver-write-test
SCRIPT="$SCRIPT_DIR/../../../skills/deliver/scripts/deliver-write"
mkdir -p "$SCRATCH/bin" "$SCRATCH/state"
export FAKE_STATE="$SCRATCH/state"
REAL_GIT=$(command -v git)
export REAL_GIT
export EXPECTED_TOKEN=q101-12345678
printf 'body\n' >"$SCRATCH/body"
cat >"$SCRATCH/bin/git" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
case $1 in
rev-parse) printf 'GIT_DIR\n' ;;
symbolic-ref) printf '%s\n' "${LOCAL_BRANCH:-feat/claim-101}" ;;
remote) printf '%s\n' "${ORIGIN_URL:-https://github.com/acme/widgets.git}" ;;
push) printf 'push\n' >>"$FAKE_STATE/writes" ;;
*) exec "$REAL_GIT" "$@" ;;
esac
FAKE
cat >"$SCRATCH/bin/gh" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
printf 'gh\n' >>"$FAKE_STATE/calls"
case $1:$2 in
api:repos/acme/widgets/labels/quest-claim%2F101)
 printf '%s\n' "${GH_HOST:-}" >"$FAKE_STATE/claim-host"
 case ${CLAIM_MODE:-held} in
 held) printf '%s;producer;1\n' "$EXPECTED_TOKEN" ;;
 foreign) printf 'foreign-token;producer;1\n' ;;
 malformed) printf 'bad;description\n' ;;
 absent) printf 'gh: Not Found (HTTP 404)\n' >&2; exit 1 ;;
 transport) printf 'gh: unavailable (HTTP 502)\n' >&2; exit 1 ;;
 esac ;;
pr:view)
 [ "${HANG_READ:-0}" -eq 0 ] || exec sleep 20
 jq -n --argjson issue "${CLOSING_ISSUE:-101}" --arg name "${CLOSING_REPO_NAME:-widgets}" '{number:42,headRefName:"feat/claim-101",isCrossRepository:false,closingIssuesReferences:[{number:$issue,repository:{name:$name,owner:{login:"acme"}}}]}' ;;
pr:create | pr:edit)
 if [ "${HANG_WRITE:-0}" -eq 1 ]; then printf partial; exec sleep 20; fi
 printf '%s\n' "$2" >>"$FAKE_STATE/writes"
 printf 'https://github.com/acme/widgets/pull/42\n' ;;
*) exit 97 ;;
esac
FAKE
chmod +x "$SCRATCH/bin/git" "$SCRATCH/bin/gh"
run_case() {
	local expected=$1 wanted=$2 rc=0
	shift 2
	: >"$FAKE_STATE/writes"
	: >"$FAKE_STATE/calls"
	(
		cd "$SCRATCH"
		PATH="$SCRATCH/bin:$PATH" GH_HOST=enterprise.example \
			bash "$SCRIPT" --claim-token "$EXPECTED_TOKEN" acme/widgets 101 "$@"
	) \
		>"$FAKE_STATE/out" 2>"$FAKE_STATE/err" || rc=$?
	[ "$rc" -eq "$expected" ] || {
		cat "$FAKE_STATE/err" >&2
		printf 'expected%s got%s\n' "$expected" "$rc" >&2
		exit 1
	}
	[ "$(cat "$FAKE_STATE/writes")" = "$wanted" ] || {
		printf 'unexpected writes\n' >&2
		exit 1
	}
}
run_case 0 push push
[ "$(cat "$FAKE_STATE/claim-host")" = github.com ]
run_case 0 create pr-create main title "$SCRATCH/body"
run_case 0 edit pr-edit 42 "$SCRATCH/body"
for mode in absent foreign malformed transport; do
	export CLAIM_MODE=$mode
	case $mode in absent) expected=2 ;; transport) expected=4 ;; *) expected=6 ;; esac
	run_case "$expected" '' push
	run_case "$expected" '' pr-create main title "$SCRATCH/body"
	run_case "$expected" '' pr-edit 42 "$SCRATCH/body"
	[ -s "$FAKE_STATE/err" ]
done
unset CLAIM_MODE
LOCAL_BRANCH=main run_case 1 '' push
ORIGIN_URL=$'https://github.com/acme/widgets.git\nhttps://github.com/other/repo.git' run_case 1 '' push
ORIGIN_URL=https://github.com/other/repo.git run_case 1 '' push
CLOSING_ISSUE=999 run_case 1 '' pr-edit 42 "$SCRATCH/body"
CLOSING_REPO_NAME=other run_case 1 '' pr-edit 42 "$SCRATCH/body"
run_case 1 '' push --no-verify
run_case 1 '' unsupported
EXPECTED_TOKEN=q999-12345678 run_case 1 '' push
[ ! -s "$FAKE_STATE/calls" ]
invalid_cli() {
	local rc=0
	: >"$FAKE_STATE/writes"
	: >"$FAKE_STATE/calls"
	(
		cd "$SCRATCH"
		PATH="$SCRATCH/bin:$PATH" bash "$SCRIPT" "$@"
	) \
		>"$FAKE_STATE/out" 2>"$FAKE_STATE/err" || rc=$?
	[ "$rc" -eq 1 ] && [ ! -s "$FAKE_STATE/calls" ] && [ ! -s "$FAKE_STATE/writes" ]
}
invalid_cli acme/widgets 101 push
invalid_cli --claim-token
invalid_cli --claim-token '' acme/widgets 101 push
invalid_cli --claim-token q101-1234567g acme/widgets 101 push
invalid_cli --claim-token q101-12345678 acme/widgets 0 push
# Exercise real bounds in an isolated coherent bundle with shortened test constants.
mkdir -p "$SCRATCH/plugin/skills/deliver/scripts" "$SCRATCH/plugin/skills/quest-log"
cp "$SCRIPT" "$SCRATCH/plugin/skills/deliver/scripts/deliver-write"
cp -R "$SCRIPT_DIR/../../../skills/quest-log/assets" "$SCRATCH/plugin/skills/quest-log/"
sed -i.bak -e 's/run_gh 30 /run_gh 1 /' -e 's/run_gh 120 /run_gh 1 /' "$SCRATCH/plugin/skills/deliver/scripts/deliver-write"
original_script=$SCRIPT
SCRIPT="$SCRATCH/plugin/skills/deliver/scripts/deliver-write"
HANG_READ=1 run_case 1 '' pr-edit 42 "$SCRATCH/body"
rg --no-config -q 'exceeded 1s bound' "$FAKE_STATE/err"
HANG_WRITE=1 run_case 5 '' pr-create main title "$SCRATCH/body"
[ ! -s "$FAKE_STATE/out" ]
rg --no-config -q 'may have landed' "$FAKE_STATE/err"
SCRIPT=$original_script
# Preserve a prior valid push while the next independently gated phase refuses.
run_case 0 push push
export CLAIM_MODE=foreign
rc=0
(
	cd "$SCRATCH"
	PATH="$SCRATCH/bin:$PATH" bash "$SCRIPT" --claim-token "$EXPECTED_TOKEN" acme/widgets 101 pr-create main title "$SCRATCH/body"
) >"$FAKE_STATE/out" 2>"$FAKE_STATE/err" || rc=$?
[ "$rc" -eq 6 ] && [ "$(cat "$FAKE_STATE/writes")" = push ]
printf 'delivery selected-write contracts passed\n'
