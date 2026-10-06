# Standing repair accepted-location bar — issue #448

Charter: issue #448 `WORK:SCOPE` token `q448-a6ef9cd4`; operator-approved exclusions are
retained there. Design denominator: 100 changed lines (S). Decision:
[ADR 0082](../../adr/0082-standing-repairs-bar-instruction-locations.md), extending ADR 0064
and ADR 0081.

## Problem

A policy-admitted repair may change an accepted instruction location and so restore an
earlier approved blob of the declaring file, reviving revoked authority without a human.

## Scope

- `skills/quest-log/SKILL.md`, *Standing repair authority*: one normative paragraph stating
  the bar (the definition all callers point to); the recheck list applies it; the
  policy-bound merge predicate requires it.
- `skills/quest/SKILL.md`: the scope-freeze admission sentence and the built-diff recheck name
  the bar.
- `skills/campaign/SKILL.md`: the policy-bound provenance paragraph, the unattended
  pending→policy-bound move, and the pre-merge policy recheck name the bar.
- `skills/return-to-town/SKILL.md`: unchanged, checked — it names "standing-policy
  admission" without restating its predicate, so quest-log's definition reaches it.
- `.claude-plugin/plugin.json`: 7.5.0 → 7.6.0.
- Ownership: quest-log keeps the rule; consumers name it; no caller migrates and no path
  becomes obsolete.

The touched-path set is `git diff --no-renames --name-only <base>...<head>`: three-dot so
base-only changes are excluded, `--no-renames` so a rename lists both paths, and mode-only
changes are listed. Before a diff exists, a packet whose frozen `surface` (a campaign row's
file scope) names or could match an accepted path is barred; unknown fit falls back, as today.

## Failure model

1. Actors and deployments: an unattended quest or campaign worker evaluating a standing
   policy on a repository's protected base; a maintainer approving policy PRs.
2. Invariants and assets: no repair changes `AGENTS.md`, `CLAUDE.md`, or `.claude/CLAUDE.md`
   under policy authority alone; ADR 0064/0081 binding and location rules unchanged.
3. Accepted failure classes: a legitimate instruction-file repair loses policy admission and
   waits for a human — the intended cost; a case variant such as `Claude.md` is not barred —
   it declares nothing, because the base read uses exact tree paths (ADR 0081).
4. Covered elsewhere: nested, local, or user-level instruction files (excluded; separate
   follow-up); risk-only policy paths in `$sort-board` and `$bounty` (excluded; they write no
   diff); commit-bound gate wording (`references/merge-gate.md`).

### Threat model

- Boundary narrowed: standing-policy admission and policy-bound merge. None added or widened.
- Actor: a repair actor with branch or PR write access acting under an admitted policy.
- Control: the bar on the packet surface at admission and on the actual three-dot diff at
  each recheck, last immediately before the final merge gate on the evaluated head SHA; a head
  change already forces re-evaluation (campaign).
- Out of scope: a compromised maintainer approval or protected-branch bypass — ADR 0064.

## Success

1. quest-log states the bar once, for exactly the three accepted paths, and applies it at
   admission, every recheck, and the policy-bound merge predicate.
2. quest and campaign name the bar where they restate admission or merge predicates.
3. `just verify`, `just records`, `just plugin-check`, and `just version-check` exit 0.

## Validation

- Skill prose (quest-log, quest, campaign): `task-test-not-applicable` — Markdown policy prose
  with no executable consumer; anatomy rule 4 forbids asserting on it. Read against ADR 0082.
- ADR 0082 record shape: `focused-test` — `just records` exits 0; red when a section is missing.
- Plugin version: `focused-test` — `BASE_SHA=$(git rev-parse origin/main) just version-check`
  exits 1 before the bump, 0 at 7.6.0.
