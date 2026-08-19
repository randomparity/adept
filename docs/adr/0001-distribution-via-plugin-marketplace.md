# 0001 — Distribution via a plugin marketplace

## Status

Accepted (2026-08-11)

## Context

The predecessor repository, `randomparity/agent-config`, distributed skills and merged
per-host agent configuration through a 1,337-line bash installer with a 1,929-line suite
behind it. Roughly half the installer was the merge layer: `merge_json_settings` combined
`settings.json` with a private overlay using jq's `*` operator, and `emit_merged_toml`
combined `config.toml` with a Codex overlay by splicing text with awk.

Neither tool can represent the merge it was asked to perform. jq's `*` replaces arrays
wholesale rather than combining them, so an overlay adding one entry to `permissions.deny`
silently discarded every entry the base had. awk is not a TOML parser, so the Codex path
carried an erasure detector, a refusal protocol, retention bookkeeping, and byte-level
pre-checks to compensate for splicing a format it could not read. Each defect found there
was answered with another compensating rule, and the rules interacted.

The bug list is the evidence. Of the 37 issues open in `agent-config` when this record was
written, 21 are installer, overlay, or deployment-gate defects, and 5 more are the settings
hook guards installed alongside them. Two of the remaining ones — #181 and #118 — are not
implementation bugs at all: they report that the overlay rule *itself* is too blunt, one
refusing a legitimate array-of-tables extension and the other finding no route to express a
host-private deny entry. When the defects stop being mistakes in the code and start being
consequences of the design, patching has reached its limit.

## Decision

**Skills are distributed as a plugin, and this repository is its own marketplace.**
`.claude-plugin/marketplace.json` declares one plugin whose source is `./`, and Claude Code
installs it with `claude plugin marketplace add randomparity/adept` followed by
`claude plugin install adept@randomparity`. Codex reads the same marketplace manifest and
takes its skills path from `.codex-plugin/plugin.json`. The harness owns install, update,
uninstall, caching, and version resolution.

**Manifests carry no `version` field.** Updates track the git SHA, so every push to `main`
is an update and there is no version-bump ritual. This is a deliberate trade against
`claude plugin validate --strict`, which promotes the resulting warning to an error: the two
cannot both hold, and the version-bump ritual is part of the maintenance burden this split
exists to remove.

**Configuration is not distributed from here at all.** `settings.json`, `CLAUDE.md`,
`statusline.sh`, `config.toml`, and the language and reference documents become whole files
owned by the private `randomparity/dotfiles` repository under chezmoi. No merge of any
config format exists in either repository. Where a host genuinely diverges — when it
actually does, not in anticipation — the divergence is expressed as a chezmoi template,
which is a mechanism built for the job by people who own the file formats.

## Consequences

- `install.sh` (1,337 lines), `install-test.sh` (1,929), the overlay protocol, and the
  deployment-modelling gates `check-deployed-membership.sh` and
  `check-deployed-references.sh` have no successor. They modelled where files land after an
  installer put them there; the plugin cache and `claude plugin validate` answer the same
  question by construction.
- The whole repository is copied into the plugin cache — `tests/`, `scripts/`, `docs/` and
  all — not just `skills/`. This was measured, not assumed, by installing into Codex and
  listing the cache. It is why test fixtures live under `tests/fixtures/` rather than beside
  the skills they exercise: a fixture inside a skill's own directory is reachable by that
  skill at runtime, and one already shipped a stub issue-tracker profile that was selectable
  and returned fabricated issues.
- An update is no longer a thing anyone runs. `claude plugin update adept` exists, and the
  harness also updates in the background, so a change merged here reaches a machine without
  a step on that machine's part. The cost is the same fact stated the other way: a bad merge
  to `main` reaches every machine the same way, so `main` has to stay green.
- Two things the installer did have no home yet and are not silently dropped.
  `install-tools.sh` provisioned a developer machine; it dies with `agent-config`, and if
  tool bootstrap is missed on a future new machine it re-homes as a chezmoi `run_onchange_`
  script. The settings hooks stay inline in `settings.json` under `dotfiles` rather than
  becoming a plugin `hooks/hooks.json`, because the hook bodies are self-contained command
  strings enforcing personal policy and keeping them with settings avoids a
  `${CLAUDE_PLUGIN_ROOT}` path migration. That is reversible if the guardrails should
  eventually travel with the skills.
- The gate that validates the manifests reads the Claude ones only. `claude plugin validate`
  exits 0 with `.mcp.json` and `.codex-plugin/plugin.json` both unparseable, so
  `just plugin-check` parses them itself. Anything else either manifest means is its own
  harness's business, and this repository does not re-implement a schema it does not own.
- The predecessor's decision records are not migrated. They remain readable at the archived
  `randomparity/agent-config`, and the ones that governed the installer describe a component
  that no longer exists.

## Considered & rejected

- **Fix the merge layer properly — a real TOML parser, and jq recursion that combines arrays
  instead of replacing them.** The most direct reading of the bug list, and it would close
  most of the 21 issues. Rejected because it buys a correct implementation of a mechanism
  that should not exist: two agent harnesses already resolve configuration precedence, and a
  third resolver in bash competes with both. The mechanism's cost is not its bugs — it is
  that every future config key needs a merge rule.
- **Keep the installer for configuration and move only skills to a plugin.** Rejected on the
  same ground, one step weaker: the overlay defects are all on the configuration side, so
  this keeps precisely the half that generated them.
- **A single repository holding both skills and configuration, with the plugin manifest
  added.** Rejected because the two halves have opposite audiences. Skills are public and
  benefit from being installable by anyone; configuration is host-private and must never be.
  One repository means one visibility setting, and the safe choice for a mixed repository is
  private — which would take the skills off the marketplace.
- **Symlink a checkout into `~/.claude/` instead of installing anything.** Rejected for the
  reason the predecessor rejected it: a symlink makes uncommitted edits, half-written files,
  and branch switches live inside a running agent.
- **Give the manifests a `version` and bump it per release.** Rejected as the ritual named in
  the Decision. Worth revisiting only if adept gains external consumers who need to pin.
  Reversed by [0022](0022-versioned-manifest-and-bump-gate.md) (2026-08-19), on a ground this
  bullet did not have: the field takes over the update trigger from the SHA, so it is adopted
  with a gate that refuses a change leaving it alone. That record replaces the
  `Manifests carry no version field` paragraph of the Decision above and nothing else here.
- **Do nothing and keep patching.** Rejected on the trend rather than on any single defect:
  the two issues that report the overlay rule as wrong in principle are not answerable by a
  fix, and the time spent on installer corner cases had displaced the work the skills exist
  to support.
