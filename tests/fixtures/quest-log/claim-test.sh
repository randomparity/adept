#!/usr/bin/env bash
set -euo pipefail

# Adversarial suite for the quest-claim tracker operations. A stateful stub
# gh stands in for GitHub: its label store is a fixture directory where
# create is mkdir -- atomic, failing on existence, the fixture's stand-in
# for the server-side unique-name constraint ADR 0018 probes live.
unset RIPGREP_CONFIG_PATH

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=SCRIPTDIR/../../../scripts/test-fixture-helpers.sh
. "$script_dir/../../../scripts/test-fixture-helpers.sh"

clear_git_env

source_dir=$(cd -- "$script_dir/../../../skills/quest-log/assets" && pwd -P)
fixture_init claim-test
sandbox=$(cd -- "$SCRATCH" && pwd -P)

assets="$sandbox/assets"
mkdir -p "$assets/profiles"
cp "$source_dir/tracker.sh" "$assets/tracker.sh"
cp "$source_dir/profiles/github.sh" "$assets/profiles/github.sh"
chmod +x "$assets/tracker.sh"
tracker="$assets/tracker.sh"

# --- stub gh ---------------------------------------------------------------
# The store is $GH_STORE/<label-name>/description. mkdir is the CAS. All
# claim ops go through it, so concurrent cases exercise real interleavings.
mkdir -p "$sandbox/bin"
cat >"$sandbox/bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" >>"$GH_CALL_LOG"
printf '\n' >>"$GH_CALL_LOG"
if [[ $1 == label && $2 == create ]]; then
	name=$3
	shift 3
	desc=''
	while (($#)); do
		case $1 in
		--description)
			desc=$2
			shift 2
			;;
		*) shift ;;
		esac
	done
	case ${GH_FAIL:-} in
	rate)
		printf 'gh: API rate limit exceeded for user ID 1 (HTTP 429)\n' >&2
		exit 1
		;;
	validation)
		printf 'HTTP 422: Validation Failed: name is invalid\n' >&2
		exit 1
		;;
	server)
		printf 'gh: HTTP 500 Internal Server Error\n' >&2
		exit 1
		;;
	esac
	if mkdir "$GH_STORE/$name" 2>/dev/null; then
		printf '%s' "$desc" >"$GH_STORE/$name/description"
		printf 'Created label %s\n' "$name"
		exit 0
	fi
	printf 'HTTP 422: Validation Failed: already exists\n' >&2
	exit 1
fi
if [[ $1 == label && $2 == delete ]]; then
	name=$3
	if [[ -d $GH_STORE/$name ]]; then
		rm -rf "${GH_STORE:?}/$name"
		exit 0
	fi
	printf 'gh: Not Found (HTTP 404)\n' >&2
	exit 1
fi
if [[ $1 == api ]]; then
	if [[ ${GH_FAIL:-} == rate ]]; then
		printf 'gh: API rate limit exceeded for user ID 1 (HTTP 429)\n' >&2
		exit 1
	fi
	path=$2
	case $path in
	repos/*/labels/quest-claim%2F*)
		# gh --jq '.description // ""' prints the raw string; mimic that.
		enc=${path##*/}
		n=${enc#quest-claim%2F}
		if [[ -f $GH_STORE/quest-claim/$n/description ]]; then
			cat "$GH_STORE/quest-claim/$n/description"
			printf '\n'
			exit 0
		fi
		printf '{"message":"Not Found","status":"404"}gh: Not Found (HTTP 404)\n' >&2
		exit 1
		;;
	repos/*/labels\?*)
		# gh applies --jq per page: mimic its post-filter output -- one
		# compact object per line, digit-suffixed claim labels only.
		for dir in "$GH_STORE"/quest-claim/*/; do
			[[ -d $dir ]] || continue
			n=${dir%/}
			n=${n##*/}
			[[ $n =~ ^[0123456789]+$ ]] || continue
			desc=$(cat "$dir/description")
			jq -nc --arg name "quest-claim/$n" --arg description "$desc" \
				'{name:$name,description:$description}'
		done
		exit 0
		;;
	esac
fi
printf 'stub gh: unhandled: %s\n' "$*" >&2
exit 1
FAKE_GH
chmod +x "$sandbox/bin/gh"

assert_exit() {
	local expected=$1 actual=$2 label=$3
	[[ $actual == "$expected" ]] ||
		fail "$label: expected exit $expected, got $actual"
}

new_store() {
	rm -rf "${GH_STORE:?}"
	mkdir -p "$GH_STORE"
}

seed_claim() { # issue token producer epoch
	mkdir -p "$GH_STORE/quest-claim/$1"
	printf '%s;%s;%s' "$2" "$3" "$4" >"$GH_STORE/quest-claim/$1/description"
}

export GH_STORE="$sandbox/store"
export GH_CALL_LOG="$sandbox/calls"
export PATH="$sandbox/bin:$PATH"
# The stub reads GH_FAIL; the export attribute sticks to later assignments.
export GH_FAIL=''
now=$(date -u +%s)

run() { # op args... -- runs the tracker, captures status in RUN_STATUS
	RUN_STATUS=0
	"$tracker" "$@" >"$sandbox/out" 2>"$sandbox/err" || RUN_STATUS=$?
}

# --- acquire / verify / release basics --------------------------------------
new_store
run claim-acquire --profile github --target example/repo 101 \
	--token q101-aaaaaaaa --producer alice
assert_exit 0 "$RUN_STATUS" 'acquire on empty store'
jq -e '.claimed == true and .token == "q101-aaaaaaaa"' \
	>"$sandbox/jq-out" <"$sandbox/out" || fail 'acquire payload wrong'

run claim-verify --profile github --target example/repo 101 --token q101-aaaaaaaa
assert_exit 0 "$RUN_STATUS" 'verify held'
jq -e '.held == true and (.age_seconds | type == "number" and . >= 0)' \
	>"$sandbox/jq-out" <"$sandbox/out" || fail 'verify payload wrong'

run claim-verify --profile github --target example/repo 101 --token q101-bbbbbbbb
assert_exit 6 "$RUN_STATUS" 'verify foreign token'
jq -e '.error == "conflict" and .holder.token == "q101-aaaaaaaa"' \
	>"$sandbox/jq-out" <"$sandbox/err" || fail 'conflict payload wrong'

run claim-release --profile github --target example/repo 101 --token q101-bbbbbbbb
assert_exit 6 "$RUN_STATUS" 'release with foreign token refused'
[[ -d $GH_STORE/quest-claim/101 ]] || fail 'foreign release deleted the claim'

run claim-release --profile github --target example/repo 101 --token q101-aaaaaaaa
assert_exit 0 "$RUN_STATUS" 'owner release'
[[ ! -d $GH_STORE/quest-claim/101 ]] || fail 'owner release left the claim'

run claim-release --profile github --target example/repo 101 --token q101-aaaaaaaa
assert_exit 0 "$RUN_STATUS" 'release absent is idempotent'

run claim-verify --profile github --target example/repo 101 --token q101-aaaaaaaa
assert_exit 2 "$RUN_STATUS" 'verify absent exits 2'

# --- self-recovery after a lost create response ------------------------------
new_store
seed_claim 101 q101-aaaaaaaa alice "$now"
run claim-acquire --profile github --target example/repo 101 \
	--token q101-aaaaaaaa --producer alice
assert_exit 0 "$RUN_STATUS" 'self-recovery acquire'
jq -e '.recovered == "self"' >"$sandbox/jq-out" <"$sandbox/out" ||
	fail 'self-recovery not reported'

# --- simultaneous claims: K=10 rounds ----------------------------------------
for round in 1 2 3 4 5 6 7 8 9 10; do
	new_store
	"$tracker" claim-acquire --profile github --target example/repo 101 \
		--token q101-aaaaaaaa --producer alice \
		>"$sandbox/outA" 2>"$sandbox/errA" &
	pA=$!
	"$tracker" claim-acquire --profile github --target example/repo 101 \
		--token q101-bbbbbbbb --producer bob \
		>"$sandbox/outB" 2>"$sandbox/errB" &
	pB=$!
	sA=0 sB=0
	wait "$pA" || sA=$?
	wait "$pB" || sB=$?
	case "$sA:$sB" in
	0:6)
		winner=q101-aaaaaaaa
		loser=q101-bbbbbbbb
		;;
	6:0)
		winner=q101-bbbbbbbb
		loser=q101-aaaaaaaa
		;;
	*) fail "round $round: exits $sA:$sB, expected one 0 and one 6" ;;
	esac
	[[ -f $GH_STORE/quest-claim/101/description ]] ||
		fail "round $round: no claim at rest"
	stored=$(cat "$GH_STORE/quest-claim/101/description")
	case $stored in
	"$winner"\;*) ;;
	*) fail "round $round: store holds '$stored', winner was $winner" ;;
	esac
	run claim-verify --profile github --target example/repo 101 --token "$winner"
	assert_exit 0 "$RUN_STATUS" "round $round: winner verifies held"
	run claim-verify --profile github --target example/repo 101 --token "$loser"
	assert_exit 6 "$RUN_STATUS" "round $round: loser verifies foreign"
done

# --- staleness and recovery ---------------------------------------------------
new_store
seed_claim 101 q101-0ld0ld0 alice "$((now - 100000))"
run claim-recover --profile github --target example/repo 101 \
	--token q101-n3wn3w --producer bob --older-than 60
assert_exit 0 "$RUN_STATUS" 'stale recovery'
stored=$(cat "$GH_STORE/quest-claim/101/description")
case $stored in
q101-n3wn3w\;bob\;*) ;;
*) fail "recovery stored '$stored'" ;;
esac

new_store
seed_claim 101 q101-y0ung00 alice "$now"
run claim-recover --profile github --target example/repo 101 \
	--token q101-n3wn3w --producer bob --older-than 60
assert_exit 6 "$RUN_STATUS" 'young claim refuses --older-than'
stored=$(cat "$GH_STORE/quest-claim/101/description")
case $stored in
q101-y0ung00\;*) ;;
*) fail 'refused recovery clobbered the live claim' ;;
esac
run claim-recover --profile github --target example/repo 101 \
	--token q101-n3wn3w --producer bob --force
assert_exit 0 "$RUN_STATUS" '--force overrides a live claim'

new_store
run claim-recover --profile github --target example/repo 101 \
	--token q101-n3wn3w --producer bob --older-than 60
assert_exit 0 "$RUN_STATUS" 'recover of absent claim creates'

# --- concurrent recoverers: K=10 rounds ---------------------------------------
for round in 1 2 3 4 5 6 7 8 9 10; do
	new_store
	seed_claim 101 q101-0ld0ld0 alice "$((now - 100000))"
	"$tracker" claim-recover --profile github --target example/repo 101 \
		--token q101-aaaaaaaa --producer alice --older-than 60 \
		>"$sandbox/outA" 2>"$sandbox/errA" &
	pA=$!
	"$tracker" claim-recover --profile github --target example/repo 101 \
		--token q101-bbbbbbbb --producer bob --older-than 60 \
		>"$sandbox/outB" 2>"$sandbox/errB" &
	pB=$!
	wait "$pA" || true
	wait "$pB" || true
	[[ -f $GH_STORE/quest-claim/101/description ]] ||
		fail "recover round $round: no claim at rest"
	stored=$(cat "$GH_STORE/quest-claim/101/description")
	owner=
	case $stored in
	q101-aaaaaaaa\;*)
		owner=q101-aaaaaaaa
		loser=q101-bbbbbbbb
		;;
	q101-bbbbbbbb\;*)
		owner=q101-bbbbbbbb
		loser=q101-aaaaaaaa
		;;
	*) fail "recover round $round: store holds '$stored'" ;;
	esac
	run claim-verify --profile github --target example/repo 101 --token "$owner"
	assert_exit 0 "$RUN_STATUS" "recover round $round: owner verifies held"
	run claim-verify --profile github --target example/repo 101 --token "$loser"
	[[ $RUN_STATUS == 2 || $RUN_STATUS == 6 ]] ||
		fail "recover round $round: displaced verify exited $RUN_STATUS"
done

# --- malformed descriptions ----------------------------------------------------
new_store
mkdir -p "$GH_STORE/quest-claim/101"
printf 'not-a-claim' >"$GH_STORE/quest-claim/101/description"
run claim-verify --profile github --target example/repo 101 --token q101-aaaaaaaa
assert_exit 6 "$RUN_STATUS" 'malformed verify is foreign, never held'
run claim-recover --profile github --target example/repo 101 \
	--token q101-aaaaaaaa --producer alice --older-than 1
assert_exit 6 "$RUN_STATUS" 'malformed refuses --older-than at any age'
run claim-recover --profile github --target example/repo 101 \
	--token q101-aaaaaaaa --producer alice --force
assert_exit 0 "$RUN_STATUS" 'malformed yields to --force'

# --- failure-mode classification ------------------------------------------------
new_store
GH_FAIL=validation
run claim-acquire --profile github --target example/repo 101 \
	--token q101-aaaaaaaa --producer alice
[[ $RUN_STATUS != 6 && $RUN_STATUS != 0 ]] ||
	fail "validation 422 classified as $RUN_STATUS"
GH_FAIL=rate
run claim-acquire --profile github --target example/repo 101 \
	--token q101-aaaaaaaa --producer alice
assert_exit 4 "$RUN_STATUS" 'rate limit is transport, never conflict'
GH_FAIL=server
run claim-acquire --profile github --target example/repo 101 \
	--token q101-aaaaaaaa --producer alice
assert_exit 4 "$RUN_STATUS" 'server 500 is transport, never conflict'
GH_FAIL=

# --- recover partial: delete landed, create failed -------------------------------
new_store
seed_claim 101 q101-0ld0ld0 alice "$((now - 100000))"
GH_FAIL=server
run claim-recover --profile github --target example/repo 101 \
	--token q101-n3wn3w --producer bob --older-than 60
assert_exit 5 "$RUN_STATUS" 'recover partial exits 5'
jq -e '.error == "partial" and .partial.stage == "create"' \
	>"$sandbox/jq-out" <"$sandbox/err" || fail 'recover partial payload wrong'
[[ ! -d $GH_STORE/quest-claim/101 ]] || fail 'partial left the old claim'
GH_FAIL=
run claim-acquire --profile github --target example/repo 101 \
	--token q101-n3wn3w --producer bob
assert_exit 0 "$RUN_STATUS" 'acquire after partial takes the absent path'

# --- grammar guards --------------------------------------------------------------
run claim-acquire --profile github --target example/repo 101 \
	--token 'bad token!' --producer alice
assert_exit 1 "$RUN_STATUS" 'invalid token is usage'
run claim-acquire --profile github --target example/repo 'not-a-number' \
	--token q101-aaaaaaaa --producer alice
assert_exit 1 "$RUN_STATUS" 'non-numeric issue is usage'

# --- transport failure at a verify gate is never a claim loss ----------------------
new_store
seed_claim 101 q101-aaaaaaaa alice "$now"
GH_FAIL=rate
run claim-verify --profile github --target example/repo 101 --token q101-aaaaaaaa
assert_exit 4 "$RUN_STATUS" 'rate-limited verify is transport, never loss'
GH_FAIL=

# --- parser edge cases --------------------------------------------------------------
new_store
seed_claim 101 q101-aaaaaaaa alice "$now;"
run claim-verify --profile github --target example/repo 101 --token q101-aaaaaaaa
assert_exit 0 "$RUN_STATUS" 'trailing semicolon parses clean'
new_store
mkdir -p "$GH_STORE/quest-claim/101"
printf 'q101-aaaaaaaa; alice;%s' "$now" >"$GH_STORE/quest-claim/101/description"
run claim-verify --profile github --target example/repo 101 --token q101-aaaaaaaa
assert_exit 6 "$RUN_STATUS" 'whitespace field is malformed'
new_store
mkdir -p "$GH_STORE/quest-claim/101"
printf 'q101-aaaaaaaa;alice;%s;extra' "$now" >"$GH_STORE/quest-claim/101/description"
run claim-verify --profile github --target example/repo 101 --token q101-aaaaaaaa
assert_exit 6 "$RUN_STATUS" 'four fields is malformed'

# --- external deletion races a verify gate --------------------------------------------
new_store
seed_claim 101 q101-aaaaaaaa alice "$now"
rm -rf "${GH_STORE:?}/quest-claim/101"
run claim-verify --profile github --target example/repo 101 --token q101-aaaaaaaa
assert_exit 2 "$RUN_STATUS" 'externally deleted claim verifies absent'

# --- claim-list --------------------------------------------------------------------
new_store
seed_claim 101 q101-aaaaaaaa alice "$now"
seed_claim 102 q102-bbbbbbbb bob "$((now - 100000))"
mkdir -p "$GH_STORE/quest-claim/103"
printf 'garbage' >"$GH_STORE/quest-claim/103/description"
mkdir -p "$GH_STORE/quest-claim/abc"
printf 'q10x-cccccccc;carol;%s' "$now" >"$GH_STORE/quest-claim/abc/description"
run claim-list --profile github --target example/repo
assert_exit 0 "$RUN_STATUS" 'claim-list'
jq -e 'length == 3' >"$sandbox/jq-out" <"$sandbox/out" ||
	fail 'claim-list count wrong (non-digit suffix must not list)'
jq -e '.[] | select(.issue == "101")
	| .token == "q101-aaaaaaaa" and .malformed == false' \
	>"$sandbox/jq-out" <"$sandbox/out" || fail 'claim-list well-formed entry'
jq -e '.[] | select(.issue == "103")
	| .token == null and .producer == null and .at == null
		and .malformed == true' \
	>"$sandbox/jq-out" <"$sandbox/out" || fail 'claim-list malformed entry'

# --- liveness boundary ages ---------------------------------------------------------
new_store
for age in 100 700 50000; do
	seed_claim 101 q101-aaaaaaaa alice "$((now - age))"
	run claim-verify --profile github --target example/repo 101 --token q101-aaaaaaaa
	assert_exit 0 "$RUN_STATUS" "verify at age $age"
	reported=$(jq -r '.age_seconds' <"$sandbox/out")
	((reported >= age && reported <= age + 30)) ||
		fail "age $age reported as $reported"
done

printf 'claim-test: all assertions passed\n'
