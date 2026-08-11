#!/usr/bin/env bash
# Regression tests for start-server.sh argument validation.

set -euo pipefail

# ripgrep applies RIPGREP_CONFIG_PATH's contents as arguments ahead of the ones
# passed below, so a personal ripgreprc would otherwise steer this suite's own
# matching.
unset RIPGREP_CONFIG_PATH

# Hooks export repository-local Git variables that override `git -C`. Clear
# Git's complete reported set before any fixture repository is discovered.
while IFS= read -r variable; do
  [ -n "$variable" ] || continue
  unset "$variable"
done < <(git rev-parse --local-env-vars)

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# The suite lives in tests/fixtures/ so it is excluded from the installed
# payload; the script it exercises ships under skills/.
SCRIPT="$SCRIPT_DIR/../../../skills/brainstorming/scripts/start-server.sh"

passed=0
failed=0

run_case() {
  local name=$1 expected=$2 want=$3
  shift 3
  local dir got=0
  # Allocated, not constructed: `just test` and CI now run this suite, and a
  # name derived from the pid plus two counters is predictable enough for a
  # local actor to pre-create as a symlink, redirecting the writes below.
  dir="$(mktemp -d "${TMPDIR:-/tmp}/brainstorm-start-test.XXXXXX")"

  if "$SCRIPT" "$@" >"$dir/out" 2>"$dir/err"; then
    got=0
  else
    got=$?
  fi

  if [ "$got" = "$expected" ] && grep -qF -- "$want" "$dir/out" "$dir/err"; then
    passed=$((passed + 1))
    printf '  ok   %s\n' "$name"
  else
    failed=$((failed + 1))
    printf '  FAIL %s (exit=%s, expected=%s, wanted=%s)\n' \
      "$name" "$got" "$expected" "$want"
    sed -n '1,8p' "$dir/out" "$dir/err"
  fi

  if [ -d "$dir" ]; then
    rm -R "$dir"
  fi
}

# The server-id grammar is an ASCII bracket expression, and bash takes a bracket
# range from the locale's collation -- so the property worth asserting is that it
# bites under the locale a developer actually runs, not under whichever one this
# suite inherits. Pin a territory UTF-8 locale where the host has one. `C.UTF-8`
# is deliberately not accepted as a substitute: it does not reproduce the
# collation behaviour, so a case that settled for it would pass while the defect
# was live (ADR 0023). With no such locale the accented candidate is rejected
# whatever the grammar, so the case still passes -- it just stops proving the
# property.
utf8_locale=$(locale -a 2>/dev/null |
  rg -N -m1 '^[a-z]{2}_[A-Z]{2}\.(utf8|UTF-8)$' || true)
if [ -z "$utf8_locale" ]; then
  printf 'note: no territory UTF-8 locale; the accented case proves nothing\n' >&2
fi

# The stubs below are what an aborted run would leave in TMPDIR, so the removal
# is a trap rather than a trailing statement: an assertion failure only bumps a
# counter, but `set -e` turns any unexpected failure into an exit from here.
server_id_dir=""
cleanup_server_id_dir() {
  if [ -n "$server_id_dir" ] && [ -d "$server_id_dir" ]; then
    rm -R "$server_id_dir"
  fi
  server_id_dir=""
}
trap cleanup_server_id_dir EXIT

# The server-id guard is unreachable from argv: start-server.sh derives the
# candidate from /dev/urandom inside its own process. Shadow `od` so the guard
# sees a chosen candidate, then read back the id the script committed to disk,
# which it writes before it goes anywhere near the server. The ASCII case is the
# control that proves the stub reaches the guard at all -- without it a stub that
# silently failed would take the fallback and leave the accented case passing for
# the wrong reason.
run_server_id_case() {
  local name=$1 stub_id=$2 expect=$3
  local dir stub project id_file id

  server_id_dir="$(mktemp -d "${TMPDIR:-/tmp}/brainstorm-start-test.XXXXXX")"
  dir="$server_id_dir"
  stub="$dir/bin"
  project="$dir/project"
  mkdir -p "$stub" "$project"

  printf '%s\n' '#!/usr/bin/env bash' "printf %s '$stub_id'" >"$stub/od"
  # server.cjs is not under test. Announce the line start-server.sh waits for and
  # exit, so its liveness window fails the run fast instead of holding this suite
  # for the full startup timeout.
  printf '%s\n' '#!/usr/bin/env bash' 'printf "server-started\n"' >"$stub/node"
  chmod +x "$stub/od" "$stub/node"

  PATH="$stub:$PATH" LC_ALL="${utf8_locale:-C}" "$SCRIPT" --project-dir "$project" \
    >"$dir/out" 2>"$dir/err" || true

  id_file="$(find "$project" -type f -name server-instance-id -print -quit)"
  id=""
  if [ -n "$id_file" ]; then
    id="$(cat "$id_file")"
  fi

  if [ -z "$id_file" ]; then
    failed=$((failed + 1))
    printf '  FAIL %s (no server-instance-id was written)\n' "$name"
  elif [ "$expect" = accepted ] && [ "$id" = "$stub_id" ]; then
    passed=$((passed + 1))
    printf '  ok   %s\n' "$name"
  elif [ "$expect" = rejected ] && [ -n "$id" ] && [ "$id" != "$stub_id" ] &&
    [ "${id#*é}" = "$id" ]; then
    passed=$((passed + 1))
    printf '  ok   %s\n' "$name"
  else
    failed=$((failed + 1))
    printf '  FAIL %s (expected %s, committed id=%s)\n' "$name" "$expect" "$id"
  fi

  cleanup_server_id_dir
}

# --project-dir state must stay out of git without the script touching a tracked
# file (ADR 0027). The suite above locates its artifact with a path-agnostic
# `find`, so it passes whether state lands in .agent/ or anywhere else and cannot
# see the ignore contract at all. These two cases assert that contract directly.
# The node stub is the same trick used above: server.cjs is not under test.
run_ignore_case() {
  local name=$1 tracked_contents=$2 expect=$3
  local dir stub project got=0

  server_id_dir="$(mktemp -d "${TMPDIR:-/tmp}/brainstorm-ignore-test.XXXXXX")"
  dir="$server_id_dir"
  stub="$dir/bin"
  project="$dir/project"
  mkdir -p "$stub" "$project"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "server-started\n"' >"$stub/node"
  chmod +x "$stub/node"

  git -C "$project" init -q
  git -C "$project" config user.email test@example.com
  git -C "$project" config user.name 'Test'
  printf 'seed\n' >"$project/README.md"
  git -C "$project" add README.md
  git -C "$project" commit -qm seed
  if [ -n "$tracked_contents" ]; then
    mkdir -p "$project/.agent"
    printf '%s\n' "$tracked_contents" >"$project/.agent/.gitignore"
    git -C "$project" add -f .agent/.gitignore
    git -C "$project" commit -qm 'repo tracks its own .agent/.gitignore'
  fi

  PATH="$stub:$PATH" "$SCRIPT" --project-dir "$project" \
    >"$dir/out" 2>"$dir/err" || got=$?

  if [ "$expect" = refuses ]; then
    if [ "$got" -ne 0 ] && grep -qF 'refusing to modify it' "$dir/out" "$dir/err" &&
      [ "$(cat "$project/.agent/.gitignore")" = "$tracked_contents" ]; then
      passed=$((passed + 1))
      printf '  ok   %s\n' "$name"
    else
      failed=$((failed + 1))
      printf '  FAIL %s (exit=%s, tracked file now: %s)\n' \
        "$name" "$got" "$(cat "$project/.agent/.gitignore")"
    fi
  elif [ "$(cat "$project/.agent/.gitignore" 2>/dev/null)" = '*' ] &&
    [ -z "$(git -C "$project" status --porcelain)" ]; then
    passed=$((passed + 1))
    printf '  ok   %s\n' "$name"
  else
    failed=$((failed + 1))
    printf '  FAIL %s (ignore file=%s, status=%s)\n' "$name" \
      "$(cat "$project/.agent/.gitignore" 2>/dev/null)" \
      "$(git -C "$project" status --porcelain)"
  fi

  cleanup_server_id_dir
}

# The branch a boolean test of `ls-files` would swallow: rev-parse still reports a
# repository while the index is unreadable, so the query exits 128 and the answer
# is unknown. Writing through on that is how a tracked ignore file gets clobbered.
run_unanswerable_case() {
  local name='an unanswerable tracked-query stops rather than clobbering'
  local dir stub project got=0

  server_id_dir="$(mktemp -d "${TMPDIR:-/tmp}/brainstorm-ignore-test.XXXXXX")"
  dir="$server_id_dir"
  stub="$dir/bin"
  project="$dir/project"
  mkdir -p "$stub" "$project"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "server-started\n"' >"$stub/node"
  chmod +x "$stub/node"

  git -C "$project" init -q
  git -C "$project" config user.email test@example.com
  git -C "$project" config user.name 'Test'
  printf 'seed\n' >"$project/README.md"
  git -C "$project" add README.md
  git -C "$project" commit -qm seed
  chmod 000 "$project/.git/index"

  PATH="$stub:$PATH" "$SCRIPT" --project-dir "$project" \
    >"$dir/out" 2>"$dir/err" || got=$?
  chmod 644 "$project/.git/index"

  if [ "$got" -ne 0 ] && grep -qF 'cannot determine whether' "$dir/out" "$dir/err"; then
    passed=$((passed + 1))
    printf '  ok   %s\n' "$name"
  else
    failed=$((failed + 1))
    printf '  FAIL %s (exit=%s)\n' "$name" "$got"
    sed -n '1,4p' "$dir/out" "$dir/err"
  fi

  cleanup_server_id_dir
}

main() {
  printf 'start-server.sh\n\n'
  run_case "missing --host value" 1 "--host requires a value" --host
  run_case "next flag is not a --host value" 1 "--host requires a value" \
    --host --url-host localhost
  run_case "missing --project-dir value" 1 "--project-dir requires a value" \
    --project-dir
  run_case "missing --url-host value" 1 "--url-host requires a value" --url-host
  run_case "zero idle timeout rejected" 1 "must be a positive integer" \
    --idle-timeout-minutes 0
  run_case "unknown flag rejected" 1 "Unknown argument: --bogus" --bogus
  # 32 characters each, so the {32,64} bound is satisfied and the character
  # class is the only thing left to decide the outcome.
  run_server_id_case "ASCII server id is kept" \
    "abcd0123456789012345678901234567" accepted
  run_server_id_case "accented server id falls back to the hex generator" \
    "abéc0123456789012345678901234567" rejected
  run_ignore_case "project state is ignored without touching a tracked file" \
    "" writes
  run_ignore_case "a tracked ignore file that exposes state is not overwritten" \
    "unrelated-entry" refuses
  # root ignores the mode bit this case turns on, so it would pass while proving
  # nothing. Skip it loudly rather than bank a false green (ADR 0023).
  if [ "$(id -u)" -eq 0 ]; then
    printf '  skip run as root: the unreadable-index case proves nothing\n'
  else
    run_unanswerable_case
  fi

  printf '\n%d passed, %d failed\n' "$passed" "$failed"
  [ "$failed" -eq 0 ]
}

main "$@"
