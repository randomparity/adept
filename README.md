# adept

Development-workflow skills for Claude Code and Codex, distributed as a plugin.
This repository is its own marketplace: `.claude-plugin/marketplace.json` declares
one plugin whose source is `./`, and Codex reads the same file.

There is no install script and there will not be one. The harness owns install,
update, uninstall, and caching — see
[ADR 0001](docs/adr/0001-distribution-via-plugin-marketplace.md) for why.

## Install

Claude Code:

    claude plugin marketplace add randomparity/adept
    claude plugin install adept@randomparity

Codex CLI:

    codex plugin marketplace add git@github.com:randomparity/adept.git
    codex plugin add adept@randomparity

## Update

`claude plugin update adept`, or in the background without being asked. Manifests
carry no `version` field: updates track the git SHA, so every merge to `main` is an
update.

## What ships

26 skills covering design, TDD, adversarial review, shipping, and campaign
orchestration, plus 3 references the skills consult and 2 MCP servers (`context7`,
`exa`). `claude plugin details adept` prints the current inventory and its
projected token cost.

The `exa` server reads `EXA_API_KEY` from the session environment at start. A machine
without the key set gets a failing server it can disable; nothing else depends on it.

## Working on this repository

    just verify     # the guardrail suite: gates, suites, linters, manifests
    just hooks      # once per clone: installs prek and the pre-push hook

To try un-pushed changes without installing anything:

    claude --plugin-dir ./

`/reload-plugins` picks up edits inside a running session.

`CLAUDE.md` carries the rules that govern what may ship here — in particular that a
skill is instructions rather than a program, that no skill runs a long-lived process,
and that nothing automated asserts on prose.

## Licence

MIT — see [LICENSE](LICENSE). Some skills derive from
[obra/superpowers](https://github.com/obra/superpowers); its licence is retained at
[licenses/superpowers.LICENSE](licenses/superpowers.LICENSE).
