# 0045 — Cleanup faults preserve the earned status

## Status

Accepted (2026-08-27)

## Context

Repository gates reserve exit 1 for a content finding and exit 2 for a fault that prevents a
clean verdict. An EXIT trap runs after the gate has earned its status, but an unguarded scratch
removal can replace that status. `check-ripgrep-config.sh` consequently turns a clean run into an
unnamed finding when `rm` fails, while `verify-push.sh` bypasses its cleanup-failure accounting on
the ordinary removal branch.

## Decision

Cleanup captures the status that entered the EXIT trap. A failed or refused scratch removal names
the retained path and exits 2 only when the incoming status was 0. When the gate already earned a
non-zero status, cleanup reports the retained path and preserves that status.

Cleanup success returns the incoming status unchanged. Each gate keeps this accounting locally;
the two sites do not introduce a shared helper.

## Consequences

Exit 1 continues to mean a named content finding, cleanup faults become distinguishable at exit 2,
and a real finding or CI failure cannot be hidden by a later cleanup failure. Failed cleanup leaves
a named path for manual recovery. Both suites need controlled failing-removal coverage for clean
and already-failing runs.

## Considered & rejected

**Ignore cleanup failures.** judgment: observability; silence would leave scratch state behind
without telling the operator where it is.

**Return the removal command's status.** verified: at base commit
`48a814c6f6c94791134d52b8ddc1a51d7b897b31`,
`bash -c 'set -e; cleanup(){ false; }; trap cleanup EXIT; printf "ok\n"'` printed `ok` and
exited 1 under GNU Bash 5.3.9 on x86_64 Linux, reproducing the status replacement reported by
issue #77.

**Always replace the incoming status with exit 2.** judgment: correctness; cleanup is secondary to
the gate or CI verdict already earned and must not hide it.

**Extract a shared cleanup helper.** verified: at base commit
`48a814c6f6c94791134d52b8ddc1a51d7b897b31`,
`sed -n '60,70p' scripts/check-ripgrep-config.sh` showed one guarded scratch-directory removal,
while `sed -n '126,144p' scripts/verify-push.sh` showed worktree removal followed by scratch-root
removal. Judgment: a shared abstraction across those different responsibilities is outside this
two-site correction and would add more surface than it removes.
