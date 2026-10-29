# IBM Bob install requirements

This document records what a Bob user must supply to make adept skills work, and what
open decisions block a future installer. Each claim is marked **verified** or **unverified**
with the environment in which it was checked.

Verification key:
- **verified** — confirmed by static inspection of this repository (source code, documentation).
  Environment: macOS arm64, repository HEAD at `feat/bob-install-requirements-478`
  (2026-10-29), no live Bob session.
- **unverified** — not yet confirmed against a live Bob instance or documented by IBM.
  The stated behaviour is derived from Bob's published documentation, repository source,
  or logical inference and should be tested before an installer is written.

Related: issue #478, ADR 0001 (`docs/adr/0001-distribution-via-plugin-marketplace.md`).

---

## 1. Minimum file tree

A Bob install must produce the following tree for adept skills to work.
All paths are verified from repository source unless noted otherwise.

### Global install (`~/.bob/skills/`)

```
~/.bob/
└── skills/
    ├── attunement/         # all files from skills/attunement/
    ├── bounty/
    ├── campaign/
    ├── … (one directory per skill) …
    └── quest/
references/                 # all 11 files from references/ at repo root
    ├── dispatch-liveness.md
    ├── heed-counsel.md
    ├── merge-gate.md
    ├── model-mapping.md
    ├── model-selection.md
    ├── network-bounds.md
    ├── numbered-reservations.md
    ├── review-depth.md
    ├── review-lenses.md
    ├── trial-by-fire.md
    └── true-seeing.md
scripts/
└── check-public-safety.sh  # root-level wrapper
```

**Note on `scripts/check-public-safety.sh`:** **verified** — this file
(`scripts/check-public-safety.sh:3–9`) resolves `ROOT` as the directory two levels above
itself and then `exec`s `$ROOT/skills/quest/scripts/check-public-safety "$@"`. A Bob install
that copies only the `skills/` tree will not have this wrapper and will not have the inner
scanner. A full tree copy is required. The inner scanner lives at
`skills/quest/scripts/check-public-safety`.

**Note on `references/` location:** **verified** — every script that addresses shared
standards uses a path like `../../references/` relative to a skill's own subdirectory
(e.g. `skills/quest/SKILL.md:57`, `skills/forge/SKILL.md:239`). The directory must be a
sibling of `skills/`, not nested inside it.

### Project install (`<project>/.bob/skills/`)

Same tree as the global install, but rooted at `<project>/.bob/` instead of `~/.bob/`. Bob's
skill location docs state that project skills take precedence over global ones on name
collision (see §4 below), so a project install can shadow a global one.

---

## 2. `<plugin root>` resolution: copy install vs symlink install

The `<plugin root>` convention is defined in skill text as "the directory two levels above
this skill's own directory" (e.g. `skills/attunement/SKILL.md:33–36`). Scripts resolve it at
runtime using `$BASH_SOURCE[0]`.

**Copy install** (all files copied into `~/.bob/`): **verified** — all scripts resolve
ROOT correctly because the physical directory three levels up from any script is the copy
root. Both logical (`cd --`) and physical (`cd -P`) resolution agree when no symlinks are
present.

**Symlink install** (skill directories symlinked into `~/.bob/skills/<name>`):
**unverified** — behaviour depends on whether each script uses logical or physical `cd`:

| Script | Resolution | Expected symlink behaviour |
|--------|-----------|---------------------------|
| `skills/deliver/scripts/deliver-write` | logical (`cd -- "$SCRIPT_DIR/../../.."`) | Resolves to the directory the symlink points into, i.e. the checkout, not `~/.bob/` |
| `skills/return-to-town/scripts/publish-handoff` | physical (`cd -P -- "$SCRIPT_DIR/../../.."`) | Resolves to the physical checkout directory |
| `skills/return-to-town/scripts/refresh-merge` | physical (`cd -P -- "$SCRIPT_DIR/../../.."`) | Resolves to the physical checkout directory |
| `skills/quest/scripts/publish-forge-review` | logical (`cd "$SCRIPT_DIR"`) then `../../..` | Resolves to checkout |
| `skills/bounty/scripts/create-verified-issue.sh` | physical (`pwd -P`) | Resolves to physical checkout |

The issue evidence section (`Evidence:Symlink sensitivity`) measured this on macOS arm64 and
found that logical resolution (`deliver-write`) resolved ROOT to the Bob directory while
physical resolution (`publish-handoff`) resolved it to the checkout. Both approaches break
the assumption that ROOT contains `scripts/check-public-safety.sh` and `references/`,
unless those paths exist in both the checkout and the install target, or a symlink forest
replicates the full expected tree.

**Supported path:** A copy install (no symlinks) is the only configuration where all
scripts agree on ROOT. A symlink install requires additional work to ensure ROOT-relative
lookups resolve consistently across scripts; this work has not been done.

---

## 3. Symlink following and reload behaviour

**Bob IDE (symlinks):** **unverified** — Bob's sandboxing documentation states that "symlinks
pointing outside the project directory may not work correctly" (Bob Shell sandboxing page,
File system limitations). Bob IDE's analogous sandboxing behaviour for skill directories is
not separately documented. Whether a symlinked `~/.bob/skills/<name>` directory is followed
when loading skill content is not confirmed.

**Bob Shell (symlinks):** **unverified** — same caveat as above applies to Bob Shell's file
system access model.

**Reload:** **unverified** — the Bob IDE skills documentation states that "Skills load once
per conversation to avoid duplicate prompts." Whether newly added skill directories appear
without restarting Bob (IDE or Shell) is not documented. Best practice assumption: open a
new conversation or restart Bob after placing new skill directories.

---

## 4. How a skill's directory is named to the model

**verified (from Bob documentation):** The `name` field in `SKILL.md` frontmatter is "the
skill's display name used in the Bob interface." The `use_skill` tool takes a `skill_name`
parameter that Bob matches against this `name` field, not against the directory name.

**Consequence for adept:** Each adept skill already sets its `name` field in its `SKILL.md`
frontmatter (e.g. `name: attunement`, `name: quest`). The directory name under
`~/.bob/skills/` does not need to match the `name` field, but using the same name as the
directory (as adept already does) avoids confusion.

**Harness naming at load time:** **verified** — skills refer to a `<plugin root>` that
"the harness names when it loads the skill" (e.g. `skills/attunement/SKILL.md:35–36`,
`skills/quest/SKILL.md:174–175`). Under Claude Code, the harness injects the plugin cache
path as this root. Under Bob, no equivalent injection exists; scripts that rely on this
convention will not receive a harness-supplied root, so ROOT derivation falls to the
`cd`-based resolution described in §2.

---

## 5. Collision and idempotency rules

**Priority:** **verified (from Bob documentation)** — if both `<project>/.bob/skills/` and
`~/.bob/skills/` contain a skill with the same `name` field, the project-level skill takes
precedence. Since adept's skill names are unique within the repository but not globally
reserved, a user with a pre-existing skill using the same name would have it silently shadowed
(global → project) or shadow adept's copy (project pre-existing → new global install).

**Pre-existing `~/.bob/skills/` content:** **unverified** — no documentation describes what
happens if the target directory exists and contains files adept did not create. A copy-based
install would need to merge directories rather than replace them. Idempotency and
non-destructive behaviour of a copy install have not been tested.

**Pre-existing `~/.bob/references/`:** **unverified** — adept's `references/` tree is
at the repository root, not under `~/.bob/references/`. How to install it (copy to
`~/.bob/references/`, a separate path sibling to `skills/`, or another location) has not
been decided. If `~/.bob/references/` already contains user-authored files, a naive copy
could clobber them.

**Re-running after an update:** **unverified** — update semantics (overwrite, merge, skip)
for an already-installed tree are undefined. Any installer must define an explicit update
strategy.

---

## 6. adept features with no Bob equivalent

The following adept capabilities are Claude Code– and Codex-specific and have no Bob
equivalent at the time of writing:

| Feature | adept location | Bob status |
|---------|---------------|-----------|
| Slash-command syntax (`$quest`, `$forge`, etc.) | Skill descriptions reference these as invocation patterns used by Claude Code / Codex operators | **unverified** — Bob supports slash commands but adept's skills are invoked via `use_skill`, not slash commands; the `$name` shorthand is a Claude Code convention |
| `agents/openai.yaml` per-skill worker manifests | `skills/*/agents/openai.yaml` (22 skills ship these) | **verified** — no Bob equivalent: Bob has no plugin system that reads per-skill worker manifests; these files are Codex CLI–specific |
| Plugin marketplace manifest | `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json` | **verified** — Bob has no plugin marketplace; skills must be placed manually |
| Version field | `.claude-plugin/marketplace.json` (via ADR 0022) | **verified** — not relevant to Bob install |

**`agents/openai.yaml` detail:** Each file provides a Codex CLI interface definition (display
name, short description, default prompt) used when a skill is invoked as an OpenAI Codex
agent. Bob does not read these files. A Bob install does not need to place them, but
including them as part of a full-tree copy is harmless.

---

## 7. Open decisions blocking an installer

Two existing records conflict with writing a Bob installer:

### ADR 0001 — Distribution via a plugin marketplace

`docs/adr/0001-distribution-via-plugin-marketplace.md` (Accepted 2026-08-11) states:
> "There is no install script and there will not be one. The harness owns install, update,
> uninstall, and caching."

This decision was made in the context of Claude Code and Codex. It did not anticipate a
Bob user who must hand-place files. A new ADR would need to supersede or amend this
decision before an install script targeting Bob could be added to this repository.

### Plan note — "Bob is retired" (2026-08-11)

`docs/workflow/plans/2026-08-11-adept-dotfiles-separation.md:18` states:
> "Bob is retired. Task 9 is skipped in full; nothing under `$OLD/agents/bob/` is
> carried into either new repo, and Bob-related issues close as obsolete in Task 11."

Line 979 of the same plan records that Bob "has no plugin system" and a
clone-plus-symlink approach "was never executed."

### Resolution required

An installer cannot be written and reviewed until either:
1. An ADR supersedes the "no install script" clause of ADR 0001 for the Bob target, **and**
2. The project explicitly reverses the "Bob is retired" decision, opening Bob as a
   supported target.

This document records the requirements and constraints; it does not resolve these
decisions. See issue #478 for the proposed approach: file the installer as a separate
follow-up only after these decisions are made.
