#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(CDPATH='' cd -- "${BASH_SOURCE[0]%/*}" && pwd)
# shellcheck source=SCRIPTDIR/../../../scripts/test-fixture-helpers.sh
. "$SCRIPT_DIR/../../../scripts/test-fixture-helpers.sh"
clear_git_env
fixture_init refresh-merge-test
SCRATCH=$(CDPATH='' cd -P -- "$SCRATCH" && pwd)
SCRIPT="$SCRIPT_DIR/../../../skills/return-to-town/scripts/refresh-merge"
REAL_GIT=$(command -v git)
export REAL_GIT
mkdir -p "$SCRATCH/bin"
cat >"$SCRATCH/bin/git" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
case $1 in
remote)
 if [ "${2-}" = get-url ]; then
  printf '%s\n' "${TEST_ORIGIN:-https://github.com/acme/widgets.git}"
  exit 0
 fi ;;
fetch)
 advance=no
 case ${TEST_MODE:-} in
 contended) advance=yes ;;
 refresh|publish-uncertain|readback-fail|hook-check|claim-after-refresh)
  [ -f "$TEST_STATE/advanced" ] || advance=yes ;;
 esac
 if [ "$advance" = yes ]; then
  base=$("$REAL_GIT" --git-dir="$TEST_REMOTE" rev-parse refs/heads/main)
  tree=$("$REAL_GIT" --git-dir="$TEST_REMOTE" rev-parse "$base^{tree}")
  next=$(printf 'independent base\n' | "$REAL_GIT" -c user.name=Fixture -c user.email=fixture@example.invalid --git-dir="$TEST_REMOTE" commit-tree "$tree" -p "$base")
  "$REAL_GIT" --git-dir="$TEST_REMOTE" update-ref refs/heads/main "$next"
  touch "$TEST_STATE/advanced"
 fi ;;
merge)
 printf 'refresh\n' >>"$TEST_STATE/events" ;;
push)
 printf 'push\n' >>"$TEST_STATE/events" ;;
merge-base)
 [ "${TEST_MODE:-}" != ancestry-fault ] || exit 128 ;;
esac
exec "$REAL_GIT" "$@"
FAKE
cat >"$SCRATCH/bin/gh" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
head=$("$REAL_GIT" --git-dir="$TEST_REMOTE" rev-parse refs/heads/feat/test)
mode=${TEST_MODE:-good}
case $1:$2 in
pr:view)
 [ "$mode" != transport ] || exit 1
 if [ "$mode" = timeout ]; then printf '{"partial":'; exec sleep 20; fi
 [ "$mode" != changed-head ] || head=1111111111111111111111111111111111111111
 state=OPEN
 [ ! -f "$TEST_STATE/merged" ] || state=MERGED
 jq -n --arg head "$head" --arg state "$state" --argjson cross "$([ "$mode" = fork ] && printf true || printf false)" \
 '{number:42,state:$state,headRefName:"feat/test",baseRefName:"main",headRefOid:$head,isCrossRepository:$cross,author:{login:"author"},closingIssuesReferences:[{number:101,repository:{name:"widgets",owner:{login:"acme"}}}]}' ;;
pr:merge)
 printf 'merge\n' >>"$TEST_STATE/events"
 printf '%s\n' "$@" >"$TEST_STATE/merge-args"
 [ "$mode" != merge-uncertain ] || exit 1
 [ "$mode" != queued ] || exit 0
 touch "$TEST_STATE/merged" ;;
run:list)
 case $mode in
 no-runs|no-automation) printf '[]\n' ;;
 saturated) jq -n '[range(100)|{workflowName:"x",event:"pull_request",status:"completed",conclusion:"success"}]' ;;
 ci-fail) printf '[{"status":"completed","conclusion":"failure"}]\n' ;;
 ci-unknown) printf '[{"status":"completed","conclusion":"mystery"}]\n' ;;
 dynamic)
  if [ ! -f "$TEST_STATE/polled" ]; then
   touch "$TEST_STATE/polled"
   printf '[{"status":"in_progress","conclusion":null}]\n'
  else
   printf '[{"status":"completed","conclusion":"success"},{"status":"completed","conclusion":"failure"}]\n'
  fi ;;
 *) printf '[{"status":"completed","conclusion":"success"},{"status":"completed","conclusion":"skipped"}]\n' ;;
 esac ;;
issue:comment)
 shift 2
 while [ "$#" -gt 0 ]; do
  case $1 in --body-file) cp "$2" "$TEST_STATE/posted"; shift 2 ;; *) shift ;; esac
 done
 printf 'publish\n' >>"$TEST_STATE/events"
 printf 'https://github.com/acme/widgets/issues/101#issuecomment-73\n'
 [ "$mode" != publish-uncertain ] || exit 1 ;;
api:*)
 shift
 endpoint=''
 while [ "$#" -gt 0 ]; do
  case $1 in --hostname|--jq) shift 2 ;; --paginate|--slurp) shift ;; *) endpoint=$1; shift ;; esac
 done
 endpoint=${endpoint#/}
 case $endpoint in
 repos/acme/widgets/labels/quest-claim%2F101)
  [ "${GH_HOST:-}" = github.com ] || exit 98
  case $mode in
   foreign) printf 'q101-deadbeef;producer;1\n' ;;
   claim-after-refresh)
    if [ -f "$TEST_STATE/verified" ]; then printf 'q101-deadbeef;producer;1\n'
    else printf 'q101-12345678;producer;1\n'; fi ;;
   absent) printf 'gh: Not Found (HTTP 404)\n' >&2; exit 1 ;;
   *) printf 'q101-12345678;producer;1\n' ;;
  esac ;;
 repos/acme/widgets/issues/101/comments*)
  author=author
  original=$TEST_APPROVED
  [ "$mode" != forged ] || author=outsider
  [ "$mode" != stale-handshake ] || original=1111111111111111111111111111111111111111
  jq -n --arg sha "$original" --arg author "$author" --rawfile posted "$TEST_STATE/posted" \
   '[[{id:1,user:{login:$author},body:("<!-- WORK:TRAJECTORY -->\nMERGE-READY: #42 @ "+$sha+"\n<!-- TRAJECTORY:COMPLETE -->")}]+(if $posted=="" then [] else [{id:73,user:{login:"maintainer"},body:$posted}] end)]' ;;
 repos/acme/widgets/issues/comments/73)
  [ "$mode" != readback-fail ] || exit 1
  jq -n --rawfile body "$TEST_STATE/posted" '{body:$body,user:{login:"maintainer"}}' ;;
 repos/acme/widgets/issues/101) printf '{"number":101,"html_url":"https://github.com/acme/widgets/issues/101"}\n' ;;
 repos/acme/widgets/collaborators/*/permission)
  case $endpoint in */outsider/*) printf '{"permission":"read"}\n' ;; *) printf '{"permission":"write"}\n' ;; esac ;;
 repos/acme/widgets/commits/*/check-runs*)
  if [ "$mode" = check-fail ]; then printf '[{"total_count":1,"check_runs":[{"id":1,"status":"completed","conclusion":"failure"}]}]\n'
  else printf '[{"total_count":0,"check_runs":[]}]\n'; fi ;;
 repos/acme/widgets/commits/*/status*)
  if [ "$mode" = status-fail ]; then printf '[{"total_count":1,"statuses":[{"context":"external","state":"error"}]}]\n'
  else printf '[{"total_count":0,"statuses":[]}]\n'; fi ;;
 repos/acme/widgets/actions/workflows*)
  if [ "$mode" = no-automation ]; then printf '[{"total_count":0,"workflows":[]}]\n'
  else printf '[{"total_count":1,"workflows":[{"id":1}]}]\n'; fi ;;
 user) printf '{"login":"maintainer"}\n' ;;
 *) printf 'unexpected fake endpoint %s\n' "$endpoint" >&2; exit 97 ;;
 esac ;;
*) printf 'unexpected fake gh\n' >&2; exit 97 ;;
esac
FAKE
cat >"$SCRATCH/bin/sleep" <<'FAKE'
#!/usr/bin/env bash
# The fixture removes only the helper's between-snapshot backoff, not call bounds.
[ "$1" != 5 ] || exit 0
exec /bin/sleep "$@"
FAKE
chmod +x "$SCRATCH/bin/"*
case_number=0
new_case() {
	case_number=$((case_number + 1))
	CASE="$SCRATCH/case-$case_number"
	mkdir -p "$CASE/private" "$CASE/state"
	chmod 700 "$CASE/private"
	export TEST_STATE="$CASE/state" TEST_REMOTE="$CASE/remote.git" TEST_MODE=good
	: >"$TEST_STATE/events"
	: >"$TEST_STATE/posted"
	git init -q --bare "$TEST_REMOTE"
	git init -q -b main "$CASE/work"
	git -C "$CASE/work" config user.name Fixture
	git -C "$CASE/work" config user.email fixture@example.invalid
	printf 'base\n' >"$CASE/work/base"
	git -C "$CASE/work" add base
	git -C "$CASE/work" commit -qm base
	git -C "$CASE/work" remote add origin "$TEST_REMOTE"
	git -C "$CASE/work" push -q origin main
	git -C "$CASE/work" checkout -qb feat/test
	printf 'feature\n' >"$CASE/work/feature"
	git -C "$CASE/work" add feature
	git -C "$CASE/work" commit -qm feature
	git -C "$CASE/work" push -q origin feat/test
	TEST_APPROVED=$(git -C "$CASE/work" rev-parse HEAD)
	export TEST_APPROVED
	cat >"$CASE/verify" <<'VERIFY'
#!/usr/bin/env bash
printf 'verified\n' >>"$TEST_STATE/events"
touch "$TEST_STATE/verified"
VERIFY
	chmod +x "$CASE/verify"
	jq -n --arg work "$CASE/work" --arg head "$TEST_APPROVED" --arg verify "$CASE/verify" \
		'{format:"refresh-merge-v1",repo:"acme/widgets",issue:101,pr:42,branch:"feat/test",base:"main",worktree:$work,approved_head:$head,
		authority:{role:"campaign-root",merge_grant:"explicit finite merge grant",ownership:"observed ended worker and reclaimed checkout",scope_check:"current scope and eligible row",assignment_check:"complete snapshot; no assignments"},
		assignments:{numbered:[],versions:[]},merge_method:"merge",regenerate:[],generated_paths:[],verification:{mode:"command",argv:[$verify],hook_path:"",hook_blob:""},deadline_seconds:120,
		state:{phase:"ready",head:$head,failures:[],observations:[],lineage:[],handshake_url:""}}' >"$CASE/private/context"
	chmod 600 "$CASE/private/context"
}
mutate_context() {
	jq "$1" "$CASE/private/context" >"$CASE/private/next"
	chmod 600 "$CASE/private/next"
	mv "$CASE/private/next" "$CASE/private/context"
}
run_case() {
	local expected=$1 rc=0
	(
		cd "$CASE/work"
		PATH="$SCRATCH/bin:$PATH" GH_HOST=untrusted.example \
			bash "$SCRIPT" --claim-token q101-12345678 --context "$CASE/private/context"
	) \
		>"$TEST_STATE/out" 2>"$TEST_STATE/err" || rc=$?
	if [ "$rc" -ne "$expected" ]; then
		cat "$TEST_STATE/err" >&2
		cat "$TEST_STATE/out" >&2
		fail "case $case_number ($TEST_MODE): expected $expected got $rc"
	fi
	jq -e 'type=="object" and (.reason|type)=="string"' "$TEST_STATE/out" >/dev/null
}
no_writes() { [ ! -s "$TEST_STATE/events" ] || fail 'unexpected mutation'; }
# A successful generic fetch may leave a base tracking ref stale in a consumer
# checkout. The actual gate must fetch its selected base despite this config.
new_case
prior_base=$(git -C "$CASE/work" rev-parse origin/main)
git -C "$CASE/work" config remote.origin.fetch '+refs/heads/feat/test:refs/remotes/origin/feat/test'
tree=$(git -C "$CASE/work" rev-parse "$prior_base^{tree}")
next=$(printf 'independent base\n' | git -C "$CASE/work" commit-tree "$tree" -p "$prior_base")
git -C "$CASE/work" push -q origin "$next:refs/heads/main"
[ "$(git -C "$CASE/work" rev-parse origin/main)" = "$prior_base" ] || fail 'fixture did not retain stale base'
run_case 0
[ "$(cat "$TEST_STATE/events")" = "$(printf 'refresh\nverified\npush\npublish\nmerge')" ] || fail 'narrow fetch skipped current base'
[ "$(git -C "$CASE/work" rev-parse origin/main)" = "$next" ] || fail 'selected base was not refreshed'
new_case
run_case 0
[ "$(cat "$TEST_STATE/events")" = merge ] || fail 'ordinary merge path'
[ "$(cat "$TEST_STATE/merge-args")" = "$(printf 'pr\nmerge\n42\n--repo\ngithub.com/acme/widgets\n--merge\n--match-head-commit\n%s' "$TEST_APPROVED")" ] || fail 'guarded arguments'
for mode in ci-fail ci-unknown saturated dynamic check-fail status-fail no-runs forged stale-handshake changed-head fork ancestry-fault foreign absent transport; do
	new_case
	export TEST_MODE=$mode
	case $mode in foreign) expected=6 ;; absent) expected=2 ;; transport | ancestry-fault) expected=4 ;; *) expected=1 ;; esac
	run_case "$expected"
	no_writes
	if [ "$mode" = ancestry-fault ]; then jq -e '.state.failures|length==0' "$CASE/private/context" >/dev/null; fi
done
new_case
export TEST_MODE=no-automation
run_case 0
new_case
export TEST_MODE=timeout
mutate_context '.deadline_seconds=1'
run_case 4
no_writes
new_case
export TEST_MODE=refresh
run_case 0
[ "$(cat "$TEST_STATE/events")" = "$(printf 'refresh\nverified\npush\npublish\nmerge')" ] || fail 'complete refresh route'
jq -e '.state.phase=="merged" and (.state.failures|length)==1 and (.state.lineage|length)==1' "$CASE/private/context" >/dev/null
for mode in publish-uncertain readback-fail merge-uncertain queued claim-after-refresh; do
	new_case
	export TEST_MODE=$mode
	expected=5
	[ "$mode" != claim-after-refresh ] || expected=6
	run_case "$expected"
	cp "$TEST_STATE/events" "$TEST_STATE/prior"
	run_case 1
	cmp "$TEST_STATE/prior" "$TEST_STATE/events"
done
for edit in '.authority.merge_grant=""' '.extra=true' '.state.phase="refresh-pending"' '.state.failures=[.state.head]' '.regenerate=[["echo","bad\narg"]]' '.generated_paths=["../foreign"]'; do
	new_case
	mutate_context "$edit"
	run_case 1
	no_writes
done
new_case
chmod 644 "$CASE/private/context"
run_case 1
no_writes
new_case
mv "$CASE/private/context" "$CASE/private/real"
ln -s real "$CASE/private/context"
run_case 1
no_writes
new_case
export TEST_MODE=contended
run_case 1
[ "$(rg --no-config -c '^refresh$' "$TEST_STATE/events")" = 2 ] || fail 'two refresh limit'
[ "$(rg --no-config -c '^push$' "$TEST_STATE/events")" = 2 ] || fail 'two pushes'
jq -e '.state.failures|length==3' "$CASE/private/context" >/dev/null
cp "$TEST_STATE/events" "$TEST_STATE/prior"
run_case 1
cmp "$TEST_STATE/prior" "$TEST_STATE/events"
# A repeated proven miss records another observation, not another refresh grant.
new_case
base=$(git -C "$CASE/work" rev-parse origin/main)
tree=$(git -C "$CASE/work" rev-parse "$base^{tree}")
next=$(printf 'moved base\n' | git -C "$CASE/work" commit-tree "$tree" -p "$base")
git -C "$CASE/work" push -q origin "$next:refs/heads/main"
mutate_context ".state.failures=[.state.head] | .state.observations=[{head:.state.head,base:\"$next\",exit:1}]"
run_case 1
no_writes
jq -e '(.state.failures|length)==1 and (.state.observations|length)==2' "$CASE/private/context" >/dev/null
# Fresh base assignments are checked before a cleanly mergeable refresh.
new_case
git -C "$CASE/work" checkout -q main
mkdir -p "$CASE/work/docs/adr"
printf 'record\n' >"$CASE/work/docs/adr/0042-other.md"
git -C "$CASE/work" add docs/adr/0042-other.md
git -C "$CASE/work" commit -qm record
git -C "$CASE/work" push -q origin main
git -C "$CASE/work" checkout -q feat/test
mutate_context '.assignments.numbered=[{path:"docs/adr/0042-own.md",value:"0042",directory:"docs/adr",separator:"-",suffix:".md"}]'
run_case 1
no_writes
new_case
printf '{"version":"3.0.0"}\n' >"$CASE/work/version.json"
git -C "$CASE/work" add version.json
git -C "$CASE/work" commit -qm version
git -C "$CASE/work" push -q origin feat/test
TEST_APPROVED=$(git -C "$CASE/work" rev-parse HEAD)
export TEST_APPROVED
mutate_context ".approved_head=\"$TEST_APPROVED\" | .state.head=\"$TEST_APPROVED\" | .assignments.versions=[{path:\"version.json\",value:\"3.0.0\"}]"
git -C "$CASE/work" checkout -q main
printf '{"version":"4.0.0"}\n' >"$CASE/work/version.json"
git -C "$CASE/work" add version.json
git -C "$CASE/work" commit -qm later-version
git -C "$CASE/work" push -q origin main
git -C "$CASE/work" checkout -q feat/test
run_case 1
no_writes
# The attested managed hook supplies verification exactly once; no command duplicate.
new_case
export TEST_MODE=hook-check
hook="$CASE/work/.git/hooks/pre-push"
cp "$CASE/verify" "$hook"
chmod +x "$hook"
blob=$(git hash-object "$hook")
mutate_context ".verification={mode:\"push-hook\",argv:[],hook_path:\"$hook\",hook_blob:\"$blob\"}"
run_case 0
[ "$(cat "$TEST_STATE/events")" = "$(printf 'refresh\npush\nverified\npublish\nmerge')" ] || fail 'single hook verification owner'
new_case
export TEST_MODE=hook-check
mutate_context '.verification={mode:"push-hook",argv:[],hook_path:"/nonexistent/pre-push",hook_blob:"1111111111111111111111111111111111111111"}'
run_case 1
no_writes
printf 'refresh-merge boundary cases: %s passed\n' "$case_number"
