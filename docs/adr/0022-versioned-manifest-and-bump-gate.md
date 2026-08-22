# 0022 — A versioned plugin manifest, bumped by a gate

## Status

Accepted (2026-08-19)

## Context

[ADR 0001](0001-distribution-via-plugin-marketplace.md) decided that the manifests carry no
`version` field: updates track the git SHA, so every push to `main` is an update and there is
no version-bump ritual. Its `Considered & rejected` list names the alternative — *give the
manifests a `version` and bump it per release* — and its stated condition for revisiting is
external consumers who need to pin. Issue #145 asks for the version and a process for
updating it. This record answers that issue and replaces that one paragraph of 0001.

Three facts bound the answer. Two of them were not available when 0001 was written.

**A version can only live on the plugin.** A skill has no version field. The Claude Code
SKILL.md frontmatter reference lists `name`, `description`, `argument-hint`, `arguments`,
`disable-model-invocation`, `user-invocable`, `allowed-tools`, `disallowed-tools`, `model`,
`effort`, `context`, `agent`, `background`, `hooks`, `paths`, `shell`, `metadata`, `license`
and `compatibility`, and an unexpected key is a hard error naming the allowed set. So "a
version for the skills" is one version for all 27, declared where the harness reads one.

**The field pins.** For every source type but `command`, Claude Code resolves a plugin's
version from `plugin.json`, then the marketplace entry, then the git commit SHA, then an
archive digest, then `unknown`; it compares the resolved version against what is installed
and **skips the update when they match**. Declaring a version therefore does not merely
label a release — it takes over the update trigger from the SHA. A change merged with the
version left alone reaches no installed copy, on every machine, with nothing to notice. That
is the concrete shape of the "ritual" 0001 rejected, and it is a silent failure rather than
a loud one.

**`--strict` stops being unusable.** 0001 traded against it and CLAUDE.md forbade it,
because the missing-version warning is the one it promotes to an error. With the field
present, `claude plugin validate ./` and `claude plugin validate ./ --strict` both pass at
exit 0 with no warnings, so the trade 0001 recorded no longer has two sides.

What has not changed is the premise 0001 named for revisiting. There are no external
consumers pinning adept, and this record does not claim any. The version is adopted for the
issue that asked for it, and the update trigger it takes over is what the rest of this
record is about.

## Decision

**`.claude-plugin/plugin.json` declares a `version`, starting at `1.0.0`.** It is the only
place a version lives. `plugin.json` outranks the marketplace entry in the harness's own
resolution order, so a copy in `.claude-plugin/marketplace.json` could only ever disagree
with it, and `.codex-plugin/plugin.json` gets none for the same reason.

**The version is `MAJOR.MINOR.PATCH` and nothing else** — plain decimal fields, no leading
zeros, no prerelease suffix, no build metadata. Narrower than semver, because the ordering
the gate needs is three integer comparisons and semver's prerelease precedence rules are a
parser with no consumer here.

**Every change to this repository bumps it.** Not every change to a shipped path — every
change. `MAJOR` when a skill is removed or renamed or an invocation's contract breaks,
`MINOR` when a skill or reference is added or gains a capability, `PATCH` otherwise.

**`scripts/check-plugin-version.sh` enforces it**, wired into `just verify` as
`just version-check`. Three rules: the version exists; it has the shape above; and it is
strictly greater than the base ref's whenever the working tree differs from `BASE_SHA` at
all. It reads the same `BASE_SHA` the records gate reads and the workflow already sets, and
follows the same degradation — unset outside CI it checks the first two rules and says the
third did not run, unset inside CI it is fatal. Exit 0 clean, 1 on a finding, 2 on a fault,
the contract the other gates under `scripts/` state.

**`just plugin-check` gains `--strict`.** CLAUDE.md already said any warning beyond the
missing-version one is a defect; `--strict` is that sentence enforced rather than read.

## Consequences

A bump is now part of every pull request: one line in one file, refused by a required check
when it is missing. That is the ritual 0001 declined, and this record accepts it in exchange
for a validator that passes clean and an update trigger that is stated rather than implied.

The rule is "every change" rather than "every shipped change" deliberately. Any allowlist of
shipped paths fails in the silent direction — a directory added later sits outside the list,
so its changes stop demanding a bump and stop reaching installed copies with nothing said —
and the list is a second inventory to keep. Requiring a bump for every change reproduces
exactly what 0001 had, since under the SHA scheme every merge was already an update.

Version numbers therefore carry no information about whether skills changed. A `PATCH` bump
may be a typo in this file. `MAJOR` and `MINOR` still mean what they say; `PATCH` means
"something changed".

The bump rule does not run on a workstation. `BASE_SHA` is a CI value, `just verify` locally
checks the first two rules only, and the pre-push hook re-runs `just verify` rather than
supplying a base ref — so a forgotten bump reaches the pull request and is caught there. A
second base-ref resolution here, guessing at `origin/main`, would be a competing mechanism
for a job the records gate already owns one of.

Concurrent pull requests both touching `plugin.json` conflict on that line. The conflict is
one line and resolving it is choosing the higher number; the alternative — deriving the
version so nobody edits it — is rejected below.

ADR 0001 stands except for its `Manifests carry no version field` paragraph. Its
distribution decision, its configuration split, and the rest of its rejected list are
untouched, so it carries no supersession banner: a banner would tell a reader the whole
marketplace decision had been replaced, which is false. A cross-reference is appended to the
rejected bullet this record reverses.

## Considered & rejected

**Close #145 and keep 0001's no-version decision.** judgment: the issue is the repository
owner's, the decision to adopt a version was taken with the pinning behaviour on the table,
and nothing here overrides that.

**Put the version in `.claude-plugin/marketplace.json` as well, or instead.** verified: the
plugins reference gives the resolution order as `plugin.json`, then the marketplace entry,
then the git SHA — so a marketplace copy is dead where both are set, and two copies are a
drift surface with a winner already declared.

**Give each skill its own version in SKILL.md frontmatter, which is what #145's wording
asks for.** verified: the Claude Code frontmatter reference names nineteen fields and
`version` is not among them; an unexpected key errors with `Unexpected key(s) in SKILL.md
frontmatter: … Allowed properties are: allowed-tools, compatibility, description, license,
metadata, name`. Twenty-seven numbers no harness reads would be documentation of a feature
that does not exist.

**Full semver, prerelease identifiers and build metadata included.** judgment: this
repository publishes one linear stream to one marketplace. The precedence rules for
`1.0.0-rc.1` against `1.0.0-rc.2` are a parser to write and test for a case nobody has.

**Bump only when a shipped path changes, under an allowlist of `skills/`, `references/`,
`.claude-plugin/`, `.codex-plugin/` and `.mcp.json`.** judgment: it fails silently. A path
added later is outside the list and its changes quietly stop demanding a bump, which is the
same silent-staleness failure the gate exists to prevent, reached one level up.

**Derive the version instead of declaring it — a date, a commit count, or a CI step that
rewrites the manifest on merge.** judgment: a generated commit on `main` after every merge
is a long-lived automation with its own failure modes, and the manifest stops being
readable as source. The conflict it avoids is one line.

**Let the gate perform the bump rather than refuse the change.** judgment: a gate that
edits the tree it is checking is no longer a verdict, and the number it picks — patch,
always — is the one the author was supposed to think about.

**Enforce the bump with a `prek` hook at commit time instead of in CI.** verified: the bump
rule needs a base ref, and `commit-check` runs with no `BASE_SHA`; a hook would have to
resolve one itself, which is the competing base-ref mechanism the Consequences reject.

**Keep `just plugin-check` without `--strict`.** judgment: CLAUDE.md already declared any
other warning a defect, so the flag changes what is enforced rather than what is intended.
