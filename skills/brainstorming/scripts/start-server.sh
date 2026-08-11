#!/usr/bin/env bash
set -euo pipefail

# Start the brainstorm server and output connection info
# Usage: start-server.sh [--project-dir <path>] [--host <bind-host>] [--url-host <display-host>] [--foreground] [--background]
#
# Starts server on a random high port, outputs JSON with URL.
# Each session gets its own directory to avoid conflicts.
#
# Options:
#   --project-dir <path>  Store session files under <path>/.agent/brainstorm/
#                         instead of /tmp. Files persist after server stops.
#   --host <bind-host>    Host/interface to bind (default: 127.0.0.1).
#                         Use 0.0.0.0 in remote/containerized environments.
#   --url-host <host>     Hostname shown in returned URL JSON.
#   --idle-timeout-minutes <n>  Shut down after n minutes idle (default 240 = 4h).
#   --open                Auto-open the browser on the first screen (use only
#                         after the user approves the visual companion).
#   --foreground          Run server in the current terminal (no backgrounding).
#   --background          Force background mode (overrides Codex auto-foreground).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

json_error() {
  printf '{"error": "%s"}\n' "$1"
}

require_value() {
  local flag=$1 value=${2-}
  if [[ -z "$value" || "$value" == --* ]]; then
    json_error "$flag requires a value"
    exit 1
  fi
  REQUIRED_VALUE=$value
}

# Parse arguments
PROJECT_DIR=""
FOREGROUND="false"
FORCE_BACKGROUND="false"
BIND_HOST="127.0.0.1"
URL_HOST=""
IDLE_TIMEOUT_MINUTES=""
REQUIRED_VALUE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
  --project-dir)
    require_value "$1" "${2-}"
    PROJECT_DIR=$REQUIRED_VALUE
    shift 2
    ;;
  --host)
    require_value "$1" "${2-}"
    BIND_HOST=$REQUIRED_VALUE
    shift 2
    ;;
  --url-host)
    require_value "$1" "${2-}"
    URL_HOST=$REQUIRED_VALUE
    shift 2
    ;;
  --idle-timeout-minutes)
    require_value "$1" "${2-}"
    IDLE_TIMEOUT_MINUTES=$REQUIRED_VALUE
    shift 2
    ;;
  --open)
    export BRAINSTORM_OPEN=1
    shift
    ;;
  --foreground | --no-daemon)
    FOREGROUND="true"
    shift
    ;;
  --background | --daemon)
    FORCE_BACKGROUND="true"
    shift
    ;;
  *)
    json_error "Unknown argument: $1"
    exit 1
    ;;
  esac
done

if [[ -z "$URL_HOST" ]]; then
  if [[ "$BIND_HOST" == "127.0.0.1" || "$BIND_HOST" == "localhost" ]]; then
    URL_HOST="localhost"
  else
    URL_HOST="$BIND_HOST"
  fi
fi

if [[ -n "$IDLE_TIMEOUT_MINUTES" ]]; then
  if ! [[ "$IDLE_TIMEOUT_MINUTES" =~ ^[0-9]+$ ]] || [[ "$IDLE_TIMEOUT_MINUTES" -lt 1 ]]; then
    echo "{\"error\": \"--idle-timeout-minutes must be a positive integer\"}"
    exit 1
  fi
  export BRAINSTORM_IDLE_TIMEOUT_MS=$((IDLE_TIMEOUT_MINUTES * 60 * 1000))
fi

# server.cjs is the whole companion; without node the script would otherwise create a
# session directory, kill any running server, and only then fail with a bare
# "node: command not found" on a backgrounded process whose output goes to the log.
if ! command -v node >/dev/null 2>&1; then
  echo "{\"error\": \"node not found on PATH; the brainstorm visual companion needs Node.js to run server.cjs\"}"
  exit 1
fi

is_windows_like_shell() {
  case "${OSTYPE:-}" in
  msys* | cygwin* | mingw*) return 0 ;;
  esac
  if [[ -n "${MSYSTEM:-}" ]]; then
    return 0
  fi
  local uname_s
  uname_s="$(uname -s 2>/dev/null || true)"
  case "$uname_s" in
  MSYS* | MINGW* | CYGWIN*) return 0 ;;
  esac
  return 1
}

# Some environments reap detached/background processes. Auto-foreground when detected.
if [[ -n "${CODEX_CI:-}" && "$FOREGROUND" != "true" && "$FORCE_BACKGROUND" != "true" ]]; then
  FOREGROUND="true"
fi

# Windows/Git Bash reaps nohup background processes. Auto-foreground when detected.
if [[ "$FOREGROUND" != "true" && "$FORCE_BACKGROUND" != "true" ]]; then
  if is_windows_like_shell; then
    FOREGROUND="true"
  fi
fi

# Session files (server.log, server-info, .last-token) embed the session key —
# keep everything this script and the server create owner-only.
umask 077

# Generate unique session directory
SESSION_ID="$$-$(date +%s)"

if [[ -n "$PROJECT_DIR" ]]; then
  mkdir -p "${PROJECT_DIR}/.agent"
  # umask 077 above is for session files that embed the session key. .agent/ is a
  # directory two skills share, so pin its mode here instead of letting whichever
  # skill runs first decide it. The session directories below stay 0700.
  chmod 755 "${PROJECT_DIR}/.agent"

  # A self-ignoring .gitignore at the .agent/ root keeps sessions out of git
  # without touching a tracked file. --project-dir is not required to be a
  # repository, so no repository means nothing to keep out of git and no reason
  # to write the file at all -- that also covers a host with no git, where the
  # question cannot be asked and skipping the write is the safe answer.
  if git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    # Inside a repository the three answers are kept apart rather than tested as
    # a boolean: 0 is tracked, 1 is untracked, and anything else means the query
    # went unanswered. Folding the last into "untracked" would overwrite the
    # tracked file this check exists to protect. Output is discarded because the
    # untracked path prints git's pathspec error to stderr.
    PROJECT_TRACKED=0
    git -C "$PROJECT_DIR" ls-files --error-unmatch .agent/.gitignore >/dev/null 2>&1 ||
      PROJECT_TRACKED=$?

    case "$PROJECT_TRACKED" in
    0)
      # Tracked is not automatically fatal: a repository that tracks its own
      # ignore file and already covers .agent/brainstorm/ is the benign case.
      # Verify the outcome rather than refusing on the mechanism.
      if ! git -C "$PROJECT_DIR" check-ignore -q .agent/brainstorm/; then
        echo "{\"error\": \"${PROJECT_DIR}/.agent/.gitignore is tracked in this repository and does not ignore .agent/brainstorm/; refusing to modify it\"}"
        exit 1
      fi
      ;;
    1)
      # Temp file then rename, not a plain redirect: the redirect truncates
      # before it writes, and a concurrent reader of the ignore file sees the
      # empty gap. The trap is what keeps an interrupted run from leaving a
      # .gitignore.XXXXXX behind with no ignore file to cover it.
      IGNORE_TMP=$(mktemp "${PROJECT_DIR}/.agent/.gitignore.XXXXXX")
      trap 'rm -f "$IGNORE_TMP"' EXIT
      printf '*\n' >"$IGNORE_TMP"
      chmod 644 "$IGNORE_TMP"
      mv -f "$IGNORE_TMP" "${PROJECT_DIR}/.agent/.gitignore"
      trap - EXIT
      ;;
    *)
      echo "{\"error\": \"cannot determine whether ${PROJECT_DIR}/.agent/.gitignore is tracked (git exited ${PROJECT_TRACKED})\"}"
      exit 1
      ;;
    esac
  fi

  SESSION_DIR="${PROJECT_DIR}/.agent/brainstorm/${SESSION_ID}"
  # Persist the bound port and key per project so a restart reuses them and an
  # already-open browser tab reconnects to the same URL with a valid cookie.
  export BRAINSTORM_PORT_FILE="${PROJECT_DIR}/.agent/brainstorm/.last-port"
  export BRAINSTORM_TOKEN_FILE="${PROJECT_DIR}/.agent/brainstorm/.last-token"
else
  SESSION_DIR="/tmp/brainstorm-${SESSION_ID}"
fi

STATE_DIR="${SESSION_DIR}/state"
PID_FILE="${STATE_DIR}/server.pid"
LOG_FILE="${STATE_DIR}/server.log"
SERVER_ID_FILE="${STATE_DIR}/server-instance-id"

# Create fresh session directory with content and state peers
mkdir -p "${SESSION_DIR}/content" "$STATE_DIR"

# Enumerated, not the range [A-Za-z0-9_-]: a bash bracket expression takes its
# ranges from the locale's collation, so under a territory UTF-8 locale -- the
# ordinary interactive setting -- [A-Za-z] admits accented letters, and an id
# this guard is meant to reject is written to disk and handed to the server
# instead. Pinning the collation would mean an `LC_ALL=C` subshell around the
# match, since a variable assignment cannot prefix the `[[` builtin.
# Do not "simplify" this back to a range;
# tests/fixtures/brainstorming/start-server-test.sh fails if you do.
# stop-server.sh reads this id back and spells the same set out.
SERVER_ID_CHARS='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-'
readonly SERVER_ID_CHARS

SERVER_ID=""
if [[ -r /dev/urandom ]]; then
  SERVER_ID="$(od -An -N24 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n' || true)"
fi
if ! [[ "$SERVER_ID" =~ ^[$SERVER_ID_CHARS]{32,64}$ ]]; then
  SERVER_ID="$(printf '%08x%08x%08x%08x' "$$" "$(date +%s)" "${RANDOM:-0}" "${RANDOM:-0}")"
fi
printf '%s\n' "$SERVER_ID" >"$SERVER_ID_FILE"
chmod 600 "$SERVER_ID_FILE" 2>/dev/null || true

# Kill any existing server
if [[ -f "$PID_FILE" ]]; then
  old_pid=$(cat "$PID_FILE")
  kill "$old_pid" 2>/dev/null
  rm -f "$PID_FILE"
fi

cd "$SCRIPT_DIR" || exit 1

# Resolve the harness PID (grandparent of this script).
# $PPID is the ephemeral shell the harness spawned to run us — it dies
# when this script exits. The harness itself is $PPID's parent.
OWNER_PID="$(ps -o ppid= -p "$PPID" 2>/dev/null | tr -d ' ')"
if [[ -z "$OWNER_PID" || "$OWNER_PID" == "1" ]]; then
  OWNER_PID="$PPID"
fi

# Windows/MSYS2: Node.js cannot see POSIX PIDs from the MSYS2 namespace.
# Passing a PID node cannot verify causes server to log owner-pid-invalid
# and self-terminate at the 60-second lifecycle check. Clear it so the
# watchdog is disabled and the idle timeout becomes the only shutdown trigger.
if is_windows_like_shell; then
  OWNER_PID=""
fi

# Foreground mode for environments that reap detached/background processes.
if [[ "$FOREGROUND" == "true" ]]; then
  env BRAINSTORM_DIR="$SESSION_DIR" BRAINSTORM_HOST="$BIND_HOST" BRAINSTORM_URL_HOST="$URL_HOST" BRAINSTORM_OWNER_PID="$OWNER_PID" node server.cjs "--brainstorm-server-id=$SERVER_ID" &
  SERVER_PID=$!
  echo "$SERVER_PID" >"$PID_FILE"
  wait "$SERVER_PID"
  exit $?
fi

# Start server, capturing output to log file
# Use nohup to survive shell exit; disown to remove from job table
nohup env BRAINSTORM_DIR="$SESSION_DIR" BRAINSTORM_HOST="$BIND_HOST" BRAINSTORM_URL_HOST="$URL_HOST" BRAINSTORM_OWNER_PID="$OWNER_PID" node server.cjs "--brainstorm-server-id=$SERVER_ID" >"$LOG_FILE" 2>&1 &
SERVER_PID=$!
disown "$SERVER_PID" 2>/dev/null
echo "$SERVER_PID" >"$PID_FILE"

# Wait for server-started message (check log file)
for _ in {1..50}; do
  if grep -q "server-started" "$LOG_FILE" 2>/dev/null; then
    # Verify server is still alive after a short window (catches process reapers)
    alive="true"
    for _ in {1..20}; do
      if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        alive="false"
        break
      fi
      sleep 0.1
    done
    if [[ "$alive" != "true" ]]; then
      echo "{\"error\": \"Server started but was killed. Retry in a persistent terminal with: $SCRIPT_DIR/start-server.sh${PROJECT_DIR:+ --project-dir $PROJECT_DIR} --host $BIND_HOST --url-host $URL_HOST --foreground\"}"
      exit 1
    fi
    grep "server-started" "$LOG_FILE" | head -1
    exit 0
  fi
  sleep 0.1
done

# Timeout - server didn't start
echo '{"error": "Server failed to start within 5 seconds"}'
exit 1
