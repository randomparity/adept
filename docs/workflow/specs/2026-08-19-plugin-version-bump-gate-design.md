# A versioned plugin manifest and a bump gate — design

Issue: randomparity/adept#145. Decision record:
`docs/adr/0022-versioned-manifest-and-bump-gate.md`.

Every citation below is at `67cc60d`, this change's merge-base with `main`, on macOS 25.6.0
with Claude Code 2.1.235 and `codex-cli` 0.147.0.

## Problem

#145 asks for a version on the skills and a process for updating it. Two things about the
current state have to be established before the shape of the answer is decidable, and both
were checked rather than assumed.

`claude plugin validate ./` at `67cc60d` exits 0 with exactly one warning,
`plugins[0] plugin.json → version: No version specified`. That warning is the issue's
starting point, and `CLAUDE.md:52` records it as expected and accepted, alongside the rule
that `--strict` must not be added because it promotes that warning to an error.

The premise the issue states — "Skills support a version (i.e. in Claude Code Marketplace)" —
does not hold at the skill level. The Claude Code frontmatter reference names nineteen
SKILL.md fields and `version` is not one of them, and an unexpected key is a hard error that
prints the allowed set. The version the marketplace warning refers to is the plugin's.

The blocking fact is what the field does once present. Per the plugins reference, Claude Code
resolves a plugin's version from `plugin.json`, then the marketplace entry, then the git
commit SHA, then an archive digest, then `unknown`, and skips the update when the resolved
version matches what is installed. So adding the field takes the update trigger away from the
SHA. Today every merge to `main` reaches every machine; with a version declared, a merge that
does not bump it reaches none, silently.

That is precisely the ritual `docs/adr/0001-distribution-via-plugin-marketplace.md:104-105`
rejected, whose stated revisit condition — external consumers who need to pin — is not met.
The repository owner decided to adopt the version anyway with the pinning behaviour on the
table; ADR 0022 records that and the mitigation this change builds.

Measured, so the `--strict` half is not assumed either: a copy of the tree at `67cc60d` with
`"version": "0.1.0"` added to `.claude-plugin/plugin.json` passes
`claude plugin validate` **and** `claude plugin validate --strict` at exit 0 with no
warnings.

## Requirements

1. `.claude-plugin/plugin.json` declares a version, and one place does.
2. A gate refuses a change that leaves it alone, because the failure it prevents is silent.
3. The bump process is stated where a contributor reads it: `CLAUDE.md`, and `README.md` for
   the user-visible update story.
4. The gate is deterministic and structural — anatomy rule 4 forbids a gate that asserts on
   prose, and this one reads JSON and git, not Markdown.
5. Executable code clears anatomy rule 2. This is a deterministic git-and-JSON comparison
   against a base ref, which a model cannot perform reliably by reading.
6. Bash 3.2 floor, tab indentation under `scripts/`, `rg --no-config`, explicit exit-status
   capture, and the exit contract the other `scripts/` gates state (0 clean, 1 finding,
   2 fault).
7. Documents that assert the old policy stop asserting it: `CLAUDE.md`, `README.md`, and the
   `.github/workflows/verify.yml` comment that justifies an unpinned CLI by citing "the
   version-bump ritual this repo exists to remove".
8. ADR 0001 is not rewritten. It is append-only once merged, and only one of its paragraphs
   is replaced.
9. `just verify` passes, `just records` included.

## Design

The decision and its rejected alternatives live in ADR 0022 and are not restated. What the
implementation produces:

**One version, in `.claude-plugin/plugin.json`, starting at `1.0.0`.** Not in the marketplace
entry and not in `.codex-plugin/plugin.json`: `plugin.json` outranks the marketplace entry in
the harness's resolution order, so a second copy is a drift surface with a winner already
declared. `1.0.0` rather than `0.1.0` because twenty-seven skills are already installed and
depended on, and a `0.x` stream cannot express the `MAJOR` bump that a removed or renamed
skill owes. The starting number is reversible; the scheme is not.

**A narrowed version shape.** `MAJOR.MINOR.PATCH`, plain decimal fields, no leading zeros, no
prerelease suffix, no build metadata. The gate's ordering is three integer comparisons.

**`scripts/check-plugin-version.sh`**, three rules:

| rule | statement | failure |
|---|---|---|
| 1 | `.claude-plugin/plugin.json` declares a `version` | exit 1 |
| 2 | it is `MAJOR.MINOR.PATCH` as narrowed above | exit 1 |
| 3 | when the working tree differs from `BASE_SHA` at all, it is strictly greater than the base ref's | exit 1 |

Rule 3 is "at all" rather than "in the shipped paths". An allowlist of shipped paths fails in
the silent direction — a directory added later is outside it, so its changes stop demanding a
bump and stop reaching installed copies with nothing said — and requiring a bump for every
change reproduces exactly what the SHA scheme gave, since every merge was already an update.

Faults (exit 2), each one a state where a rule is undecided rather than violated: no manifest,
a manifest that will not parse, a `BASE_SHA` that is not a commit, a git diff or tree read
that could not run, a base-ref version that is not `MAJOR.MINOR.PATCH`, and an empty
`BASE_SHA` inside CI. Exit 1 stays reserved for a content finding, so a run that stopped never
reads as a version the author must fix.

Two bootstrap states pass rule 3 with a note: a base ref whose manifest declares no version,
and a base ref with no manifest at all. The first is the state of every ref before this
change, including this change's own base.

**`BASE_SHA` governs rule 3**, the variable `.github/scripts/check-records.sh` already reads
and `.github/workflows/verify.yml:56` already sets from
`github.event.pull_request.base.sha || github.event.before`. Unset outside CI, the gate checks
rules 1 and 2 and prints that the third did not run; unset inside CI, it is fatal, so the rule
cannot be switched off by dropping one `env:` line. The consequence is stated rather than
engineered around: `just verify` on a workstation does not check the bump, and the required
check in CI does. Resolving a base ref a second way here would be a competing mechanism for a
job the records gate already owns one of.

**`just plugin-check` gains `--strict`.** The one accepted warning was the missing version;
`CLAUDE.md` already called any other warning a defect.

**ADR 0001 gets a cross-reference, not a banner.** Only its version paragraph is replaced, and
the supersession banner this repository uses means the record as a whole — `0002` and `0007`
both carry one for a full supersession. A banner on `0001` would tell a reader the plugin-
marketplace decision had been replaced, which is false. Instead one appended sentence under
the rejected bullet points at `0022`. Appending is what the append-only rule permits;
`check_sections_append_only` fails on removed lines only.

## Files changed

| file | change |
|---|---|
| `.claude-plugin/plugin.json` | new — `"version": "1.0.0"` |
| `scripts/check-plugin-version.sh` | new — the gate |
| `scripts/check-plugin-version-test.sh` | new — its fixture suite, auto-discovered by `just test` |
| `scripts/git-fixture-isolation-test.sh` | the new suite joins the hardcoded list of git-fixture suites |
| `Justfile` | new `version-check` recipe, added to `verify`; `plugin-check` gains `--strict` |
| `CLAUDE.md` | the accepted-warning paragraph becomes the version contract and the bump levels |
| `README.md` | the *Update* section states the version and the gate instead of the SHA |
| `.github/workflows/verify.yml` | the CLI-pinning comment stops citing a removed ritual |
| `docs/adr/0022-versioned-manifest-and-bump-gate.md` | new — the decision |
| `docs/adr/0001-distribution-via-plugin-marketplace.md` | one appended cross-reference under the rejected bullet |
| `docs/workflow/specs/2026-08-19-plugin-version-bump-gate-design.md` | this file |
| `docs/workflow/plans/2026-08-19-plugin-version-bump-gate.md` | the implementation plan |

## Out of scope

- Per-skill versions. There is no frontmatter field for one, established above.
- Release tagging, changelogs and `gh release create` — issue #50, which is the release-stage
  question for target repositories and states this repository's own posture as a premise. That
  premise changes with this record; the issue's question does not.
- Codex's version handling. `.codex-plugin/plugin.json` carries `name`, `description` and
  `skills`, and this repository does not re-implement a schema it does not own (ADR 0001).
- Any gate over the version's *meaning* — whether a `MINOR` bump really added a capability is
  a reading problem, and anatomy rule 4 governs it.

## Verification

`just verify` in the worktree, bare. Within it, `just version-check` runs with no `BASE_SHA`
and reports rules 1 and 2 only; `just test` runs `scripts/check-plugin-version-test.sh` with
its own fixtures, which is where rule 3 is exercised. `just plugin-check` now runs `--strict`
and must produce no warnings at all.

The suite's own bite was measured rather than assumed: eight mutations of the gate — a loose
version regex, a lexical instead of numeric field comparison, rule 3 removed, an empty
`BASE_SHA` tolerated in CI, a swallowed `jq` failure, rule 3 allowed to run on a version rules
1 and 2 rejected, and each of the two shape checks removed in turn — each turned the suite red
on its own, and it passes again with the gate restored.

`scripts/git-fixture-isolation-test.sh` carries a hardcoded list of the suites that build git
fixtures, and runs each under a hook-shaped environment with `GIT_DIR`, `GIT_INDEX_FILE` and
friends pointing at a disposable repository. The new suite builds git fixtures, so it joins
that list; without the entry its isolation is asserted by `clear_git_env` and checked by
nothing.
