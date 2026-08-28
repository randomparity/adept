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

**Return the removal command's status.** verified: issue #77 reproduces a clean
`check-ripgrep-config.sh` run printing its ok line and then exiting 1 under a failing `rm`, which
borrows the status reserved for a content finding.

**Always replace the incoming status with exit 2.** judgment: correctness; cleanup is secondary to
the gate or CI verdict already earned and must not hide it.

**Extract a shared cleanup helper.** judgment: scope and fit; the two gates have different scratch
ownership and worktree-removal steps, and this is only the second production repetition.
