# Agent-neutral install requirements

This document records what any coding agent without an adept plugin marketplace must be
given for adept skills to work: the file tree, how `<plugin root>` resolves, and which adept
features exist only for Claude Code and Codex. Each agent's own document links here and
records only what is specific to that agent, starting with its install root. Each claim is
marked with one of three markers:

- **verified** — confirmed by static inspection of this repository (source code, documentation).
  Environment: macOS arm64, 2026-10-29, no live Bob session.
- **documented** — stated in the agent's published documentation but not tested against a live
  instance in this run.
- **unverified** — neither tested against a live instance nor documented by the agent's vendor.
  Behaviour is inferred from repository source or logical inference.

`<install root>` is the directory that holds the agent's `skills/` directory — for example
`~/.<agent>/` for a global install, or `<project>/.<agent>/` for a project install. Each agent
document names its own.

Agent documents: [IBM Bob](bob-install-requirements.md).

Related: issue #478, ADR 0001 (`docs/adr/0001-distribution-via-plugin-marketplace.md`).

---

## 1. Minimum file tree

An install must produce the following tree for adept skills to work.

### Global install (`~/.<agent>/skills/`)

```
<install root>
├── skills/
│   ├── attunement/         # all files from skills/attunement/
│   ├── bounty/
│   ├── campaign/
│   ├── … (one directory per skill) …
│   └── quest/
├── references/             # files from references/ at repo root
│   ├── dispatch-liveness.md
│   ├── heed-counsel.md
│   ├── merge-gate.md
│   ├── model-mapping.md
│   ├── model-selection.md
│   ├── network-bounds.md
│   ├── numbered-reservations.md
│   ├── review-depth.md
│   ├── review-lenses.md
│   ├── trial-by-fire.md
│   └── true-seeing.md
└── scripts/
    └── check-public-safety.sh  # root-level wrapper
```

**Note on `scripts/check-public-safety.sh`:** **verified** — this file
(`scripts/check-public-safety.sh:4,9`) resolves `ROOT` as the directory two levels above
itself and then `exec`s `$ROOT/skills/quest/scripts/check-public-safety "$@"`. An install
that copies only the `skills/` tree will not have this wrapper and will not have the inner
scanner. A full tree copy is required. The inner scanner lives at
`skills/quest/scripts/check-public-safety`.

**Note on `references/` location:** **verified** — every script that addresses shared
standards uses a path like `../../references/` relative to a skill's own subdirectory
(e.g. `skills/quest/SKILL.md:57`, `skills/forge/SKILL.md:239`). The directory must be a
sibling of `skills/`, not nested inside it.

### Project install (`<project>/.<agent>/skills/`)

Same tree as the global install, but rooted at `<project>/.<agent>/` instead of `~/.<agent>/`.

---

## 2. `<plugin root>` resolution: copy install vs symlink install

The `<plugin root>` convention is defined in skill text as "the directory two levels above
this skill's own directory" (e.g. `skills/attunement/SKILL.md:33–36`). Scripts resolve it at
runtime using `$BASH_SOURCE[0]`.

**Copy install** (all files copied into `<install root>`): **verified** — all scripts resolve
ROOT correctly because the physical directory three levels up from any script is the copy
root. Both logical (`cd --`) and physical (`cd -P`) resolution agree when no symlinks are
present.

**Symlink install** (skill directories symlinked into `<install root>/skills/<name>`):
**unverified** — behaviour depends on whether each script uses logical or physical `cd`:

| Script | Resolution | ROOT under a symlink install |
|--------|-----------|------------------------------|
| `skills/deliver/scripts/deliver-write` | logical (`cd -- "$SCRIPT_DIR/../../.."`) | Resolves to `<install root>` (the directory containing `skills/`) |
| `skills/return-to-town/scripts/publish-handoff` | physical (`cd -P -- "$SCRIPT_DIR/../../.."`) | Resolves to the physical checkout |
| `skills/return-to-town/scripts/refresh-merge` | physical (`cd -P -- "$SCRIPT_DIR/../../.."`) | Resolves to the physical checkout |
| `skills/quest/scripts/publish-forge-review` | logical (`cd "$SCRIPT_DIR"`) then `../../..` | Resolves to `<install root>` |
| `skills/bounty/scripts/create-verified-issue.sh` | physical (`pwd -P`) | Resolves to the physical checkout |

Issue #478's body (`Evidence: Symlink sensitivity`) reported a measurement on macOS arm64
(not re-run in this review) confirming the table's split result: logical-`cd` scripts
resolve ROOT to `<install root>`, while physical-`cd` scripts resolve it to the checkout. The
scripts therefore disagree with each other. A logical-`cd` script expects to find
`references/` and `scripts/check-public-safety.sh` inside `<install root>`; a physical-`cd`
script expects them in the checkout. Neither assumption holds for both script types
simultaneously.

**Supported path:** A copy install (no symlinks) is the only configuration where all
scripts agree on ROOT. A symlink install requires additional work (e.g. a symlink forest in
`<install root>` that mirrors `references/` and `scripts/`) to satisfy both; this work has not
been done.

---

## 3. adept features specific to Claude Code and Codex

The following adept capabilities are Claude Code– and Codex-specific. Each agent document
records whether that agent has an equivalent.

| Feature | adept location |
|---------|---------------|
| `$name` invocation shorthand (e.g. `$quest`) | Skill descriptions reference these as shorthand used by Claude Code / Codex operators |
| `agents/openai.yaml` per-skill worker manifests | `skills/*/agents/openai.yaml` (22 skills) |
| Skills plugin marketplace | `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json` |
| Version field | `.claude-plugin/plugin.json` (via ADR 0022) |

**`agents/openai.yaml` detail:** Each file provides a Codex CLI interface definition (display
name, short description, default prompt) used when a skill is invoked as an OpenAI Codex
agent.
