# Quest claim exclusion — implementation plan

**Goal.** Give `$quest` an exclusive claim on its issue: a repo label
`quest-claim/<N>` acquired through an atomic `gh label create`, verified at
four gates, recovered through staleness or operator force, and consumed by
`$seek-quest`, `$resurrection`, and `$campaign` — per
`docs/workflow/specs/2026-08-16-quest-claim-exclusion-design.md` and ADR
`docs/adr/0018-quest-claim-via-exclusive-repo-label.md`.

**Architecture.** Five new tracker-engine operations
(`claim-acquire|verify|release|recover|list`) implemented in the github
profile of `skills/quest-log/assets/tracker.sh`; a new exit class
`EXIT_CONFLICT=6`; a stateful stub-`gh` adversarial suite under
`tests/fixtures/quest-log/`; prose integration in five SKILL.md files.

**Stack.** Bash 3.2 (floor), `gh`, `jq`, `rg`. No new dependencies.

## Global Constraints

Transcribed from the spec and repo rules; every task inherits them.

- Claim label name: `quest-claim/<N>`, `<N>` decimal digits. Color `6b7280`.
- Description grammar: `<token>;<login>;<epoch>` — token
  `[A-Za-z0-9-]{1,32}`, login `[A-Za-z0-9-]{1,39}`, epoch UTC seconds digits.
  Charsets are **enumerated** in bash bracket expressions, never ranged
  (locale collation admits accented letters under UTF-8 locales — the rule
  `profiles/github.sh` already follows for label names).
- `CLAIM_GRACE=600`, `CLAIM_TTL=43200` (seconds).
- Exit taxonomy: existing `EXIT_USAGE=1 EXIT_NOT_FOUND=2 EXIT_AUTH=3
  EXIT_TRANSPORT=4 EXIT_PARTIAL=5`, new `EXIT_CONFLICT=6`. Conflict payloads
  are JSON on **stderr**; stdout carries success payloads only.
- Bash: `#!/usr/bin/env bash`, `set -euo pipefail`, tab indentation,
  bash 3.2-safe (no `mapfile`/`readarray`/assoc arrays). `rg` invocations in
  scripts pass `--no-config`. Capture scan exit statuses explicitly (ADR
  0005): no bare `|| true` on a scan whose fault and no-match states differ.
- Guardrails: `just verify` run bare before every commit series ends; the
  commit hook runs `just commit-check` (lint, format-check, public-safety).
- New suite files must be `git add`ed before `just test` will discover them
  (`git ls-files '*-test.sh'`).
- Public repo: no absolute host paths, hostnames, or credentials in any
  committed file (`scripts/check-public-safety.sh`).
- Fix loop: when a verification step fails, fix the cause and re-run that
  step's verification before advancing. Never skip ahead to the next step
  or task with a red verification behind you; never weaken an assertion to
  reach green.

## File map

| File | Change |
|---|---|
| `tests/fixtures/quest-log/claim-test.sh` | **new** — adversarial suite + stateful stub `gh` |
| `skills/quest-log/assets/tracker.sh` | add `EXIT_CONFLICT=6` to the taxonomy block |
| `skills/quest-log/assets/profiles/github.sh` | 5 claim operations + declarations + helpers |
| `tests/fixtures/quest-log/tracker-test.sh` | one `declares` case for `claim-acquire` |
| `skills/quest-log/SKILL.md` | new "Claim protocol" section |
| `skills/quest/SKILL.md` | claim sequence in step 1, gates G3/G4, token format |
| `skills/seek-quest/SKILL.md` | claim occupancy signal + hard-constraint line |
| `skills/resurrection/SKILL.md` | claim-aware sweep bullets |
| `skills/campaign/SKILL.md` | claim evidence, pre-dispatch read, prompt contract |

## Task 1 — the failing adversarial suite

**Files.** Creates `tests/fixtures/quest-log/claim-test.sh`.

**Interfaces.** Consumes `skills/quest-log/assets/tracker.sh` (staged copy)
and `scripts/test-fixture-helpers.sh` (`clear_git_env`, `fixture_init`,
`fail`). Later tasks rely on: `tracker.sh claim-<op> --profile github
--target example/repo ...` behaving per the spec (the suite encodes it).

**Where it fits.** TDD red step: the suite fails because the operations do
not exist yet (engine exits 1, "no operation").

### Steps

1. Write the file below, complete.
2. `chmod +x tests/fixtures/quest-log/claim-test.sh && git add tests/fixtures/quest-log/claim-test.sh`
3. Run it: `tests/fixtures/quest-log/claim-test.sh` — **expect failure**:
   the first case exits 1 with `no operation 'claim-acquire'` on stderr.
   This confirms the suite can fail.
4. Commit: `test: add quest-claim adversarial suite (red) (#125)`.

```bash
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
now=$(date -u +%s)

run() { # op args... — runs the tracker, captures status in RUN_STATUS
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
	RUN_STATUS=0
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
	0:6) winner=q101-aaaaaaaa; loser=q101-bbbbbbbb ;;
	6:0) winner=q101-bbbbbbbb; loser=q101-aaaaaaaa ;;
	*) fail "round $round: exits $sA:$sB, expected one 0 and one 6" ;;
	esac
	[[ -f $GH_STORE/quest-claim/101/description ]] ||
		fail "round $round: no claim at rest"
	stored=$(cat "$GH_STORE/quest-claim/101/description")
	case $stored in
	"$winner";*) ;;
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
	q101-aaaaaaaa\;*) owner=q101-aaaaaaaa; loser=q101-bbbbbbbb ;;
	q101-bbbbbbbb\;*) owner=q101-bbbbbbbb; loser=q101-aaaaaaaa ;;
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
```

**Acceptance.** Suite runs, fails only because the operations are missing,
and the failure message names `claim-acquire`.

## Task 2 — the claim operations

**Files.** Modifies `skills/quest-log/assets/tracker.sh`,
`skills/quest-log/assets/profiles/github.sh`,
`tests/fixtures/quest-log/tracker-test.sh`.

**Interfaces.** Consumes nothing from Task 1 but its expectations. Provides
to Tasks 3–5: the five operations exactly as the spec's *Tracker operations*
section, and `EXIT_CONFLICT=6`.

### Steps

1. In `tracker.sh`, extend the taxonomy block after `EXIT_PARTIAL=5`:

```bash
# shellcheck disable=SC2034
EXIT_PARTIAL=5
# shellcheck disable=SC2034
EXIT_CONFLICT=6
```

2. In `profiles/github.sh`, add the five operations to `PROFILE_DECLARES`
(append before the closing quote):

```
claim_acquire:implemented
claim_verify:implemented
claim_release:implemented
claim_recover:implemented
claim_list:implemented
```

3. Append to `profiles/github.sh` (tab-indented, matching file style):

```bash
# --- quest claims ------------------------------------------------------------
# The claim label grammar. Charsets are enumerated, not ranged, for the same
# locale-collation reason as github_label_first above.
github_claim_chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-'
readonly github_claim_chars

github_claim_validate_token() { # token
	[[ $1 =~ ^[$github_claim_chars]+$ && ${#1} -le 32 ]] ||
		die "$EXIT_USAGE" usage "claim token must be 1-32 chars of [A-Za-z0-9-]: $1"
}

github_claim_validate_producer() { # login
	[[ $1 =~ ^[$github_claim_chars]+$ && ${#1} -le 39 ]] ||
		die "$EXIT_USAGE" usage "claim producer must be a GitHub login: $1"
}

# Reads the claim label for an issue into CLAIM_STATE (absent|held|malformed)
# and, when held, CLAIM_TOKEN/CLAIM_PRODUCER/CLAIM_AT. Returns 2 when the
# store could not be read at all, leaving the error class to the caller:
# acquire reports partial (its create may have landed), the others die
# classified. Variables rather than stdout keep the caller's payload free.
CLAIM_STATE=''
CLAIM_TOKEN=''
CLAIM_PRODUCER=''
CLAIM_AT=''
github_claim_read() { # issue
	local issue=$1 status=0 desc f1 f2 f3 rest
	CLAIM_STATE=''
	CLAIM_TOKEN=''
	CLAIM_PRODUCER=''
	CLAIM_AT=''
	github_run api "repos/$TRACKER_TARGET/labels/quest-claim%2F$issue" \
		--jq '.description // ""' || status=$?
	if ((status != 0)); then
		local code class
		read -r code class <<<"$(github_classify "$GH_ERR")"
		if [[ $class == not-found ]]; then
			CLAIM_STATE=absent
			return 0
		fi
		return 2
	fi
	desc=$GH_OUT
	f1='' f2='' f3='' rest=''
	IFS=';' read -r f1 f2 f3 rest <<<"$desc"
	if [[ -n $rest || -z $f1 || -z $f2 || -z $f3 ]] ||
		[[ ! $f1 =~ ^[$github_claim_chars]+$ || ${#f1} -gt 32 ]] ||
		[[ ! $f2 =~ ^[$github_claim_chars]+$ || ${#f2} -gt 39 ]] ||
		[[ ! $f3 =~ ^[0123456789]+$ ]]; then
		CLAIM_STATE=malformed
		return 0
	fi
	CLAIM_STATE=held
	CLAIM_TOKEN=$f1
	CLAIM_PRODUCER=$f2
	CLAIM_AT=$f3
}

# Emits the conflict payload on stderr and exits EXIT_CONFLICT. Reads the
# state github_claim_read left behind.
github_claim_conflict() { # issue
	local issue=$1
	if [[ $CLAIM_STATE == malformed ]]; then
		jq -n --arg i "$issue" \
			'{error: "conflict",
			  holder: {token: null, producer: null, at: null, malformed: true},
			  message: ("foreign claim on issue " + $i + " has an unparseable description")}' >&2
	else
		jq -n --arg i "$issue" --arg t "$CLAIM_TOKEN" \
			--arg p "$CLAIM_PRODUCER" --arg a "$CLAIM_AT" \
			'{error: "conflict",
			  holder: {token: $t, producer: $p, at: $a, malformed: false},
			  message: ("live foreign claim on issue " + $i)}' >&2
	fi
	exit "$EXIT_CONFLICT"
}

# Parses the shared --token/--producer flags. Sets TOKEN and PRODUCER.
github_claim_parse_owner() { # args...
	TOKEN=''
	PRODUCER=''
	while (($#)); do
		case $1 in
		--token)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--token needs a value'
			TOKEN=$2
			shift 2
			;;
		--producer)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--producer needs a value'
			PRODUCER=$2
			shift 2
			;;
		*) die "$EXIT_USAGE" usage "unknown claim argument: $1" ;;
		esac
	done
	github_claim_validate_token "$TOKEN"
	github_claim_validate_producer "$PRODUCER"
}

profile_claim_acquire() {
	github_require_target
	(($# >= 1)) || die "$EXIT_USAGE" usage 'claim-acquire needs an issue id'
	local issue=$1 status=0 epoch desc create_err
	github_require_id "$issue" 'issue id'
	shift
	local TOKEN PRODUCER
	github_claim_parse_owner "$@"
	epoch=$(date -u +%s)
	desc="$TOKEN;$PRODUCER;$epoch"
	github_run label create "quest-claim/$issue" --repo "$TRACKER_TARGET" \
		--color 6b7280 --description "$desc" || status=$?
	if ((status == 0)); then
		jq -n --arg i "$issue" --arg t "$TOKEN" --arg p "$PRODUCER" --arg a "$epoch" \
			'{claimed: true, issue: $i, token: $t, producer: $p, at: $a}'
		return 0
	fi
	# Every create failure resolves by read-back, never by message text: the
	# store's state is the only trustworthy discriminator between losing the
	# race, winning but losing the response, and a create that genuinely
	# failed. The create's own error is preserved across the read-back --
	# GH_ERR belongs to whichever gh ran last.
	create_err=$GH_ERR
	local read_status=0
	github_claim_read "$issue" || read_status=$?
	if ((read_status != 0)); then
		jq -Rrn --arg m "$GH_ERR" \
			'{error: "partial", message: $m, partial: {stage: "read-back"}}' >&2
		exit "$EXIT_PARTIAL"
	fi
	case $CLAIM_STATE in
	held)
		if [[ $CLAIM_TOKEN == "$TOKEN" ]]; then
			jq -n --arg i "$issue" --arg t "$TOKEN" \
				--arg p "$CLAIM_PRODUCER" --arg a "$CLAIM_AT" \
				'{claimed: true, recovered: "self", issue: $i,
				  token: $t, producer: $p, at: $a}'
			return 0
		fi
		github_claim_conflict "$issue"
		;;
	malformed)
		github_claim_conflict "$issue"
		;;
	absent)
		github_die "$create_err"
		;;
	esac
}

profile_claim_verify() {
	github_require_target
	(($# >= 1)) || die "$EXIT_USAGE" usage 'claim-verify needs an issue id'
	local issue=$1 now age
	github_require_id "$issue" 'issue id'
	shift
	local TOKEN=''
	while (($#)); do
		case $1 in
		--token)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--token needs a value'
			TOKEN=$2
			shift 2
			;;
		*) die "$EXIT_USAGE" usage "unknown claim-verify argument: $1" ;;
		esac
	done
	github_claim_validate_token "$TOKEN"
	github_claim_read "$issue" || github_die "$GH_ERR"
	case $CLAIM_STATE in
	absent)
		die "$EXIT_NOT_FOUND" not-found "no claim on issue $issue"
		;;
	malformed)
		github_claim_conflict "$issue"
		;;
	held)
		if [[ $CLAIM_TOKEN == "$TOKEN" ]]; then
			now=$(date -u +%s)
			age=$((now - CLAIM_AT))
			jq -n --argjson age "$age" '{held: true, age_seconds: $age}'
			return 0
		fi
		github_claim_conflict "$issue"
		;;
	esac
}

profile_claim_release() {
	github_require_target
	(($# >= 1)) || die "$EXIT_USAGE" usage 'claim-release needs an issue id'
	local issue=$1 status=0
	github_require_id "$issue" 'issue id'
	shift
	local TOKEN=''
	while (($#)); do
		case $1 in
		--token)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--token needs a value'
			TOKEN=$2
			shift 2
			;;
		*) die "$EXIT_USAGE" usage "unknown claim-release argument: $1" ;;
		esac
	done
	github_claim_validate_token "$TOKEN"
	github_claim_read "$issue" || github_die "$GH_ERR"
	case $CLAIM_STATE in
	absent)
		printf '{}\n'
		return 0
		;;
	malformed)
		github_claim_conflict "$issue"
		;;
	held)
		[[ $CLAIM_TOKEN == "$TOKEN" ]] || github_claim_conflict "$issue"
		github_run label delete "quest-claim/$issue" --repo "$TRACKER_TARGET" \
			--yes || status=$?
		# A delete that landed with a lost response classifies transport; the
		# re-run reads absent and returns {}.
		((status == 0)) || github_die "$GH_ERR"
		printf '{}\n'
		;;
	esac
}

profile_claim_recover() {
	github_require_target
	(($# >= 1)) || die "$EXIT_USAGE" usage 'claim-recover needs an issue id'
	local issue=$1 older_than='' force=0 status=0 now age epoch desc
	github_require_id "$issue" 'issue id'
	shift
	local TOKEN PRODUCER
	while (($#)); do
		case $1 in
		--token)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--token needs a value'
			TOKEN=$2
			shift 2
			;;
		--producer)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--producer needs a value'
			PRODUCER=$2
			shift 2
			;;
		--older-than)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--older-than needs a value'
			older_than=$2
			shift 2
			;;
		--force)
			force=1
			shift
			;;
		*) die "$EXIT_USAGE" usage "unknown claim-recover argument: $1" ;;
		esac
	done
	github_claim_validate_token "$TOKEN"
	github_claim_validate_producer "$PRODUCER"
	[[ -n $older_than || $force == 1 ]] ||
		die "$EXIT_USAGE" usage 'claim-recover needs --older-than or --force'
	if [[ -n $older_than && ! $older_than =~ ^[0123456789]+$ ]]; then
		die "$EXIT_USAGE" usage "--older-than must be seconds: $older_than"
	fi
	github_claim_read "$issue" || github_die "$GH_ERR"
	case $CLAIM_STATE in
	held)
		if ((force == 0)); then
			now=$(date -u +%s)
			age=$((now - CLAIM_AT))
			((age >= older_than)) || github_claim_conflict "$issue"
		fi
		github_run label delete "quest-claim/$issue" --repo "$TRACKER_TARGET" \
			--yes || status=$?
		# Delete failed: the old claim stands untouched, and a retry matches
		# the same guard.
		((status == 0)) || github_die "$GH_ERR"
		;;
	malformed)
		# No evaluable age: --older-than always refuses; only --force or a
		# manual delete clears a malformed claim.
		((force == 1)) || github_claim_conflict "$issue"
		github_run label delete "quest-claim/$issue" --repo "$TRACKER_TARGET" \
			--yes || status=$?
		((status == 0)) || github_die "$GH_ERR"
		;;
	absent) : ;;
	esac
	epoch=$(date -u +%s)
	desc="$TOKEN;$PRODUCER;$epoch"
	status=0
	github_run label create "quest-claim/$issue" --repo "$TRACKER_TARGET" \
		--color 6b7280 --description "$desc" || status=$?
	if ((status != 0)); then
		# Between delete and create the store may be absent; the caller
		# re-runs claim-acquire, which takes the absent path.
		jq -Rrn --arg m "$GH_ERR" \
			'{error: "partial", message: $m, partial: {stage: "create"}}' >&2
		exit "$EXIT_PARTIAL"
	fi
	jq -n --arg i "$issue" --arg t "$TOKEN" --arg p "$PRODUCER" --arg a "$epoch" \
		'{claimed: true, recovered: "stale-or-forced", issue: $i,
		  token: $t, producer: $p, at: $a}'
}

profile_claim_list() {
	github_require_target
	local out
	github_run_checked api "repos/$TRACKER_TARGET/labels?per_page=100" \
		--paginate \
		--jq '.[] | select(.name | test("^quest-claim/[0-9]+$")) | {name, description}'
	out=$GH_OUT
	# Per-page output is a stream of {name, description} objects; slurp and
	# map to the entry schema. A description failing any grammar check marks
	# the whole entry malformed -- no partial parsing, so a bad field never
	# rides beside good ones.
	jq -s '
		def grammar:
			(. // "") | split(";") as $f
			| ($f | length) == 3
				and ($f[0] | test("^[A-Za-z0-9-]{1,32}$"))
				and ($f[1] | test("^[A-Za-z0-9-]{1,39}$"))
				and ($f[2] | test("^[0-9]+$"));
		[ .[]
			| .name as $n
			| if (.description | grammar) then
				(.description | split(";")) as $f
				| {issue: ($n | ltrimstr("quest-claim/")),
				   token: $f[0], producer: $f[1], at: $f[2],
				   malformed: false}
			else
				{issue: ($n | ltrimstr("quest-claim/")),
				 token: null, producer: null, at: null,
				 malformed: true}
			end ]
	' <<<"$out"
}
```

4. In `tests/fixtures/quest-log/tracker-test.sh`, after the existing
   `declares github view` case, add:

```bash
"$tracker" declares --profile github claim-acquire >"$sandbox/out" 2>&1 ||
	fail 'declares github claim-acquire exited non-zero'
assert_contains 'implemented' "$sandbox/out"
```

5. Run the new suite: `tests/fixtures/quest-log/claim-test.sh` — **expect
   `claim-test: all assertions passed`**.
6. Run the contract suite: `tests/fixtures/quest-log/tracker-test.sh` —
   expect `tracker-test: all assertions passed` (the bidirectional
   declaration gate now covers the five new operations).
7. Prove the suite bites, in four sub-steps: (a) change one `assert_exit 6`
   in the simultaneous-claims round to `assert_exit 0`; (b) re-run the
   suite and confirm it **fails**; (c) revert the edit; (d) re-run and
   confirm green again. A suite that does not redden at (b) proves nothing,
   and a suite left weakened by skipping (c) proves nothing from then on.
8. `just lint && just format-check` — expect no findings.
9. Commit: `feat: add quest-claim operations to the tracker engine (#125)`.

**Acceptance.** Both suites green; mutation step 7 reddens the suite;
shellcheck and shfmt clean.

## Task 3 — quest-log claim protocol section

**Files.** Modifies `skills/quest-log/SKILL.md`.

**Interfaces.** Provides the single definition Tasks 4–5 reference.

### Steps

1. Insert a new section after the `## Risk dimension` section's end (before
   `## Annotation convention`):

```markdown
## Claim protocol

A `$quest` run holds **implementation authority** over its issue as a
*claim*: a repository label named `quest-claim/<N>`, never applied to the
issue. Acquisition is `gh label create` — the server-side unique-name
constraint is the exclusive operation, so exactly one of two concurrent
claimants wins (ADR 0018 carries the probe evidence).

- **Description grammar**: `<token>;<login>;<epoch>` — the scope token
  (`[A-Za-z0-9-]{1,32}`, minted as `q<N>-<8 hex>`), the claiming account's
  login, and the claim time as UTC epoch seconds. A description that fails
  any grammar check is a *malformed* claim: treated as foreign everywhere,
  clearable only by `claim-recover --force` or a manual `gh label delete`.
- **Token binding**: the claim token **is** the `WORK:SCOPE` annotation
  token. A `WORK:SCOPE` annotation is authoritative only while its token
  matches the issue's live claim; an annotation whose token matches no live
  claim is a dead or displaced quest's residue — not liveness evidence, not
  a scope charter, and never a reason to stop an active quest. Every
  consumer that reads `WORK:SCOPE` for authority or liveness applies the
  token match when a claim is present; on an issue with no claim at all the
  annotation rule stands unchanged.
- **Liveness**: `CLAIM_GRACE=600` and `CLAIM_TTL=43200` seconds. A claim is
  *live* when its age < `CLAIM_TTL` **and** (its age < `CLAIM_GRACE` **or**
  the issue carries an in-flight status: `in-progress`, `in-review`,
  `awaiting-merge`). Anything else is *stale*, including every claim on a
  closed issue. The grace window covers the acquire→status-swap gap; a
  claim that never reaches an in-flight status is recoverable once grace
  expires, by design.
- **Operations** (tracker engine, github profile):
  `claim-acquire|claim-verify|claim-release|claim-recover|claim-list`.
  Exit class `EXIT_CONFLICT=6` reports a live foreign claim with a
  structured holder payload on stderr; `claim-verify` exits 0 held, 2
  absent, 6 foreign; `claim-recover` requires `--older-than <seconds>` or
  `--force` (the structural carrier of an operator's recovery decision).
- **Write edges**: `$quest` acquires, verifies, and releases;
  `claim-recover` runs under the staleness rule or explicit operator
  authorization; `$resurrection` garbage-collects claims on closed issues
  and deletes orphaned claims on issues it resets. The one-writer-per-edge
  rule extends to claim edges with exactly these writers.
- **Verify gates**: `$quest` verifies immediately after acquiring (before
  any issue mutation), after the `WORK:SCOPE` readback, before branch
  creation, and before pushing. Gate outcomes are exhaustive: held →
  proceed; absent or foreign → halt with no further issue mutation;
  transport → the ordinary retryable path.
```

2. `just shape-check` — expect pass (no `$invocation` or reference links
   added).
3. Commit: `docs: define the quest-claim protocol in quest-log (#125)`.

**Acceptance.** Section present; shape gate green.

## Task 4 — quest integration

**Files.** Modifies `skills/quest/SKILL.md`.

**Interfaces.** Consumes Task 3's definitions; changes what every future
`$quest` run does in steps 1, 2, and 8.

### Steps

1. In step 1, replace the paragraph

```
Set the issue to `status:in-progress` (ensure-create the `status:` labels per
the quest-log recipe; single-active swap). If ensure-create fails, stop
with its message rather than proceeding label-less.
```

with (outer fence here is four backticks so the inner sh fence survives):

````markdown
**Claim the issue before touching it.** Mint the scope token now, in the
short form `q<issue-number>-<8 lowercase hex>` (the quest-log claim protocol
constrains the grammar), and resolve the producer login
(`gh api user --jq .login`; a failure is an auth failure — stop with the
`gh` error). Then acquire the claim:

```sh
skills/quest-log/assets/tracker.sh claim-acquire --target <owner/name> \
  <issue-number> --token <scope-token> --producer <login>
```

On exit 6, read the holder payload and the issue's status:

- Holder stale per the liveness rule → recover:
  `claim-recover <issue-number> --token <scope-token> --producer <login>
  --older-than <CLAIM_TTL if the issue carries an in-flight status, else
  CLAIM_GRACE>` and continue as the new owner.
- Holder live, interactive root → stop. Report the holder's token,
  producer, age, and the issue's status; the human decides whether to wait
  or authorize recovery (a re-invocation carrying that decision uses
  `claim-recover --force`). Ask, never assume.
- Holder live, unattended root → stop with no writes to the issue. This is
  the one exception to the park protocol: the issue belongs to a live
  quest, and any label or comment write on it is the interference the
  protocol exists to prevent. Report the blocker in the completion report;
  under `$campaign`, return it to the orchestrator as a hold.

Then verify gate **G1**: `claim-verify` immediately after acquiring or
recovering, before any mutation of the issue. Gate outcomes are exhaustive:
exit 0 → held, proceed; exit 2 or 6 → claim lost: halt immediately, make no
further mutation of the issue (labels, comments, or the claim), and report —
never retry a lost claim into re-acquisition at a gate; exit 4 → the
ordinary retryable transport path. A loser at any gate reports its local
branch path if one exists; the operator disposes of it.

Only then set the issue to `status:in-progress` (ensure-create the
`status:` labels per the quest-log recipe; single-active swap). The swap is
idempotent and not exclusive, and nothing relies on it for exclusivity. If
ensure-create fails, release the claim first (`claim-release` — the quest
owns it and is abandoning the issue), then stop with the ensure-create
message rather than proceeding label-less.
````

2. In `### Posting the annotation`, replace the first sentence ("Mint the
   annotation token once, include it in the comment, and capture the
   returned comment URL as the annotation's location, not its identity.")
   with: "Use the scope token minted for the claim (step 1) as the
   annotation token — claim and charter share one identity. Include it in
   the comment and capture the returned comment URL as the annotation's
   location, not its identity." Append to that section: "After the
   readback, cross-check the annotation token against the claim token, then
   run verify gate **G2** (`claim-verify` again)."

3. In `## 2. Branch`, prepend: "Verify gate **G3**: `claim-verify` before
   creating the branch; a lost gate halts per step 1's rule."

4. In `## 8. Ship It`, prepend: "Verify gate **G4**: `claim-verify` before
   running `$deliver`; a lost gate halts per step 1's rule."

5. `just shape-check` — expect pass.
6. Commit: `feat: claim the issue before touching it in quest (#125)`.

**Acceptance.** The four gates and the conflict paths are present; the
token-mint instruction appears once (step 1), referenced from the
annotation section. Reading check on the conflict paths (prose has no
executable harness): the unattended branch names the no-writes exception
and the campaign hold return, the interactive branch stops and asks, and
the ensure-create failure path releases the claim before stopping.

## Task 5 — consumer skills

**Files.** Modifies `skills/seek-quest/SKILL.md`,
`skills/resurrection/SKILL.md`, `skills/campaign/SKILL.md`.

### Steps

1. `seek-quest` step 6: insert as the first bullet of the eligibility
   filter:

```markdown
- Fetch quest claims once:
  `skills/quest-log/assets/tracker.sh claim-list --target <owner/name>`.
  Drop any candidate whose issue number appears, reported as `claim
  quest-claim/<N>` — no liveness judgment: a stale claim is repaired by
  `$resurrection`, and a dropped candidate is only a recommendation away.
  A `claim-list` failure stops the sweep per the fail-stop rule below.
```

   and in `## Hard constraints`, change the first bullet's allowlist to
   "`gh`, `git ls-remote`/`git branch`, the read-only `claim-list` tracker
   operation, and `Read` only".

2. `resurrection` step 2: append to the sweep intro: "Fetch quest claims
   once (`claim-list`)." and add to the per-issue checks:

```markdown
- **claim on a closed issue** → plan: delete the claim (release guarded by
  the observed token; the owner is gone).
- **claim on an issue the staleness gate resets** → the same plan row
  deletes the orphaned claim. The gate's four conditions are unchanged: a
  claim never extends or vetoes the reset window — its TTL gates
  quest-versus-quest recovery, not this sweep.
```

   and in step 3's gate, after condition (c), note: "read `WORK:SCOPE`
   liveness with the quest-log token-binding rule: an annotation whose
   token matches no live claim is residue, not liveness."

3. `campaign`: in step 3's reconcile list, after "`status:` label set", add
   "A `quest-claim/<N>` label (one `claim-list` read for the batch) is
   in-flight evidence: map the row to in-flight and reconcile artifacts as
   for an in-progress label." In step 5, before "**Serial:** dispatch
   one...", insert:

```markdown
**Claim check before every dispatch and re-dispatch.** Read the claim
(`claim-list` covers the batch; a read failure holds the row — the step-5
hold: named in the run output while the rest of the queue drains — and
reports the error; never dispatch on an unreadable claim state). No claim →
dispatch; the worker acquires its own. Stale claim → dispatch with recovery
authorized in the prompt; the worker runs `claim-recover --older-than`.
Live claim → hold: do not dispatch. When the row's agent has been observed
ended (the re-dispatch bar above), the operator's re-dispatch answer is the
recovery authorization; the prompt carries it and the worker runs
`claim-recover --force`.
```

   and in the step-5 prompt contract list, add: "The worker mints its own
   claim token and never recovers a claim without authorization carried in
   the dispatch prompt."

4. `just shape-check` — expect pass.
5. Commit: `feat: consume quest claims in seek-quest, resurrection, campaign (#125)`.

**Acceptance.** All three skills read `claim-list` once per sweep/batch;
the campaign claim-check has exactly four branches (read failure, none,
stale, live).

## Final verification

1. `just verify` — full suite, bare. Expect all gates green, including
   `test: 16 suites passed` (15 existing + claim-test).
2. `git log --oneline origin/main..HEAD` — one commit per task plus the
   design commits.
