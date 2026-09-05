#!/usr/bin/env bash
# Build one deterministic fixture repository for the agent-behaviour evaluation cases in
# docs/workflow/specs/2026-09-05-forge-worker-accountability-design.md.
#
# The evaluation is a fresh evaluator reading changed instructions. What it needs from here is a
# repository whose git state is exactly the shape a case names, built identically every run, so
# two evaluations of the same case are comparable.
#
# Usage: eval-fixtures.sh SHAPE DESTINATION
#
#   normal         one implementation file and one test file changed by the task commit
#   tests-only     the task commit changes only the named test file
#   no-trailer     normal, but the task commit carries no Forge-Dispatch trailer
#   foreign-unit   normal, but the task commit carries task-9.1 while the task under test is 4
#   both-attempts  two task commits, task-4.1 and task-4.2, inside one range
set -euo pipefail

[ $# -eq 2 ] || {
	printf 'usage: eval-fixtures.sh SHAPE DESTINATION\n' >&2
	exit 2
}
shape=$1
destination=$2

# Refused rather than reused: a fixture built on top of a previous one is not the shape its case
# names, and the evaluation would report against a repository nobody described.
[ ! -e "$destination" ] || {
	printf 'eval-fixtures: %s already exists\n' "$destination" >&2
	exit 3
}

case $shape in
normal | tests-only | no-trailer | foreign-unit | both-attempts) ;;
*)
	printf 'eval-fixtures: unknown shape: %s\n' "$shape" >&2
	exit 2
	;;
esac

mkdir -p "$destination"
git -C "$destination" init -q
git -C "$destination" config user.email fixture@example.invalid
git -C "$destination" config user.name Fixture

printf 'old\n' >"$destination/impl.sh"
git -C "$destination" add -A
git -C "$destination" commit -qm 'base'
base=$(git -C "$destination" rev-parse HEAD)

commit_task() { # message trailer-or-empty
	git -C "$destination" add -A
	if [ -n "$2" ]; then
		git -C "$destination" commit -qm "$1" -m "Forge-Dispatch: $2"
	else
		git -C "$destination" commit -qm "$1"
	fi
}

case $shape in
normal | no-trailer | foreign-unit)
	printf 'new\n' >"$destination/impl.sh"
	printf '#!/usr/bin/env bash\ngrep -q new impl.sh\n' >"$destination/impl-test.sh"
	case $shape in
	normal) commit_task 'feat: implement' 'task-4.1' ;;
	no-trailer) commit_task 'feat: implement' '' ;;
	foreign-unit) commit_task 'feat: implement' 'task-9.1' ;;
	esac
	;;
tests-only)
	printf '#!/usr/bin/env bash\ntrue\n' >"$destination/impl-test.sh"
	commit_task 'test: add a case' 'task-4.1'
	;;
both-attempts)
	printf 'new\n' >"$destination/impl.sh"
	commit_task 'feat: first attempt' 'task-4.1'
	printf '#!/usr/bin/env bash\ngrep -q new impl.sh\n' >"$destination/impl-test.sh"
	commit_task 'feat: replacement' 'task-4.2'
	;;
esac

# A repository is not the evaluator's whole input. Eight of the ten rows turn on what the
# orchestrator reads *about* the task -- the inventory entry and the implementer's report -- so
# those are built here too. Improvised input makes two evaluation runs similar rather than
# comparable, and a case that drifts between runs measures the drift.
cat >"$destination/inventory.md" <<'INVENTORY'
## Verification

- `focused-test` — `impl-test.sh`. Expected red: the assertion fails because `impl.sh` is at its
  base content. Green command: `bash impl-test.sh`.
INVENTORY

cat >"$destination/inventory-not-applicable.md" <<'NOTAPPLICABLE'
## Verification

- `task-test-not-applicable` — the changed surface is prose in a record with no executable
  consumer, so no task-specific executable or structural observation could fail meaningfully.
NOTAPPLICABLE

# EV-10's command has to dirty a tracked path, so it needs its own inventory rather than a note
# telling the evaluator to improvise one. What it appends has to be inert: a bare word becomes a
# new command in the test script, which then dies 127 and is reported as a precondition failure
# before the residue check is ever reached -- exit 3, never the exit 6 this case exists for.
cat >"$destination/inventory-dirty.md" <<'DIRTY'
## Verification

- `focused-test` — `impl-test.sh`. Expected red: the assertion fails because `impl.sh` is at its
  base content. Green command: `bash -c 'printf "\n# dirtied\n" >>impl-test.sh; bash impl-test.sh'`.
DIRTY

# `Changed:` is computed rather than written, so the report matches whatever shape was built --
# a fixed report would tell the evaluator a `tests-only` task changed an implementation file.
cat >"$destination/report.md" <<REPORT
Status: DONE
Commits: $(git -C "$destination" rev-parse --short HEAD)
Changed: $(git -C "$destination" diff --no-renames --name-only "$base" HEAD | tr '\n' ' ')
Verification: focused-test impl-test.sh — RED \`bash impl-test.sh\` failed, GREEN \`bash impl-test.sh\` passed
REPORT

# The race case needs two reports, not one: the replacement's, above, and the original's arriving
# after it. Without this the evaluator has nothing to reconcile and EV-9 tests nothing.
if [ "$shape" = both-attempts ]; then
	cat >"$destination/report-late.md" <<LATE
Status: DONE
Commits: $(git -C "$destination" rev-parse --short 'HEAD~1')
Note: the original worker's report, arriving after its replacement was dispatched
LATE
fi

printf 'eval-fixtures: %s at %s (base %s, head %s)\n' \
	"$shape" "$destination" \
	"$(git -C "$destination" rev-parse --short "$base")" \
	"$(git -C "$destination" rev-parse --short HEAD)"
