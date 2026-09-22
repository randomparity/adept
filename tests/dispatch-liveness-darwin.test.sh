#!/bin/bash
# The wait in references/dispatch-liveness.md must run without GNU timeout.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
doc="$root/references/dispatch-liveness.md"

if grep -q 'timeout 3600' "$doc"; then
  echo "dispatch-liveness.md still prescribes timeout(1)" >&2
  exit 1
fi

work=$(mktemp -d)
set +e
timeout 2 bash -c 'until false; do sleep 1; done' >"$work/red.out" 2>"$work/red.err"
red=$?
set -e
if [ "$red" -eq 0 ]; then
  echo "bare timeout unexpectedly succeeded" >&2
  exit 1
fi
if ! grep -q "command not found" "$work/red.err"; then
  echo "expected command not found" >&2
  cat "$work/red.err" >&2
  exit 1
fi

deadline=$(( $(date +%s) + 1 ))
status=0
until false; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    status=124
    break
  fi
  sleep 1
done
[ "$status" -eq 124 ]
echo "dispatch wait darwin ok (timeout exit $red, status $status)"
rm -rf "$work"
