# 0082 Standing-policy repairs never touch an accepted instruction location

## Status

Accepted (2026-10-06)

## Context

[ADR 0064](0064-standing-repair-authority-is-base-bound.md) binds standing repair authority
to the exact blob of the instruction file that declares it, and
[ADR 0081](0081-standing-repair-authority-locations.md) accepts that declaration at
`AGENTS.md`, `CLAUDE.md`, or `.claude/CLAUDE.md`. Neither stops a policy-admitted repair from
changing one of those files. A repair whose diff restores an earlier approved blob of the
declaring file would revive authority the maintainers later narrowed or revoked, with no
fresh human approval. ADR 0081 accepted that replay as a residual and deferred the bar here.

## Decision

Extend ADR 0064 and ADR 0081; every other guarantee of both stands unchanged. A repair whose
diff adds, edits, removes, or renames a path at any accepted instruction location — compared as
exact repo-relative paths, on both sides of a rename — receives no standing-policy admission
and no policy-bound merge, whatever the policy's permitted surfaces say. It takes the ordinary
per-repair human gate. The bar is checked against the frozen packet's `surface` until a diff
exists and against the actual diff at every later recheck, including immediately before the
final merge gate.

## Consequences

Changing a file that holds or could hold authority always needs a human, which is what a
policy approval of that file already asserts. A policy whose permitted surfaces cover an
accepted location stays valid for every other repair. The bar covers all three locations, not
only the declaring file, because adding the section elsewhere changes authority too. The
diff-time checks repeat the existing packet-fit rule on purpose, as a backstop for a wrong
surface-fit judgment at admission. Other instruction files — nested, local, or user-level —
declare nothing and are not barred.

## Considered & rejected

- **Keep the accepted residual.** judgment: maintainer revocation of a policy would be
  reversible by the repairs that policy admits.
- **Bar only the declaring file.** judgment: a repair adding the section at another accepted
  location changes authority too, and which file declares can change between checkpoints.
- **Bar only a diff that restores a previously approved blob.** judgment: it needs a history
  of approved blobs, the approval store ADR 0064 declines, and leaves other authority edits
  policy-admitted.
- **Reject any policy whose permitted surfaces cover an accepted location.** judgment: it
  revokes authority for every repair to stop the few that touch the location.
