# adept — Repository Instructions

Development-workflow skills for Claude Code and Codex, distributed as a Claude Code plugin. This repo is its own marketplace: `.claude-plugin/marketplace.json` lists one plugin whose source is `./`.

There is no install script and there will not be one. The harness owns install, update, uninstall, and caching. A predecessor repo carried a 1,337-line installer whose config-merge layer generated roughly thirty open bug reports; retiring it is why this repo exists.

## Anatomy rules

These four rules govern what may ship here. They are construction rules, not aspirations — "be more careful" is what produced the backlog they replace. A change that breaks one of them is wrong even if it works.

**1. A skill is instructions, not a program.** The default artifact is one `SKILL.md`. Supporting files are the exception and must be argued for in the pull request that adds them.

**2. Executable code clears a bar or it does not ship.** A script is permitted only when it does something a model cannot do reliably inline — a deterministic file operation that would otherwise burn context or be performed inconsistently. `sdd-workspace`, `task-brief`, `review-package`, and `detect-host-architecture` clear this bar. A browser mockup server does not.

**3. No long-lived processes.** No servers, no port binding, no PID files, no lockfiles, no daemon lifecycle, no liveness checks against a previous invocation. Every script runs and exits.

This rule is not theoretical. The `brainstorming` skill shipped a Node HTTP server with shell PID lifecycle management — 1,411 lines — and both open bugs against it were defects in the "is the previous instance still alive" logic. That whole bug class exists only because something had to survive between invocations. It was deleted rather than fixed.

**4. Nothing automated asserts on prose.** No gate greps Markdown for a sentence; no test pins a table row. A predecessor gate of 563 lines plus a 753-line suite did exactly that and produced false reds under bracketed checkout paths, non-UTF-8 bytes, and a developer's personal ripgrep configuration. Prose correctness is a reading problem.

Structural gates are a different thing and are welcome: checking that a `SKILL.md` exists, that its declared name matches its directory, or that an invocation resolves is deterministic and catches real breakage. Checking that a document contains a given sentence is not.

## Layout

- `skills/<name>/SKILL.md` — one directory per skill, auto-discovered by the harness. Frontmatter `name:` must match the directory name.
- `tests/fixtures/<skill>/` — behaviour suites and their fixtures, deliberately **outside** the shipped tree. A plugin has no installer; the whole repo is copied into the plugin cache, so a fixture inside a skill's own directory is reachable by that skill at runtime. That has already caused one incident: a stub issue-tracker profile shipped, was selectable, and returned fabricated issues indistinguishable from real ones.
- `docs/superpowers/specs/`, `docs/superpowers/plans/` — design and implementation records.
- `licenses/` — attribution for skills still derived from upstream work.

## Verifying a change

This repo is mid-migration and does not yet have `just`, prek, or CI; those arrive with `docs/superpowers/plans/2026-08-11-adept-dotfiles-separation.md` Task 3. Until then, run these directly and bare — no pipes that swallow an exit code, no `|| true`:

```sh
for s in tests/fixtures/*/*-test.sh skills/decision-records/assets/check-records-test.sh; do "./$s"; done
claude plugin validate ./
shellcheck <any shell file you touched>
```

`claude plugin validate ./` passes at exit 0. Exactly one warning is expected and accepted — `plugins[0] plugin.json → version: No version specified`. Manifests carry no `version` field on purpose: updates track the git SHA, so every push to `main` is an update and there is no version-bump ritual. Do not add `--strict`; it promotes that warning to an error and the two cannot both hold.

Any other warning is a defect.

## Conventions

- This repository is **public**. Never commit host-specific configuration, absolute user paths, local hostnames or addresses, auth headers, API keys, or session state. Host-private configuration belongs in the private `dotfiles` repo.
- Never commit to `main`. Branch, open a pull request, and merge with `--rebase` or `--merge` — never squash. Per-commit history is load-bearing for `git bisect`.
- Conventional commits, imperative mood, subject ≤ 72 characters, one logical change per commit.
- Shell is bash with tab indentation, `#!/usr/bin/env bash`, and `set -euo pipefail`. **Bash 3.2 is the floor** — macOS ships 3.2.57, so no `mapfile`, no `readarray`, no associative arrays.
- `rg` invocations in gate scripts pass `--no-config`. Ripgrep reads `RIPGREP_CONFIG_PATH` ahead of its own arguments, so a developer's personal `ripgreprc` would otherwise steer a gate's verdict.
- Capture a scan's exit status explicitly rather than trailing `|| true`. `rg` exits 1 for "no matches" and greater than 1 for a real failure; collapsing those makes a scan that could not run read as one that found nothing.

## Instruction files

`CLAUDE.md` is the only repository instruction file. There is deliberately no `AGENTS.md` duplicating it: two documents stating the same rules is the drift problem this project spent real effort removing.

A `.codex-plugin/plugin.json` is planned (migration plan Task 4) so Codex can consume the skills in this repo, but it does not exist yet. If development work ever happens here through Codex, decide then whether to point `AGENTS.md` at this file rather than copy it.
