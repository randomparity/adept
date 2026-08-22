# Implementation plan — a versioned plugin manifest and a bump gate

Goal: declare a `version` in `.claude-plugin/plugin.json` and add a gate that refuses a change
leaving it alone, so the field that satisfies the validator cannot silently stop delivering
updates.

Architecture: one JSON field, one bash gate with its fixture suite, one `Justfile` recipe, and
the documents that asserted the old policy. The decision is
`docs/adr/0022-versioned-manifest-and-bump-gate.md`; the design is
`docs/workflow/specs/2026-08-19-plugin-version-bump-gate-design.md`.

Tech stack: bash 3.2, `jq`, `git`, `just`. No build step.

## Global constraints

- **Repository is public.** No absolute user paths, hostnames, addresses, or session state.
  `scripts/check-public-safety.sh` enforces this; plans and specs name the checkout root
  `$WORK`.
- **Anatomy rule 2** — executable code clears a bar. The gate is a deterministic comparison
  against a base ref, which is the class of work the rule admits.
- **Anatomy rule 4** — nothing automated asserts on prose. The gate reads JSON and git output;
  no rule of it looks at Markdown.
- **Shell house style** — `#!/usr/bin/env bash`, `set -euo pipefail`, tab indentation under
  `scripts/`, bash 3.2 floor (no arrays, no `mapfile`, no associative arrays), `rg --no-config`
  wherever `rg` is used, and every scan's exit status captured rather than `|| true`.
- **Exit contract** — 0 clean, 1 on a content finding, 2 on a fault. Nothing that merely
  stopped the gate from running may report 1.
- **Guardrail command** — `just verify`, run bare. No pipes, no `|| true`.
- **Branch** — `feat/plugin-version-and-bump-gate-145`; `BASE_BRANCH` is `main`.
- **ADR 0001 is append-only.** Add to it; remove nothing from it. `check_sections_append_only`
  fails on removed lines, and `check_headings_intact` on a reworded heading.

## Files

| file | responsibility |
|---|---|
| `.claude-plugin/plugin.json` | the sole home of the version |
| `scripts/check-plugin-version.sh` | the three rules |
| `scripts/check-plugin-version-test.sh` | the fixture suite, auto-discovered by `just test` |
| `scripts/git-fixture-isolation-test.sh` | its hardcoded suite list gains the new suite |
| `Justfile` | `version-check`, its place in `verify`, and `--strict` on `plugin-check` |
| `CLAUDE.md`, `README.md`, `.github/workflows/verify.yml` | the prose that asserted no version |
| `docs/adr/0022-…`, `docs/adr/0001-…` | the decision and its cross-reference |

## Task 1 — the gate and its suite

**Creates:** `scripts/check-plugin-version.sh`, `scripts/check-plugin-version-test.sh`.
**Modifies:** nothing.

### Interfaces

Consumes: `BASE_SHA` and `GITHUB_ACTIONS` from the environment, an optional repository root as
`$1` (the shape `check-skill-shape.sh` and `check-ripgrep-config.sh` already take, and what
lets the suite point it at a fixture). Produces: an exit status and one line per verdict.

### Step 1.1 — the three rules

Rule 1: `.claude-plugin/plugin.json` declares a `version`. Rule 2: it matches
`^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$`. Rule 3: when
`git diff --quiet "$BASE_SHA" --` reports differences, the declared version is strictly
greater than the base ref's.

Read the version with `jq -r 'if has("version") then (.version | tostring) else "" end'`.
`tostring` is load-bearing: a version written as a JSON number parses, and reading it as
absent would report "declares no version" against a manifest that declares one badly.

The reader reports through a variable and a status, and its callers fault. `fault` inside a
command substitution ends the subshell and lets the caller continue with an empty value — the
failure mode `check-skill-shape.sh` documents at its own `name_listed`.

### Step 1.2 — the fault set

Exit 2, each one a rule left undecided rather than violated:

- no manifest at the path, or one `jq` will not parse;
- `BASE_SHA` set to something that is not a commit;
- a `git diff` or `git ls-tree` that could not run — capture the status, and branch on 0, 1
  and above-1 separately;
- a base-ref version that is not `MAJOR.MINOR.PATCH`, which cannot be ordered and cannot be
  fixed by the change under review;
- an empty `BASE_SHA` while `GITHUB_ACTIONS` is set.

Separate "absent from the base ref" from "unreadable at the base ref" with
`git ls-tree --name-only`: `git show` alone exits 128 for both. Empty output at exit 0 is
absent; a non-zero exit is a fault.

### Step 1.3 — the degraded and bootstrap paths

`BASE_SHA` unset outside CI: check rules 1 and 2, print that the bump rule did not run, exit
on the finding status. A base ref that declared no version, or had no manifest: rule 3 is
satisfied by any accepted version; print which case it was.

### Step 1.4 — the suite

Fixtures are git repositories under `SCRATCH`, built with `test-fixture-helpers.sh`
(`clear_git_env`, `fixture_init`, `fail`) so a caller's `GIT_DIR` cannot reach them. Every
invocation sets `BASE_SHA` and `GITHUB_ACTIONS` explicitly, including to empty — inheriting
an ambient `BASE_SHA` exported for the records gate would run a different suite.

Cases: no version; each malformed shape (`1.0`, `1`, `v1.0.0`, `1.0.0-rc.1`, `1.0.0+build.5`,
`01.0.0`, `1.0.0.0`, `latest`); a version as a JSON number; `0.0.0`; a change without a bump;
a change with one; `1.2.9 → 1.2.10` against a lexical comparison; a version moved backwards; a
tree matching the base ref; an untracked file only; both bootstrap states; a malformed base-ref
version; a `BASE_SHA` that is not a commit; an unparseable manifest; an absent manifest; unset
`BASE_SHA` outside CI both clean and with a bad version; empty `BASE_SHA` inside CI.

Add the suite to the hardcoded list in `scripts/git-fixture-isolation-test.sh`. That suite runs
every git-fixture suite under a hook-shaped environment with `GIT_DIR`, `GIT_INDEX_FILE` and
`GIT_WORK_TREE` aimed at a disposable repository, and fails one that touches it. A new
git-fixture suite left off the list has its isolation asserted and checked by nothing.

### Step 1.5 — prove the suite bites

Break the gate, watch the suite redden, restore. At minimum: loosen the version regex, compare
version fields lexically, remove rule 3, tolerate an empty `BASE_SHA` in CI, swallow the `jq`
failure, let rule 3 run on a version rules 1 and 2 rejected, and remove each of the two shape
checks in turn. Each must turn the suite red on its own, and the suite must pass again once the
gate is restored. Report what was run.

## Task 2 — declare the version and wire the gate in

**Modifies:** `.claude-plugin/plugin.json`, `Justfile`.

Add `"version": "1.0.0"` after `"name"`. Nothing goes in
`.claude-plugin/marketplace.json` or `.codex-plugin/plugin.json`.

Add a `version-check` recipe running the gate, place it in `verify` after `plugin-check`, and
change `plugin-check` to `claude plugin validate ./ --strict`. Do **not** add `version-check`
to `commit-check`: that recipe runs from the prek pre-commit hook with no `BASE_SHA`, so it
would add a rules-1-and-2 pass to every commit and check nothing the pull request does not.

## Task 3 — the prose that asserted no version

**Modifies:** `CLAUDE.md`, `README.md`, `.github/workflows/verify.yml`.

`CLAUDE.md` — replace the accepted-warning paragraph and the "any other warning" line with the
`--strict` statement, the gate's three rules, the `MAJOR`/`MINOR`/`PATCH` levels, the
single-home rule, and the local-versus-CI boundary.

`README.md` *Update* — the version and the gate replace "Manifests carry no `version` field:
updates track the git SHA".

`.github/workflows/verify.yml` — the comment justifying an unpinned Claude Code CLI cites "the
version-bump ritual this repo exists to remove", which stops being true. Keep the reason that
still holds — validating against the harness people actually run — and drop the citation.

## Task 4 — the records

**Creates:** `docs/adr/0022-versioned-manifest-and-bump-gate.md`, the design spec, this plan.
**Modifies:** `docs/adr/0001-distribution-via-plugin-marketplace.md`.

ADR 0022 needs an H1 beginning `# 0022 `, a `## Status` body of `Accepted (2026-08-19)`, and
the five required level-2 sections. Every `Considered & rejected` bullet opens its ground with
`verified:` or `judgment:` per ADR 0019, and a `verified:` ground names what was run and where.
No index row: `docs/adr/README.md` carries no table and the gate warns (`W-INDEX-TABLE`) if one
appears.

ADR 0001 gets one appended cross-reference under its
*Give the manifests a `version` and bump it per release* bullet, naming 0022 and stating that
only the version paragraph is replaced. **No supersession banner** — the banner means the whole
record, and 0001's distribution decision stands. Remove nothing and reword no heading.

## Verification

Run, bare, from the worktree root:

```sh
just verify
```

Expect exit 0. Within it: `just version-check` prints
`version 1.0.0 declared; BASE_SHA unset, so the bump rule did not run`; `just plugin-check`
passes `--strict` with **no** warnings, where the old expectation was exactly one;
`just records` validates the new ADR and the appended line in 0001; `just test` runs the new
suite among the rest.

Then confirm rule 3 in the environment it actually runs in — CI, where `BASE_SHA` is set —
rather than only through fixtures:

```sh
BASE_SHA=$(git merge-base HEAD main) ./scripts/check-plugin-version.sh
```

Expect exit 0 and a line naming the bootstrap case, because `main` declares no version yet.

## Acceptance criteria

1. `.claude-plugin/plugin.json` declares `"version": "1.0.0"`; no other manifest declares one.
2. `scripts/check-plugin-version.sh` implements the three rules and the fault set, exits 0/1/2
   as specified, and is discovered by `just lint` and `just format-check`.
3. `scripts/check-plugin-version-test.sh` covers every case in step 1.4, is discovered by
   `just test`, and is listed in `scripts/git-fixture-isolation-test.sh`.
4. Each mutation in step 1.5 turns the suite red; the restored gate turns it green.
5. `just plugin-check` runs `--strict` and produces no warnings.
6. `CLAUDE.md`, `README.md` and `.github/workflows/verify.yml` assert no removed policy.
7. ADR 0001 has lines added and none removed, and carries no supersession banner.
8. `just verify` exits 0.

## Rollback

`git revert` of the branch restores the previous state in one step: removing the `version`
field returns the harness to SHA-tracked updates, and the gate, the recipe and the documents go
with it. No generated artifact and no external state is involved. An installed copy pinned at
`1.0.0` resumes SHA tracking on its next update once the field is gone.
