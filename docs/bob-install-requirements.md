# IBM Bob install requirements

This document records what a Bob user must supply to make adept skills work, and what
open decisions block a future installer. The requirements every non-marketplace agent shares
— the minimum file tree, `<plugin root>` resolution, and the adept features specific to
Claude Code and Codex — are in [Agent-neutral install requirements](agent-install-requirements.md),
which also defines the **verified**, **documented**, and **unverified** markers used here.

Related: issue #478, ADR 0001 (`docs/adr/0001-distribution-via-plugin-marketplace.md`).

---

## 1–2. Install root

Bob's `<install root>` is `~/.bob/` for a global install (`~/.bob/skills/`) and
`<project>/.bob/` for a project install (`<project>/.bob/skills/`). Both take the tree in
[§1](agent-install-requirements.md#1-minimum-file-tree) of the agent-neutral document, and
ROOT resolves as its [§2](agent-install-requirements.md#2-plugin-root-resolution-copy-install-vs-symlink-install)
describes. Bob's skill location docs state that project skills take precedence over global
ones on name collision (see §5 below), so a project install can shadow a global one.

---

## 3. Symlink following and reload behaviour

**Symlinks (IDE and Shell):** **unverified** — Bob Shell's sandboxing docs state that
"symlinks pointing outside the project directory may not work correctly" (sandboxing page,
File system limitations). Bob IDE has no separately documented sandboxing rule for skill
directories. Whether a symlinked `~/.bob/skills/<name>` directory is followed when loading
skill content is not confirmed for either surface.

**Reload:** **unverified** — the Bob IDE skills documentation states that "Skills load once
per conversation to avoid duplicate prompts." Whether newly added skill directories appear
without restarting Bob (IDE or Shell) is not documented. Best practice assumption: open a
new conversation or restart Bob after placing new skill directories.

---

## 4. How a skill's directory is named to the model

**documented (Bob documentation):** The `name` field in `SKILL.md` frontmatter is "the
skill's display name used in the Bob interface." The `use_skill` tool takes a `skill_name`
parameter; Bob matches it against this `name` field.

**unverified:** Whether the directory name under `~/.bob/skills/` affects resolution (vs the
`name` field) is inferred, not confirmed by Bob documentation. Each adept skill already sets
a `name` field matching its directory name (e.g. `name: attunement`), so this ambiguity
does not affect adept in practice.

**Harness naming at load time:** **verified** — skills refer to a `<plugin root>` that
"the harness names when it loads the skill" (e.g. `skills/attunement/SKILL.md:35–36`,
`skills/quest/SKILL.md:174–175`). Under Claude Code, the harness injects the plugin cache
path as this root. **unverified** — under Bob, whether an equivalent injection exists is not
documented; if it does not, ROOT derivation falls to the `cd`-based resolution in
[agent-neutral §2](agent-install-requirements.md#2-plugin-root-resolution-copy-install-vs-symlink-install).

---

## 5. Collision and idempotency rules

**Priority:** **documented (Bob documentation)** — if both `<project>/.bob/skills/` and
`~/.bob/skills/` contain a skill with the same `name` field, the project-level skill takes
precedence. Since adept's skill names are unique within the repository but not globally
reserved, a user with a pre-existing skill using the same name would have it silently shadowed
(global → project) or shadow adept's copy (project pre-existing → new global install).

**Pre-existing content and update semantics:** **unverified** — no documentation describes
what happens if `~/.bob/skills/` already exists, if `~/.bob/references/` already contains
user-authored files, or what "re-run after an update" means (overwrite, merge, skip). A
copy-based install would need to address all three. None has been tested.

---

## 6. adept features with no Bob equivalent

The adept capabilities specific to Claude Code and Codex
([agent-neutral §3](agent-install-requirements.md#3-adept-features-specific-to-claude-code-and-codex))
have no Bob equivalent at the time of writing:

| Feature | Bob status |
|---------|-----------|
| `$name` invocation shorthand (e.g. `$quest`) | **unverified** — Bob has slash commands but adept's skills are invoked via `use_skill`; the `$name` shorthand is a Codex agent convention, not a Bob convention |
| `agents/openai.yaml` per-skill worker manifests | **documented** — Bob has no feature for per-skill worker manifests (Bob docs describe no equivalent) |
| Skills plugin marketplace | **documented** — Bob's marketplace covers MCP servers and modes, not skills; adept skills must be placed manually |
| Version field | **verified** — not relevant to Bob install |

**`agents/openai.yaml` detail:** Bob does not read these files. A Bob install does not need to
place them, but including them as part of a full-tree copy is harmless.

---

## 7. Open decisions blocking an installer

Two existing records conflict with writing a Bob installer:

### ADR 0001 — Distribution via a plugin marketplace

`docs/adr/0001-distribution-via-plugin-marketplace.md` (Accepted 2026-08-11) records
that the harness owns "install, update, uninstall, caching, and version resolution" and
that `install.sh` (1,337 lines) has no successor. `.claude/CLAUDE.md:7` restates this as
"There is no install script and there will not be one."

This decision was made in the context of Claude Code and Codex. It did not anticipate a
Bob user who must hand-place files. A new ADR would need to supersede or amend this
decision before an install script targeting Bob could be added to this repository.

### Plan note — "Bob is retired" (2026-08-11)

`docs/workflow/plans/2026-08-11-adept-dotfiles-separation.md:18` states:
> "Bob is retired. Task 9 is skipped in full; nothing under `$OLD/agents/bob/` is
> carried into either new repo, and Bob-related issues close as obsolete in Task 11."

Line 967 of the same plan carries the section heading "SKIPPED (Bob retired 2026-08-11)."
Line 969 records that "Bob is retired, `~/.bob` does not exist on this machine, and no Bob
deployment manifest is present." Line 979 records that Bob "has no plugin system" and
describes a clone-plus-symlink approach that was planned but never executed.

### Resolution required

An installer cannot be written and reviewed until either:
1. An ADR supersedes the "no install script" clause of ADR 0001 for the Bob target, **and**
2. The project explicitly reverses the "Bob is retired" decision, opening Bob as a
   supported target.

This document records the requirements and constraints; it does not resolve these
decisions. See issue #478 for the proposed approach: file the installer as a separate
follow-up only after these decisions are made.
