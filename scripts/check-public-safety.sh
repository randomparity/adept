#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Keep the repository gate's default scope while sharing the skill's scanner.
if [ "$#" -eq 0 ]; then
	set -- "$ROOT"
fi
exec "$ROOT/skills/quest/scripts/check-public-safety" "$@"
