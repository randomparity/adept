#!/usr/bin/env bash
# Regression tests for stop-server.sh server-id validation.

set -euo pipefail

# ripgrep applies RIPGREP_CONFIG_PATH's contents as arguments ahead of the ones
# passed below, so a personal ripgreprc would otherwise steer this suite's own
# matching.
unset RIPGREP_CONFIG_PATH

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# The suite lives in tests/fixtures/ so it is excluded from the installed
# payload; the script it exercises ships under skills/.
SCRIPT="$SCRIPT_DIR/../../../skills/brainstorming/scripts/stop-server.sh"

passed=0
failed=0

# The server-id grammar is an ASCII bracket expression, and bash takes a bracket
# range from the locale's collation -- so the property worth asserting is that it
# bites under the locale a developer actually runs, not under whichever one this
# suite inherits. Pin a territory UTF-8 locale where the host has one. `C.UTF-8`
# is deliberately not accepted as a substitute: it does not reproduce the
# collation behaviour, so a case that settled for it would pass while the defect
# was live (ADR 0023). With no such locale the accented id is rejected whatever
# the grammar, so the case still passes -- it just stops proving the property.
utf8_locale=$(locale -a 2>/dev/null |
  rg -N -m1 '^[a-z]{2}_[A-Z]{2}\.(utf8|UTF-8)$' || true)
if [ -z "$utf8_locale" ]; then
  printf 'note: no territory UTF-8 locale; the accented case proves nothing\n' >&2
fi

session=""
fake_pid=""

cleanup() {
  if [ -n "$fake_pid" ]; then
    kill "$fake_pid" 2>/dev/null || true
    wait "$fake_pid" 2>/dev/null || true
    fake_pid=""
  fi
  if [ -n "$session" ] && [ -d "$session" ]; then
    rm -R "$session"
  fi
  session=""
}
trap cleanup EXIT

# stop-server.sh signals a pid only once it has matched this session's per-start
# instance id against the process's own argv, so the id is the only thing left to
# decide the verdict. `exec -a` puts the marker in that argv and leaves a single
# process behind: a `bash -c 'sleep 300'` stand-in would orphan its sleep child
# when stop-server.sh kills the shell. stop-server.sh compares every cmdline
# entry, so argv[0] carries it.
run_case() {
  local name=$1 id=$2 want=$3
  local state got

  session="$(mktemp -d "${TMPDIR:-/tmp}/brainstorm-stop-test.XXXXXX")"
  state="$session/state"
  mkdir -p "$state"
  printf '%s\n' "$id" >"$state/server-instance-id"

  bash -c 'exec -a "$0" sleep 300' "--brainstorm-server-id=$id" &
  fake_pid=$!
  printf '%s\n' "$fake_pid" >"$state/server.pid"

  got="$(LC_ALL="${utf8_locale:-C}" "$SCRIPT" "$session" 2>&1 || true)"

  case "$got" in
  *"\"status\": \"$want\""*)
    passed=$((passed + 1))
    printf '  ok   %s\n' "$name"
    ;;
  *)
    failed=$((failed + 1))
    printf '  FAIL %s (wanted status %s, got: %s)\n' "$name" "$want" "$got"
    ;;
  esac

  cleanup
}

main() {
  printf 'stop-server.sh\n\n'
  # 32 characters each, so the {32,64} bound is satisfied and the character class
  # is the only thing left to decide the outcome. The ASCII case is the control
  # that proves this harness reaches the kill path at all -- without it a case
  # that failed for any other reason would report stale_pid and look correct.
  run_case "ASCII server id stops the server" \
    "abcd0123456789012345678901234567" stopped
  # Written as a range the guard admits the accented id under a territory UTF-8
  # locale, and stop-server.sh signals a process it has not actually identified.
  run_case "accented server id is not a match" \
    "abéc0123456789012345678901234567" stale_pid

  printf '\n%d passed, %d failed\n' "$passed" "$failed"
  [ "$failed" -eq 0 ]
}

main "$@"
