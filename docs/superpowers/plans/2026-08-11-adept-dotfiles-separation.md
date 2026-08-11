# Adept / Dotfiles Separation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the agent-config repo and its 1,337-line installer with two new repos — `randomparity/adept` (skills as a Claude Code plugin marketplace + Codex plugin) and `randomparity/dotfiles` (chezmoi-owned whole-file agent configuration) — then archive agent-config.

**Architecture:** Skills, MCP config, and their quality gates move to `adept`, a repo that is its own plugin marketplace (`source: "./"`); Claude Code and Codex CLIs handle install/update/uninstall natively, replacing the installer's copy/manifest/prune machinery. All merged-config targets (`~/.claude/settings.json`, `CLAUDE.md`, `statusline.sh`, `languages/`, `references/`, `~/.codex/config.toml`, `AGENTS.md`) become whole files owned by chezmoi in `dotfiles` — no overlay merge exists anywhere; per-host divergence, when it first actually appears, is expressed with chezmoi templates. The old repo is archived after its open issues are closed-obsolete or transferred.

**Tech Stack:** Claude Code plugin system (`claude plugin` CLI ≥ 2.1.227), Codex CLI plugins (≥ 0.147.0), chezmoi, bash gate scripts carried from agent-config, just, prek, gh.

## Global Constraints

- Source repo (read-only during this plan): `/Volumes/Source Code Volume/src/agent-config`. Every shell block assumes `export OLD="/Volumes/Source Code Volume/src/agent-config"` has been run in that shell. Do not modify `$OLD` until Phase 3.
- Claude Code hooks stay **inline in `settings.json`** (owned by dotfiles), not as a plugin `hooks/hooks.json` in adept. The hook bodies are self-contained command strings enforcing personal policy (rm/git-clean guards), and keeping them with settings avoids any `${CLAUDE_PLUGIN_ROOT}` path migration. Reversible later if the guardrails should travel with the skills.
- New working clones: `/Volumes/Source Code Volume/src/adept` and `/Volumes/Source Code Volume/src/dotfiles`.
- `adept` is **public** (matching agent-config today, and keeping the superpowers attribution and `check-public-safety.sh` meaningful). `dotfiles` is **private**. All remotes are **SSH** (`git@github.com:...`).
- The pre-existing public `randomparity/dotfiles` (shell/vim/tmux/powerline config, last pushed 2022-09-07, default branch `master`) is **archived, not deleted**, before the new private `dotfiles` is created — Task 6 Step 0.
- **Bob is retired.** Task 9 is skipped in full; nothing under `$OLD/agents/bob/` is carried into either new repo, and Bob-related issues close as obsolete in Task 11.
- Plugin/marketplace manifests carry **no `version` field** — updates track git SHA; every push to main is an update. Consequently the validation gate is plain `claude plugin validate ./` (exit 0), **not** `--strict`: `--strict` promotes warnings to errors and warns on exactly the omitted `version`, so it and this constraint cannot both hold. Version-bump ritual is the maintenance burden this whole split exists to remove; the constraint wins. Revisit only if adept ever gains external consumers who need pinning.
- The only direct-to-main commit allowed in each new repo is its initial bootstrap commit; everything after goes through a branch and PR, merged with `--merge` or `--rebase` (never squash).
- The user's settings hook hard-blocks `git push` to `main`/`master`. Its documented bypass (`GT_REFINERY=1`) is read from the **hook process's** environment, so a command-line prefix does not satisfy it. **Bootstrap a new repo's `main` without any push to main**, as proven in Task 1:

```bash
git push origin HEAD:refs/heads/bootstrap
gh api repos/randomparity/<repo>/git/refs --method POST \
  -f ref=refs/heads/main -f sha="$(git rev-parse HEAD)"
gh api repos/randomparity/<repo> --method PATCH -f default_branch=main
gh api repos/randomparity/<repo>/git/refs/heads/bootstrap --method DELETE
git fetch origin --prune && git branch -u origin/main main
```

  Every other push in this plan targets a feature branch and is unaffected. Never set `GT_REFINERY`, never edit the hook or the user's settings.
- Every commit: conventional-commits subject ≤ 72 chars, imperative mood, and end the message with the trailer `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.
- Run gates bare — no pipes, no `|| true`. A gate's exit code is the verdict.
- Never `rm -rf`; recoverable deletes use `trash` (macOS) / `gio trash` (Linux).
- When a step needs a tool or action version (GitHub Actions, npm package), look up the current stable version at execution time; never assume one from memory.
- Preconditions (verify before Task 1): `gh auth status` succeeds; `ssh -T git@github.com` authenticates; `claude --version` ≥ 2.1.227; `codex --version` ≥ 0.147.0.

---

## Phase 1 — `adept`: the skills plugin repo

### Task 1: Scaffold adept with plugin + marketplace manifests

**Files:**
- Create: `adept/.claude-plugin/plugin.json`
- Create: `adept/.claude-plugin/marketplace.json`
- Create: `adept/.gitignore`, `adept/README.md`, `adept/LICENSE`, `adept/licenses/superpowers.LICENSE`

**Interfaces:**
- Produces: GitHub repo `randomparity/adept` (public, SSH remote), plugin name `adept`, marketplace name `randomparity`. Install strings used by Tasks 5 and 10: `claude plugin marketplace add randomparity/adept`, `claude plugin install adept@randomparity`.

- [ ] **Step 1: Create the repo and clone it**

```bash
gh repo create randomparity/adept --public --description "Development-workflow skills for Claude Code and Codex, distributed as a plugin marketplace"
git clone git@github.com:randomparity/adept.git "/Volumes/Source Code Volume/src/adept"
cd "/Volumes/Source Code Volume/src/adept"
```

- [ ] **Step 2: Write the failing check** — validate an empty plugin dir

Run: `claude plugin validate ./`
Expected: FAIL, exit 1, `No manifest found in directory`. This is the red state the manifests fix.

- [ ] **Step 3: Write the manifests**

`.claude-plugin/plugin.json`:

```json
{
  "name": "adept",
  "description": "Development-workflow skills: design, TDD, adversarial review, shipping, and campaign orchestration for Claude Code and Codex.",
  "author": { "name": "David Christensen" }
}
```

`.claude-plugin/marketplace.json`:

```json
{
  "name": "randomparity",
  "owner": { "name": "David Christensen" },
  "description": "Personal marketplace: development-workflow skills for Claude Code and Codex.",
  "plugins": [
    {
      "name": "adept",
      "source": "./",
      "description": "Development-workflow skills: design, TDD, adversarial review, shipping, and campaign orchestration."
    }
  ]
}
```

`.gitignore`:

```
.DS_Store
local/
CLAUDE.local.md
```

- [ ] **Step 4: Copy licenses and stub the README**

```bash
cp "$OLD/LICENSE" LICENSE
mkdir -p licenses
cp "$OLD/docs/licenses/superpowers.LICENSE" licenses/superpowers.LICENSE
```

`README.md` (full content; extend in Task 5):

```markdown
# adept

Development-workflow skills for Claude Code and Codex, distributed as a
Claude Code plugin marketplace. This repo is its own marketplace.

## Install

    claude plugin marketplace add randomparity/adept
    claude plugin install adept@randomparity

Codex CLI:

    codex plugin marketplace add git@github.com:randomparity/adept.git

## Update

Handled by the harness: `claude plugin update adept` (or automatically in
the background). There is no install script.
```

- [ ] **Step 5: Verify the check passes**

Run: `claude plugin validate ./`
Expected: exit 0. One residual warning is expected and accepted — `plugins[0] plugin.json → version: No version specified` — per the Global Constraints' SHA-update decision. If any *other* warning appears, fix it rather than accepting it.

- [ ] **Step 6: Bootstrap commit, with `main` seeded server-side**

```bash
git add -A
git commit -m "feat: scaffold adept plugin marketplace"
git push origin HEAD:refs/heads/bootstrap
gh api repos/randomparity/adept/git/refs --method POST \
  -f ref=refs/heads/main -f sha="$(git rev-parse HEAD)"
gh api repos/randomparity/adept --method PATCH -f default_branch=main
gh api repos/randomparity/adept/git/refs/heads/bootstrap --method DELETE
git fetch origin --prune && git branch -u origin/main main
```

The user's settings hook blocks pushes to `main`; see Global Constraints. Expected: `git ls-remote --heads origin` shows only `refs/heads/main`, and `git status -sb` shows `## main...origin/main`.

---

### Task 2: Import the skills tree and relocate test fixtures

**Files:**
- Create: `adept/skills/<36 skill dirs>` (copied from `$OLD/content/skills/`)
- Create: `adept/tests/fixtures/{brainstorming,preflight,issue,subagent-driven-development,github-tracking}/`
- Modify: every in-skill `*-test.sh` that references a `testdata` path

**Interfaces:**
- Consumes: manifests from Task 1.
- Produces: `skills/` at plugin root (auto-discovered by both Claude Code and Codex conventions); `tests/fixtures/<skill>/` as the fixture root consumed by in-skill suites and by Task 3's `just test`.

- [ ] **Step 1: Branch**

```bash
cd "/Volumes/Source Code Volume/src/adept" && git checkout -b feat/import-skills
```

- [ ] **Step 2: Copy the skills tree**

```bash
cp -R "$OLD/content/skills" skills
```

- [ ] **Step 3: Relocate the five fixture dirs out of the shipped tree**

Rationale: the plugin cache copies the whole repo, and a fixture living inside a skill's own directory is discoverable by that skill's globbing (the ADR 0024 incident — a stub tracker profile shipped and returned fabricated issues). Fixtures under `tests/` are inert.

```bash
mkdir -p tests/fixtures
git_mv() { mkdir -p "$(dirname "$2")"; mv "$1" "$2"; }
git_mv skills/brainstorming/scripts/testdata              tests/fixtures/brainstorming
git_mv skills/preflight/scripts/testdata                  tests/fixtures/preflight
git_mv skills/issue/scripts/testdata                      tests/fixtures/issue
git_mv skills/subagent-driven-development/scripts/testdata tests/fixtures/subagent-driven-development
git_mv skills/github-tracking/assets/testdata             tests/fixtures/github-tracking
```

- [ ] **Step 4: Find every reference to the old fixture locations**

Run: `rg -ln 'testdata' skills/`
Expected: a list of in-skill `*-test.sh` suites (and possibly helper scripts) in exactly the five skills above.

- [ ] **Step 5: Repoint each reference**

Rule: a suite at `skills/<skill>/scripts/foo-test.sh` reaches its fixtures at `../../../tests/fixtures/<skill>`. For each file from Step 4, replace the old relative segment (`testdata`, `scripts/testdata`, or `assets/testdata`) with a path that resolves from the referencing file to `tests/fixtures/<skill>`. Prefer computing it once per suite, e.g. at the top of each suite:

```bash
FIXTURES="$(cd "$(dirname "$0")/../../../tests/fixtures/<skill>" && pwd)"
```

then use `$FIXTURES/...` at each former `testdata/...` site.

- [ ] **Step 6: Verify no stale references remain**

Run: `rg -n 'testdata' skills/`
Expected: no output.

- [ ] **Step 7: Run the relocated suites directly**

```bash
while IFS= read -r -d '' suite; do "./$suite"; done < <(git ls-files -z -- 'skills/**-test.sh')
```

Expected: every suite passes. (Task 3 wires these into `just test`; this direct run proves the path fix before the harness exists.)

- [ ] **Step 8: Validate and commit**

Run: `claude plugin validate ./`
Expected: PASS, and the component inventory now reports 36 skills.

```bash
git add -A
git commit -m "feat: import 36 skills with fixtures outside the shipped tree"
```

- [ ] **Step 9: PR and merge**

```bash
git push -u origin feat/import-skills
gh pr create --fill
gh pr merge --rebase
```

(No CI exists yet — Task 3 adds it. Merging on the strength of Step 7/8's local runs is the bootstrap exception.)

---

### Task 3: Carry the quality gates, Justfile, prek, and CI

**Files:**
- Create: `adept/scripts/` — copied subset: `check-public-safety.sh` (+test), `check-ripgrep-config.sh` (+test), `verify-push.sh` (+test), `git-fixture-isolation-test.sh`, `list-shell-sources.sh`, `pre-push-hook`, `reserved-skill-names.txt`
- Create: `adept/scripts/check-skill-shape.sh` — new, written in this task (Step 2b). Replaces `check-skill-layout.sh`.
- Create: `adept/.github/scripts/` — records machinery copied whole: `check-records.sh`, `check-records-test.sh`, `migrate-records.sh`, `profiles/`, `records.yml`
- Create: `adept/.github/workflows/verify.yml`, `adept/Justfile`, `adept/.pre-commit-config.yaml`
- **Not carried** (they model the retired installer): `check-deployed-membership.sh`, `check-deployed-references.sh`, `check-carrier-drift.sh`, `check-shared-standards.sh`, `claude-settings-hooks-test.sh`, `claude-settings-posix-guard-test.sh` (the last two move to dotfiles in Task 8), and their test suites.
- **Not carried** (rewrite spec §4 rule 4 — nothing automated asserts on prose): `check-skill-layout.sh` (563 lines) and `check-skill-layout-test.sh` (753 lines). Its encoding and content-scanning rules are the gate class that produced false reds under bracketed checkout paths, non-UTF-8 bytes and personal ripgrep configuration. The structural subset worth keeping is re-implemented as `check-skill-shape.sh` in Step 2b — roughly 100 lines against 1,316.

**Interfaces:**
- Consumes: `skills/`, `tests/fixtures/` from Task 2.
- Produces: `just verify` (the guardrail suite CI and prek both invoke), recipes `plugin-check`, `shape-check`, `test`, `records`, `commit-check`. Task 5's ADR must satisfy `just records`.

- [ ] **Step 1: Branch and copy**

```bash
git checkout main && git pull && git checkout -b feat/gates
mkdir -p scripts .github/scripts
for f in check-public-safety.sh \
         check-public-safety-test.sh check-ripgrep-config.sh check-ripgrep-config-test.sh \
         verify-push.sh verify-push-test.sh git-fixture-isolation-test.sh \
         list-shell-sources.sh pre-push-hook reserved-skill-names.txt; do
  cp "$OLD/scripts/$f" scripts/
done
cp -R "$OLD/.github/scripts/." .github/scripts/
cp "$OLD/.pre-commit-config.yaml" .
```

- [ ] **Step 2: Repoint gate paths from `content/skills` to `skills`**

Run: `rg -ln 'content/skills|content/languages|content/references|content/instructions|agents/' scripts/ .github/scripts/`
For each hit: `content/skills` → `skills`; delete any check block that exists only to inspect `content/languages`, `content/references`, `content/instructions`, `agents/`, `install.sh`, or `install-test.sh` (those trees do not exist in adept). Re-run the rg; expected: no output.

- [ ] **Step 2b: Write the structural shape gate**

`scripts/check-skill-shape.sh` (entire file; tabs, not spaces):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Structural rules only. Rule 4 of the rewrite spec forbids any gate that
# asserts on prose, so nothing here reads a document's wording -- only whether
# the pieces that must exist do, and whether names resolve.
#
# rg gets --no-config throughout: it reads RIPGREP_CONFIG_PATH ahead of its own
# arguments, so a developer's personal ripgreprc would otherwise steer a gate's
# verdict.
#
# Bash 3.2 is the floor. macOS ships 3.2.57 and no script in this repo uses a
# bash 4 feature, so there is no mapfile and no associative array here.
# Membership is a sorted file plus a fixed whole-line grep.
#
# Every scan captures rg's status explicitly rather than trailing `|| true`.
# rg exits 1 for "no matches" and >1 for a real failure; collapsing those makes
# a scan that could not run read as a scan that found nothing.

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
status=0

report() {
	printf 'check-skill-shape: %s\n' "$1" >&2
	status=1
}

workspace="$(mktemp -d "${TMPDIR:-/tmp}/check-skill-shape.XXXXXX")"
trap 'rm -R "$workspace"' EXIT

names="$workspace/names"
find "$root/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort >"$names"

count="$(wc -l <"$names" | tr -d ' ')"
if [ "$count" -eq 0 ]; then
	printf 'check-skill-shape: no skills found under %s/skills\n' "$root" >&2
	exit 1
fi

# Rule 1: every skill directory has a SKILL.md.
# Rule 2: its `name:` frontmatter matches the directory name.
while IFS= read -r name; do
	skill_file="$root/skills/$name/SKILL.md"
	if [ ! -f "$skill_file" ]; then
		report "$name: no SKILL.md"
		continue
	fi
	declared=''
	name_status=0
	# -r is --replace, not recursive: capture the value and emit only it. \K is
	# avoided deliberately -- it is PCRE2-only and needs rg -P, which not every
	# rg build carries.
	declared="$(rg --no-config -m1 -N -o -r '$1' '^name: *(\S+)' "$skill_file")" || name_status=$?
	if [ "$name_status" -gt 1 ]; then
		printf 'check-skill-shape: reading %s failed (rg exit %s)\n' "$skill_file" "$name_status" >&2
		exit 1
	fi
	if [ -z "$declared" ]; then
		report "$name: SKILL.md has no name: frontmatter"
	elif [ "$declared" != "$name" ]; then
		report "$name: SKILL.md declares name: $declared"
	fi
done <"$names"

# Rule 3: no skill name collides with a harness-reserved name.
reserved_status=0
rg --no-config -v '^#|^$' "$root/scripts/reserved-skill-names.txt" |
	sort -u >"$workspace/reserved" || reserved_status=$?
if [ "$reserved_status" -gt 1 ]; then
	printf 'check-skill-shape: reading the reserved-name list failed (exit %s)\n' "$reserved_status" >&2
	exit 1
fi
while IFS= read -r reserved; do
	if grep -qxF -- "$reserved" "$names"; then
		report "$reserved: collides with a reserved harness name"
	fi
done <"$workspace/reserved"

# Rule 4: every `$invocation` resolves to a skill that exists. This is what
# makes the rename sweep safe -- a stale $name is otherwise silent until
# someone runs it.
#
# Only the backticked form is scanned. It is the convention in 244 of 293
# references, and the bare form collides with ordinary shell variables in
# fenced examples ($root, $path, $err, $c), which would make this gate cry wolf
# on every skill that documents a command. Measured against the current tree,
# the backticked rule has zero false positives.
refs_status=0
rg --no-config -o -N '`\$[a-z][a-z0-9-]*`' "$root"/skills/*/SKILL.md \
	>"$workspace/raw" || refs_status=$?
if [ "$refs_status" -gt 1 ]; then
	printf 'check-skill-shape: scanning invocations failed (rg exit %s)\n' "$refs_status" >&2
	exit 1
fi
# shellcheck disable=SC2016 # the $ is a literal to strip, not an expansion
sed 's/.*`\$//;s/`//' "$workspace/raw" | sort -u >"$workspace/refs"
while IFS= read -r ref; do
	if ! grep -qxF -- "$ref" "$names"; then
		report "\$$ref is invoked but no such skill exists"
	fi
done <"$workspace/refs"

if [ "$status" -eq 0 ]; then
	printf 'check-skill-shape: %s skills, all rules pass\n' "$count"
fi
exit "$status"
```

Run it:

```bash
chmod +x scripts/check-skill-shape.sh
./scripts/check-skill-shape.sh
```

Expected: `check-skill-shape: 36 skills, all rules pass`, exit 0. Also run `shellcheck scripts/check-skill-shape.sh` — expected clean, exit 0.

This script was written and verified against the real tree on 2026-08-11 under the system bash (3.2.57) before being recorded here. Reproduce that proof — a gate that cannot fail is not a gate. Revert after each mutation:

| Mutation | Expected output |
|---|---|
| `mv skills/retro/SKILL.md skills/retro/SKILL.md.bak` | `check-skill-shape: retro: no SKILL.md`, exit 1 |
| change `name: retro` to `name: bards-tale` | `check-skill-shape: retro: SKILL.md declares name: bards-tale`, exit 1 |
| append ``See `$nosuchskill` for details.`` to any `SKILL.md` | `check-skill-shape: $nosuchskill is invoked but no such skill exists`, exit 1 |

Rule 3 needs no mutation: it is proved by the reserved-names file holding 160 entries with no current skill among them.

The second mutation is worth noticing — it is exactly the rename sweep's failure mode, caught by the gate that makes the sweep safe.

- [ ] **Step 3: Write the Justfile**

```just
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
  just --list

hooks:
  #!/usr/bin/env bash
  set -euo pipefail
  marker='# adept: managed pre-push hook'
  hook_dir="$(git rev-parse --git-path hooks)"
  destination="$hook_dir/pre-push"
  source='scripts/pre-push-hook'
  prek install
  mkdir -p "$hook_dir"
  if [[ -L $destination || ( -e $destination && ! -f $destination ) ]]; then
    echo "hooks: refusing unsafe pre-push destination: $destination" >&2
    exit 1
  fi
  if [[ -f $destination ]] && ! rg -qxF "$marker" "$destination"; then
    echo "hooks: refusing foreign pre-push hook: $destination" >&2
    exit 1
  fi
  temporary="$(mktemp "$hook_dir/.pre-push.XXXXXX")"
  trap 'rm -f "$temporary"' EXIT
  cp "$source" "$temporary"
  chmod +x "$temporary"
  mv -f "$temporary" "$destination"
  trap - EXIT

records:
  #!/usr/bin/env bash
  set -euo pipefail
  ./.github/scripts/check-records-test.sh
  RECORD_PROFILES="adr debt" ./.github/scripts/check-records.sh
  shared_assets="check-records.sh check-records-test.sh migrate-records.sh"
  shared_assets="$shared_assets profiles/adr.sh profiles/debt.sh records.yml"
  for asset in $shared_assets; do
    root_asset=".github/scripts/$asset"
    skill_asset="skills/decision-records/assets/$asset"
    if ! cmp -s "$root_asset" "$skill_asset"; then
      echo "record gate mismatch: $skill_asset differs from $root_asset" >&2
      exit 1
    fi
  done

lint:
  #!/usr/bin/env bash
  set -euo pipefail
  files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(./scripts/list-shell-sources.sh --all -z)
  shellcheck "${files[@]}"

format-check:
  #!/usr/bin/env bash
  set -euo pipefail
  tabs=()
  while IFS= read -r -d '' file; do
    tabs+=("$file")
  done < <(./scripts/list-shell-sources.sh --tabs -z)
  two_space=()
  while IFS= read -r -d '' file; do
    two_space+=("$file")
  done < <(./scripts/list-shell-sources.sh --two-space -z)
  shfmt -d "${tabs[@]}"
  shfmt -i 2 -d "${two_space[@]}"

test:
  #!/usr/bin/env bash
  set -euo pipefail
  count=0
  while IFS= read -r -d '' suite; do
    case $suite in
    .github/scripts/check-records-test.sh | \
      skills/decision-records/assets/check-records-test.sh)
      continue
      ;;
    esac
    printf '== %s\n' "$suite"
    "./$suite"
    count=$((count + 1))
  done < <(git ls-files -z -- '*-test.sh')
  if ((count == 0)); then
    printf 'test: no suites discovered\n' >&2
    exit 1
  fi
  printf 'test: %s suites passed\n' "$count"

shape-check:
  ./scripts/check-skill-shape.sh

public-safety:
  ./scripts/check-public-safety.sh

ripgrep-config-check:
  ./scripts/check-ripgrep-config.sh

plugin-check:
  claude plugin validate ./

actions-check:
  actionlint
  zizmor --offline .github/workflows/

commit-check: lint format-check public-safety

push-check:
  ./scripts/verify-push.sh

verify: records commit-check shape-check ripgrep-config-check plugin-check test actions-check
  prek run --all-files --stage pre-commit --dry-run

ci:
  #!/usr/bin/env bash
  set -euo pipefail
  just verify
```

- [ ] **Step 4: Write the CI workflow**

`.github/workflows/verify.yml` — start from `$OLD/.github/workflows/verify.yml` (copy it, keep its tool-install steps for just/shellcheck/shfmt/actionlint/zizmor/prek/rg), then add a Claude CLI step before the verify step so `plugin-check` runs in CI (look up the current `actions/setup-node` major at execution time):

```yaml
      - uses: actions/setup-node@<current-major>
        with:
          node-version: 22
      - name: Install Claude Code CLI
        run: npm install -g @anthropic-ai/claude-code
```

Remove any workflow steps that invoke retired recipes (`membership-check`, `references-check`, `carrier-check`, `shared-standards-check`, `tools-check`, install-test invocations). The workflow's job must end by running `just ci`.

- [ ] **Step 5: `list-shell-sources.sh` classification sanity**

The copied classifier names two-space subsets by path (vendored brainstorming tree, records gate, decision-records assets). Run: `./scripts/list-shell-sources.sh --all -z | tr '\0' '\n' | head`
Expected: paths under `skills/`, `scripts/`, `.github/scripts/` only. If it names `content/` paths, repoint them as in Step 2.

- [ ] **Step 6: Run the full gate suite red-to-green**

```bash
just hooks
just verify
```

Expected: all recipes pass. Known likely failures to fix here, not suppress: `check-skill-shape.sh` rejecting a skill whose frontmatter name and directory disagree, `actionlint`/`zizmor` findings on the trimmed workflow, shfmt classification drift (Step 5).

- [ ] **Step 7: Commit, PR, watch CI, merge**

```bash
git add -A
git commit -m "feat: carry quality gates, Justfile, prek, and CI"
git push -u origin feat/gates
gh pr create --fill
gh pr checks --json name,state
gh pr merge --rebase
```

Expected before merge: all checks green and `gh pr view --json mergeable,mergeStateStatus` reports `MERGEABLE`/`CLEAN`.

---

### Task 4: Codex manifest and MCP servers

**Files:**
- Create: `adept/.codex-plugin/plugin.json`
- Create: `adept/.mcp.json`

**Interfaces:**
- Consumes: `skills/` from Task 2.
- Produces: Codex install path (`codex plugin marketplace add git@github.com:randomparity/adept.git`) used in Task 10; MCP servers `context7` and `exa` shipped with the plugin (replaces `install.sh`'s `maybe_configure_claude_mcp`, which ran `claude mcp add -s user context7 -- npx -y @upstash/context7-mcp` and `claude mcp add -s user exa -e EXA_API_KEY=... -- npx -y exa-mcp-server`).

- [ ] **Step 1: Branch**

```bash
git checkout main && git pull && git checkout -b feat/codex-and-mcp
```

- [ ] **Step 2: Write the Codex manifest**

`.codex-plugin/plugin.json`:

```json
{
  "name": "adept",
  "description": "Development-workflow skills: design, TDD, adversarial review, shipping, and campaign orchestration.",
  "skills": "./skills/"
}
```

- [ ] **Step 3: Write the MCP config**

`.mcp.json`:

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    },
    "exa": {
      "command": "npx",
      "args": ["-y", "exa-mcp-server"],
      "env": { "EXA_API_KEY": "${EXA_API_KEY}" }
    }
  }
}
```

Note: `${EXA_API_KEY}` expands from the session environment at server start; a machine without the key set gets a failing exa server it can disable — same opt-in economics as the old `AGENT_CONFIG_REGISTER_CLAUDE_MCP` flag, minus the installer.

- [ ] **Step 4: Validate both harnesses locally**

Run: `claude plugin validate ./`
Expected: PASS; inventory reports 36 skills and 2 MCP servers.

Run: `codex plugin marketplace add ./ && codex plugin marketplace list`
Expected: `adept` listed from the local path. Then remove the local test entry: `codex plugin marketplace remove adept` (exact removal argument per `codex plugin marketplace --help`; the SSH URL is re-added for real in Task 10).

- [ ] **Step 5: Commit, PR, merge**

```bash
git add -A
git commit -m "feat: add Codex manifest and plugin MCP servers"
git push -u origin feat/codex-and-mcp
gh pr create --fill
gh pr checks --json name,state
gh pr merge --rebase
```

---

### Task 5: ADR 0001, README completion, and marketplace registration

**Files:**
- Create: `adept/docs/adr/0001-distribution-via-plugin-marketplace.md`
- Modify: `adept/README.md`

**Interfaces:**
- Consumes: records gate from Task 3 (`just records` validates the ADR's format).
- Produces: the marketplace registered on this machine (`randomparity` in `claude plugin marketplace list`); the ADR that Task 11's issue-close comments cite by URL.

- [ ] **Step 1: Branch, and scaffold the ADR from the old repo's format**

```bash
git checkout main && git pull && git checkout -b feat/adr-0001
mkdir -p docs/adr docs/debt
cp "$OLD/docs/adr/0008"*.md docs/adr/0001-distribution-via-plugin-marketplace.md
```

Keep the copied file's header/frontmatter *structure* exactly (the records gate checks it); replace number, title, date (2026-08-11), status (accepted), and body.

- [ ] **Step 2: Write the ADR body**

Core content (adapt into the record format):

> **Context.** agent-config distributed skills and merged per-host configuration through a 1,337-line bash installer. Roughly 700 lines merged JSON with `jq '.[0] * .[1]'` (replaces arrays) and TOML with awk text-splicing (not a parser), compensated by erasure detectors, a refusal protocol (old ADR 0049), retention bookkeeping, and byte-level pre-checks. ~30 of 38 open issues were installer, overlay, or deployment-gate defects.
>
> **Decision.** Skills are distributed as a Claude Code plugin from this repo, which is its own marketplace (`.claude-plugin/marketplace.json`, source `./`), and as a Codex plugin via `.codex-plugin/plugin.json` over the same `skills/` tree. The harness owns install, update, uninstall, caching, and version resolution (git SHA; no `version` field). Configuration files are not distributed here at all: they are whole files owned by the private `randomparity/dotfiles` chezmoi repo. No merge of any config format exists in either repo; per-host divergence is expressed with chezmoi templates when a host actually diverges.
>
> **Consequences.** install.sh, install-test.sh, the overlay protocol, and the deployment-modeling gates (`check-deployed-membership`, `check-deployed-references`) have no successor — the plugin cache plus `claude plugin validate` replace them. Test fixtures live under `tests/fixtures/`, outside the shipped `skills/` tree, superseding old ADRs 0024/0025's staging-time pruning. Old repo ADRs remain readable at the archived `randomparity/agent-config`.

- [ ] **Step 3: Complete the README**

Extend Task 1's README with: component inventory (36 skills, 2 MCP servers), the dev loop (`claude --plugin-dir ./` to test un-pushed changes; `/reload-plugins` after edits), the gate entry point (`just verify`), and a pointer to `docs/adr/0001`.

- [ ] **Step 4: Run the records gate**

Run: `just records`
Expected: PASS. If it fails on format, fix the ADR to the gate's report — do not modify the gate.

- [ ] **Step 5: Commit, PR, merge**

```bash
git add -A
git commit -m "docs: record plugin-marketplace distribution in ADR 0001"
git push -u origin feat/adr-0001
gh pr create --fill
gh pr checks --json name,state
gh pr merge --rebase
```

- [ ] **Step 6: Register the marketplace on this machine (install waits for Task 10)**

```bash
claude plugin marketplace add randomparity/adept
claude plugin marketplace list
```

Expected: marketplace `randomparity` listed, sourced from the SSH remote. Do **not** run `claude plugin install` yet — the installer-deployed copies in `~/.claude/skills` would duplicate every skill until Task 10 removes them.

---

## Phase 2 — `dotfiles`: chezmoi-owned configuration

### Task 6: Scaffold dotfiles and capture the Claude configuration

**Files:**
- Create: GitHub repo `randomparity/dotfiles`; chezmoi source dir at `/Volumes/Source Code Volume/src/dotfiles`
- Create (chezmoi source names): `dot_claude/settings.json`, `dot_claude/CLAUDE.md`, `dot_claude/executable_statusline.sh`, `dot_claude/languages/*.md` (5 files), `dot_claude/references/orchestration.md`, `README.md`, `.gitignore`

**Interfaces:**
- Consumes: nothing from Phase 1.
- Produces: `chezmoi apply`/`chezmoi verify` as the sole config-sync mechanism; source-state paths consumed by Tasks 7–9; bootstrap command for other machines: `chezmoi init --apply git@github.com:randomparity/dotfiles.git`.

- [ ] **Step 0: Archive the pre-existing dotfiles repo (do not delete)**

```bash
gh repo view randomparity/dotfiles --json pushedAt,visibility
gh repo archive randomparity/dotfiles --yes
gh repo view randomparity/dotfiles --json isArchived
```

Expected: the 2022 shell-config repo reports `pushedAt` in 2022 and `isArchived: true`. **If `pushedAt` is recent, stop and escalate** — the repo is in use and the name must change instead. Archiving keeps its history browsable; the name is then reusable for the new private repo.

- [ ] **Step 1: Install chezmoi and create the repo**

```bash
brew install chezmoi
gh repo create randomparity/dotfiles --private --description "chezmoi-managed agent configuration"
git clone git@github.com:randomparity/dotfiles.git "/Volumes/Source Code Volume/src/dotfiles"
mkdir -p ~/.config/chezmoi
printf 'sourceDir = "/Volumes/Source Code Volume/src/dotfiles"\n' > ~/.config/chezmoi/chezmoi.toml
chezmoi doctor
```

Expected: `chezmoi doctor` reports the source dir and no errors. (Other machines skip the `sourceDir` override and use `chezmoi init` normally.)

- [ ] **Step 2: Verify the deployed files match the old repo's base (no local drift)**

```bash
diff <(jq -S . "$OLD/agents/claude/shared/settings.base.json") <(jq -S . ~/.claude/settings.json)
cmp "$OLD/agents/claude/shared/CLAUDE.md" ~/.claude/CLAUDE.md
cmp "$OLD/agents/claude/shared/statusline.sh" ~/.claude/statusline.sh
```

Expected: all three produce no output (this host has no overlay, so deployed == base). **If any differ, stop and reconcile before capturing** — the deployed file has drifted from the repo and the difference must be understood, not silently canonized.

- [ ] **Step 3: Capture the Claude tree into chezmoi**

```bash
chezmoi add ~/.claude/settings.json ~/.claude/CLAUDE.md ~/.claude/statusline.sh
chezmoi add ~/.claude/languages ~/.claude/references
```

Expected source files: `dot_claude/settings.json`, `dot_claude/CLAUDE.md`, `dot_claude/executable_statusline.sh` (mode captured automatically), `dot_claude/languages/{bash,github-actions,python,rust,typescript}.md`, `dot_claude/references/orchestration.md`.

- [ ] **Step 4: Prove idempotency**

Run: `chezmoi verify ~/.claude`
Expected: exit 0, no output — source and destination agree byte-for-byte.

- [ ] **Step 5: README and bootstrap commit**

`README.md`:

```markdown
# dotfiles

chezmoi-managed agent configuration (Claude Code, Codex). Whole files
only — no overlays, no merging. Per-host divergence, when a host actually
needs it, is a chezmoi template, not a merge.

## New machine

    brew install chezmoi        # or the platform equivalent
    chezmoi init --apply git@github.com:randomparity/dotfiles.git

Skills come from the adept plugin, not this repo:

    claude plugin marketplace add randomparity/adept
    claude plugin install adept@randomparity
```

`.gitignore`:

```
.DS_Store
```

```bash
cd "/Volumes/Source Code Volume/src/dotfiles"
git add -A
git commit -m "feat: capture Claude configuration under chezmoi"
git push origin HEAD:refs/heads/bootstrap
gh api repos/randomparity/dotfiles/git/refs --method POST \
  -f ref=refs/heads/main -f sha="$(git rev-parse HEAD)"
gh api repos/randomparity/dotfiles --method PATCH -f default_branch=main
gh api repos/randomparity/dotfiles/git/refs/heads/bootstrap --method DELETE
git fetch origin --prune && git branch -u origin/main main
```

`main` is seeded server-side because the user's settings hook blocks pushes to it (see Global Constraints). Expected: `git ls-remote --heads origin` shows only `refs/heads/main`, and `git status -sb` shows `## main...origin/main` with no divergence.

---

### Task 7: Capture Codex configuration

**Files:**
- Create: `dot_codex/config.toml`, `dot_codex/AGENTS.md`, `dot_codex/symlink_languages.tmpl`, `dot_codex/symlink_references.tmpl`

**Interfaces:**
- Consumes: `dot_claude/languages`, `dot_claude/references` from Task 6 (symlink targets).
- Produces: `~/.codex/config.toml` and `~/.codex/AGENTS.md` as chezmoi-owned files; `~/.codex/{languages,references}` as symlinks into `~/.claude/` (replacing the installer's duplicate copies).

- [ ] **Step 1: Branch**

```bash
cd "/Volumes/Source Code Volume/src/dotfiles" && git checkout -b feat/codex
```

- [ ] **Step 2: Drift check, then capture**

```bash
cmp "$OLD/agents/codex/shared/config.base.toml" ~/.codex/config.toml
cmp "$OLD/agents/codex/shared/AGENTS.md" ~/.codex/AGENTS.md
```

Expected: no output (no overlay on this host; on a mac, the Codex TOML overlay was permanently refused anyway — old ADR 0057). If they differ, stop and reconcile as in Task 6 Step 2.

```bash
chezmoi add ~/.codex/config.toml ~/.codex/AGENTS.md
```

- [ ] **Step 3: Replace the duplicated common content with symlinks**

`dot_codex/symlink_languages.tmpl` (entire file content):

```
{{ .chezmoi.homeDir }}/.claude/languages
```

`dot_codex/symlink_references.tmpl` (entire file content):

```
{{ .chezmoi.homeDir }}/.claude/references
```

Note: `chezmoi apply` will not replace the existing real directories with symlinks; Task 10 deletes the installer's copies first, then applies. Until Task 10 runs, `chezmoi verify ~/.codex` is expected to FAIL on these two paths — that is the red state Task 10 resolves.

- [ ] **Step 4: Verify what can be verified now**

Run: `chezmoi verify ~/.codex/config.toml ~/.codex/AGENTS.md`
Expected: exit 0.

- [ ] **Step 5: Commit, PR, merge**

```bash
git add -A
git commit -m "feat: capture Codex configuration; symlink shared content"
git push -u origin feat/codex
gh pr create --fill
gh pr merge --rebase
```

(No CI in dotfiles until Task 8; local `chezmoi verify` is the gate this round.)

---

### Task 8: Carry the hook-body suites and minimal gates into dotfiles

**Files:**
- Create: `dotfiles/tests/claude-settings-hooks-test.sh`, `dotfiles/tests/claude-settings-posix-guard-test.sh` (copied from `$OLD/scripts/`)
- Create: `dotfiles/Justfile`, `dotfiles/.pre-commit-config.yaml`, `dotfiles/.github/workflows/verify.yml`

**Interfaces:**
- Consumes: `dot_claude/settings.json` from Task 6 (the file the suites now test).
- Produces: `just verify` in dotfiles: shellcheck + shfmt over tracked shell, the two hook-body suites, and `chezmoi verify`-style source sanity. Open issues #156/#157/#160/#165/#170/#179 transfer here in Task 11 against these suites.

- [ ] **Step 1: Branch and copy the suites**

```bash
git checkout main && git pull && git checkout -b feat/gates
mkdir -p tests
cp "$OLD/scripts/claude-settings-hooks-test.sh" tests/
cp "$OLD/scripts/claude-settings-posix-guard-test.sh" tests/
```

- [ ] **Step 2: Repoint the suites at the chezmoi source file**

Run: `rg -n 'agents/claude/shared/settings.base.json' tests/`
Replace every hit with `dot_claude/settings.json` (path relative to repo root; adjust any `$(dirname "$0")/..` prefix the suites use). Re-run the rg; expected: no output.

- [ ] **Step 3: Run the suites red-check**

```bash
./tests/claude-settings-hooks-test.sh
./tests/claude-settings-posix-guard-test.sh
```

Expected: PASS (the settings content is unchanged — only its home moved). A failure here means Step 2's repointing is wrong, not that the hooks regressed.

- [ ] **Step 4: Write the Justfile**

```just
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
  just --list

lint:
  #!/usr/bin/env bash
  set -euo pipefail
  files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(git ls-files -z -- '*.sh')
  shellcheck "${files[@]}"
  shfmt -i 2 -d "${files[@]}"

test:
  ./tests/claude-settings-hooks-test.sh
  ./tests/claude-settings-posix-guard-test.sh

source-check:
  chezmoi --source . verify

verify: lint test

ci:
  just verify
```

Note: `source-check` is excluded from `verify` because CI has no destination tree to verify against; it is a local-only convenience.

- [ ] **Step 5: prek and CI**

```bash
cp "$OLD/.pre-commit-config.yaml" .
prek install
```

`.github/workflows/verify.yml`: minimal single job — checkout, install just/shellcheck/shfmt/rg/jq (mirror the tool-install steps from adept's workflow), run `just ci`.

- [ ] **Step 6: Run everything**

Run: `just verify`
Expected: PASS.

- [ ] **Step 7: Commit, PR, watch CI, merge**

```bash
git add -A
git commit -m "feat: carry hook-body suites and guardrail gates"
git push -u origin feat/gates
gh pr create --fill
gh pr checks --json name,state
gh pr merge --rebase
```

---

### Task 9: Bob targets — SKIPPED (Bob retired 2026-08-11)

**Do not execute this task.** The checkpoint was resolved before execution: Bob is retired, `~/.bob` does not exist on this machine, and no Bob deployment manifest is present. Nothing under `$OLD/agents/bob/` is carried forward. Bob-related issues close as obsolete in Task 11. The steps below are retained only as a record of what was dropped.

<details>
<summary>Dropped steps (do not run)</summary>


**Files:**
- Create: `dot_bob/settings.json`, `dot_bob/AGENTS.md`, `dot_bob/custom_modes.yaml`, `dot_bob/settings/custom_modes.yaml`, `dot_bob/mcp.json`, `dot_bob/mcp_settings.json`, `dot_bob/rules/` (tree), `run_after_sync-bob-skills.sh.tmpl`

**Interfaces:**
- Consumes: adept's `skills/` tree (via a fresh clone — Bob has no plugin system).
- Produces: `~/.bob/` fully chezmoi-owned; `~/.bob/skills` as a symlink to a chezmoi-maintained clone of adept.

- [ ] **Step 1: Branch; drift-check and capture Bob's files**

```bash
git checkout main && git pull && git checkout -b feat/bob
diff <(jq -S . "$OLD/agents/bob/shared/settings.base.json") <(jq -S . ~/.bob/settings.json)
diff <(jq -S . "$OLD/agents/bob/shared/mcp.json") <(jq -S . ~/.bob/mcp.json)
diff <(jq -S . "$OLD/agents/bob/shared/mcp.json") <(jq -S . ~/.bob/mcp_settings.json)
cmp "$OLD/agents/bob/shared/AGENTS.md" ~/.bob/AGENTS.md
```

Expected: no output anywhere (`mcp.json` and `mcp_settings.json` are the same document — the old installer wrote one source to both destinations). Stop and reconcile on any difference.

```bash
chezmoi add ~/.bob/settings.json ~/.bob/AGENTS.md ~/.bob/mcp.json ~/.bob/mcp_settings.json
chezmoi add ~/.bob/custom_modes.yaml ~/.bob/settings/custom_modes.yaml
chezmoi add ~/.bob/rules
```

(`mcp.json`/`mcp_settings.json` and the two `custom_modes.yaml` copies are intentional duplicates in source, replacing the installer's multi-destination write; they are two files edited together in one repo — acceptable without a gate.)

- [ ] **Step 2: Bob's skills via a maintained clone + symlink**

`run_after_sync-bob-skills.sh.tmpl` (entire file):

```bash
#!/bin/bash
set -euo pipefail
clone="{{ .chezmoi.homeDir }}/.local/share/adept"
if [ -d "$clone/.git" ]; then
  git -C "$clone" pull --ff-only --quiet
else
  git clone --quiet git@github.com:randomparity/adept.git "$clone"
fi
ln -sfn "$clone/skills" "{{ .chezmoi.homeDir }}/.bob/skills"
```

Note: Task 10 removes the installer's `~/.bob/skills` copy before `chezmoi apply`, so `ln -sfn` creates the symlink cleanly.

- [ ] **Step 3: Verify, commit, PR, merge**

Run: `chezmoi verify ~/.bob/settings.json ~/.bob/AGENTS.md`
Expected: exit 0.

```bash
git add -A
git commit -m "feat: capture Bob configuration; sync skills from adept clone"
git push -u origin feat/bob
gh pr create --fill
gh pr merge --rebase
```

</details>

---

### Task 10: Cutover on this machine

**Run this outside any active Claude Code session doing other work** — it removes and re-creates `~/.claude/settings.json` (hooks, permissions).

**Files:**
- Modify (host state, not repo): `~/.claude`, `~/.codex`

**Interfaces:**
- Consumes: everything from Tasks 1–9.
- Produces: a machine running entirely on plugin + chezmoi; the runbook other machines follow is the dotfiles README (Task 6 Step 5) — if this task deviates from it, fix the README in the same turn.

- [ ] **Step 1: Remove the installer's deployment, manifest-driven**

```bash
for dir in ~/.claude ~/.codex; do
  m="$dir/.agent-config-manifest"
  [ -f "$m" ] || continue
  while IFS= read -r rel; do
    [ -e "$dir/$rel" ] && trash "$dir/$rel"
  done < "$m"
  trash "$m"
done
```

Expected: `~/.claude` loses `settings.json`, `CLAUDE.md`, `statusline.sh`, `skills`, `languages`, `references`, `licenses/superpowers.LICENSE`; `~/.codex` loses `config.toml`, `AGENTS.md`, `skills`, `languages`, `references`, `licenses/superpowers.LICENSE`. Everything is recoverable from Trash. Leave `~/.claude/.agent-config-backups` alone for now. (`~/.bob` does not exist — Bob is retired.)

- [ ] **Step 2: Apply chezmoi**

```bash
chezmoi apply
chezmoi verify
```

Expected: both exit 0. Config files are back, byte-identical to source; `~/.codex/languages` and `~/.codex/references` are now symlinks.

- [ ] **Step 3: Install the plugin (Claude)**

```bash
claude plugin install adept@randomparity
claude plugin list
claude plugin details adept
```

Expected: `adept` enabled; details report 36 skills and the 2 MCP servers.

- [ ] **Step 4: Register with Codex**

```bash
codex plugin marketplace add git@github.com:randomparity/adept.git
codex plugin marketplace list
```

Expected: `adept` installed from the SSH URL.

- [ ] **Step 5: End-to-end proof (done means proven)**

In a fresh `claude` session: confirm the skill list shows the 36 adept skills (namespaced to the plugin), `/statusline`-driven status line still renders, and one skill invocation works end-to-end (e.g. ask for `/preflight` in a scratch repo). In a fresh `codex` session: confirm skills are listed. Record the observed results in the task report — which arms ran and what they showed.

- [ ] **Step 6: Duplicate-skill check**

Run: `ls ~/.claude/skills 2>&1`
Expected: `No such file or directory` — user-scope skill copies are gone; only the plugin provides them. If the directory exists, something re-created it; investigate before proceeding.

---

## Phase 3 — decommission agent-config

### Task 11: Sweep the open issues

**Files:** none (GitHub state only).

**Interfaces:**
- Consumes: adept ADR 0001 URL (cite in every close comment); dotfiles test suites (Task 8) as the new home for hook issues.

Disposition table for all 37 open issues. Transfers use `gh issue transfer <n> randomparity/<repo>`; closes use `gh issue close <n> --reason "not planned" --comment "Obsoleted by the adept/dotfiles split — see randomparity/adept docs/adr/0001. <one line naming what died: the overlay merge / the installer / the retired gate>"`.

- [ ] **Step 1: Close the issues whose subject no longer exists** (installer, overlay protocol, retired deployment gates, deleted visual companion):
  `77, 78, 85, 118, 120, 147, 152, 161, 164, 171, 178, 180, 181`
  For #118 specifically, the close comment notes the replacement: a host-private `permissions.deny` entry is now a chezmoi per-host template in dotfiles — additive host config is expressible by construction.
  For #77 and #78, the close comment names the reason precisely: the brainstorming visual companion was deleted rather than fixed, because the rewrite design bans long-lived processes by construction (spec §4 rule 3). Both bugs are defects in exactly the liveness logic that ban removes. Deleted in adept commit `aca0ba2`.

- [ ] **Step 2: Transfer the hook-body and settings-guard issues to dotfiles:**
  `86, 139, 156, 157, 160, 165, 170, 179, 182`

- [ ] **Step 3: Transfer the skill-content and carried-gate issues to adept:**
  `4, 44, 45, 46, 47, 48, 64, 138, 148, 153, 158, 159, 163, 167, 174`
  (#167 spans gate scripts in both repos — transfer to adept and open a sibling issue in dotfiles referencing it.)

- [ ] **Step 4: Verify zero open issues remain**

Run: `gh issue list --repo randomparity/agent-config --state open --json number --limit 50`
Expected: `[]`.

---

### Task 12: Point, archive, and clean up

**Files:**
- Modify: `$OLD/README.md` (replace body with a pointer)

**Interfaces:**
- Consumes: completed Tasks 10–11.
- Produces: archived `randomparity/agent-config`; local clones reconciled.

- [ ] **Step 1: Replace the old README with a tombstone pointer (via PR)**

```bash
cd "$OLD" && git checkout -b docs/tombstone
```

New `README.md` body (keep the first heading, replace everything else):

```markdown
# agent-config (archived)

Superseded 2026-08-11 by:

- **[randomparity/adept](https://github.com/randomparity/adept)** — the skills,
  as a Claude Code plugin marketplace and Codex plugin. See its ADR 0001 for
  why the installer was retired.
- **randomparity/dotfiles** (private) — agent configuration, chezmoi-owned
  whole files. No overlay merge exists anymore.

History, ADRs 0001–0057, and debt records remain browsable here.
```

```bash
git add README.md
git commit -m "docs: point to adept and dotfiles successors"
git push -u origin docs/tombstone
gh pr create --fill
gh pr merge --rebase
```

Note: this repo's `verify` CI still runs on the PR and must pass — a doc-only change should not trip it; if it does, that finding goes in the report, not under the rug.

- [ ] **Step 2: Archive**

```bash
gh repo archive randomparity/agent-config --yes
```

- [ ] **Step 3: Local cleanup**

```bash
cd "$OLD" && git checkout main && git pull && git branch -d docs/tombstone && git remote prune origin
```

Keep the local clone (it is the archive's working copy and `$OLD` references die with this plan). The second working directory `/Users/dave/src/agent-config`, if it is a clone of the same repo, gets the same `git pull`; remove it only with the user's say-so — it predates this plan.

- [ ] **Step 4: Confirm the estate**

Run: `gh repo view randomparity/agent-config --json isArchived` → `true`; `gh repo view randomparity/adept --json visibility` → `PRIVATE`; `gh repo view randomparity/dotfiles --json visibility` → `PRIVATE`.

---

## Deliberately not carried (flag, don't smuggle)

- **`install.sh` / `install-test.sh` / overlay protocol / `examples/hosts`** — no successor by design (ADR 0001).
- **`check-deployed-membership.sh`, `check-deployed-references.sh`** — modeled the installer; the plugin cache + `validate --strict` replace them.
- **`check-skill-layout.sh` + suite (1,316 lines)** — retired by rewrite spec §4 rule 4. Replaced by `check-skill-shape.sh` (~100 lines, Task 3 Step 2b), which keeps the structural rules — a `SKILL.md` exists, its declared name matches its directory, no reserved-name collision, every `` `$invocation` `` resolves — and drops the content-scanning rules that generated the false reds. The encoding rules go with it: a plugin cache copies bytes, and a mis-encoded document is visibly broken rather than silently wrong.
- **`check-carrier-drift.sh`, `check-shared-standards.sh`** — kept the standards text synchronized across `agents/*/shared` copies. Those copies now live as independent whole files in dotfiles (`dot_claude/CLAUDE.md`, `dot_codex/AGENTS.md`). Cross-file drift is again possible. **Accepted for v1** (two files, one repo, edited side by side); if drift bites, the chezmoi-native fix is a `.chezmoitemplates/` shared partial with a per-carrier variable — file that as a dotfiles issue at the moment of first drift, not before (YAGNI).
- **`install-tools.sh`** — machine provisioning, orthogonal to both repos' purpose. Dies with agent-config. If tool bootstrap is missed on a future new machine, re-home it as a `run_onchange_` script in dotfiles; file the issue then.
- **The old repo's 49 ADRs / 12 debt records** — remain in the archive; adept and dotfiles start their own numbering.
