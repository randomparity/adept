---
name: decision-records
description: "Use when a repo needs immutable numbered records — Architecture Decision Records or deferred-work records — that stay auditable and hard to erase. Defines the docs/adr/ and docs/debt/ record formats and installs the CI gate that fails a PR carrying a malformed record or one that stopped being a record. Referenced by $review-loop, which writes deferral records for its deferred-tracked disposition."
---

# Decision Records

Two record kinds share one gate: **ADRs** (`docs/adr/NNNN-slug.md`), which own an
architectural decision, and **deferral records** (`docs/debt/NNNN-slug.md`), which own a
concern a review judged valid and deliberately did not fix. Both are immutable once
merged, numbered one file per record with the directory listing as the index, and
resolved or superseded by a banner added in place rather than by editing or deleting the
record.

**The record is the owner, not a tracker issue.** A file works with no tracker, no
authentication, no network, and no human in the turn. It also lands in the diff, so the
reviewer of the resulting PR sees the decision or deferral at review time, which an issue
never achieves. An issue may *point* at a record for queue position; it is never the
owner.

## Architecture Decision Records

`docs/adr/NNNN-slug.md`, numbered one above the highest present.

```markdown
# NNNN — one line naming the decision

## Status

Accepted (YYYY-MM-DD)

## Context

What forced the decision, and the constraints in play.

## Decision

What was decided.

## Consequences

What this costs, going forward.

## Considered & rejected

Alternatives, and why each was not chosen.
```

`## Status` reads `Proposed`, `Deferred`, or `Accepted` / `Rejected` / `Superseded`
followed by `(YYYY-MM-DD)`. Supersede a merged ADR by adding a banner beneath its
existing status line — never by editing the decision itself:

```markdown
> **Superseded by [NNNN](NNNN-slug.md)** (YYYY-MM-DD)
```

The banner's link must resolve to a sibling record in the same directory. At
target-repository `docs/adr/README.md`, there is deliberately no index table. The directory
listing is the index,
so a decision-producing change touches only its own file plus that one banner when it
supersedes.

## Deferral records

`docs/debt/NNNN-slug.md`, numbered one above the highest present.

```markdown
# NNNN — one line naming the concern

## Status

Open
review-by: YYYY-MM-DD

## Concern

What the review found, with evidence. Enough that a reader who was not there can judge it.

## Why deferred

Why it is valid yet not owned by the change that found it.

## Non-regression boundary

What the deferring change must not make worse, and how that line is held.

## What would resolve it

The change that closes this, and how to tell it is done.

## Provenance

target: path/to/the/reviewed/file
Which run found it, and when. Optionally `tracker: #12` as a pointer.
```

`target:` and `review-by:` are **bare line-start literals** — column one, no bullet, no
indentation, no emphasis. Open records require `review-by:`; an idiomatic `- target: x`
does not match. Resolve a record by
replacing `Open` with `> **Resolved by <what>** (YYYY-MM-DD)` in its `## Status` in place,
and drop the `review-by:` line with it: the date asks when to re-evaluate a live concern,
and a resolved one has answered that. A line left behind does not go stale — the banner
retires the re-evaluation date, so a merged record is never reopened just to silence
`W-REVIEWBY-STALE`. It must still *parse*, though: `E-REVIEWBY-FORM` holds whatever state
the record is in, so a surviving line stays a bare ISO-8601 date and never grows an
annotation like `2026-10-25 (moot)`.

## Rules common to both, that the checker enforces

Write to these whether or not a repo has the gate:

- every required section present **and non-empty** — a heading with no content is not a
  record;
- record numbers are unique;
- target-repository `docs/adr/README.md` is the only non-record exception;
- and once a record is merged, its substantive sections are **append-only**. Adding a
  resolution or supersession banner, or appending detail, is fine; removing or rewriting
  what a section already said is not — including the record's own heading lines and the
  text between the title and the first section. `## Status` is exempt, since that is the
  section a resolution or supersession changes. The one further exception is a
  **marker-only** change, which is what the migrator below produces: a diff that alters
  nothing but the markers in the table there is permitted, and the diff proves that about
  itself, so there is no flag to set.

**Records are immutable once merged.** Renumbering without changing content is fine;
deleting, moving, or replacing a record with a symlink is not, and the gate fails all
three. There is no legitimate removal, so there is no "deleted with a banner" case.

**Grandfathering.** A record non-conforming at the base ref reports `W-LEGACY-SHAPE`
instead of an error for its structural findings — pre-template records are the motivating
case. Conformance is recomputed from the base ref on every
run, not stored: a record migrated into conformance is checked at full severity starting
the next run, with no flag or registry to curate. Anti-erasure findings and the rules that
are not decidable from one file's bytes alone (a supersession link, the index-table
heuristic, an orphaned `target:`) are never downgraded — they describe a change, or a file
that is not a record at all, not a record's own shape.

## Migrating a legacy record

`migrate-records.sh` brings a merged record's markers into the current form. Run it locally
from the repository root, never in CI. It is one of the six gate assets below, so a repo that
adopted the gate runs its own copy and needs nothing from this skill:

```sh
# from the skill, in a repo that has not adopted the gate
RECORD_PROFILES="adr debt" assets/migrate-records.sh
RECORD_PROFILES="adr debt" assets/migrate-records.sh --write

# from an adopted copy
RECORD_PROFILES="adr debt" ./.github/scripts/migrate-records.sh --write
```

Dry run by default; `--write` applies. It requires a clean worktree, touches only files
under each enabled profile's record directory, and never commits — commit the result on its
own, with the `Migrated-markers:` trailer lines it prints. Provenance is that commit, not a
label in the record: a `migrated:` line would be new content, and the gate would reject it.

Every transform is **line-local**. It rewrites markers and the case around text without
moving text between lines or regions:

| from | to |
|---|---|
| `# 1. Title`, `# ADR N: Title` | `# 0001 — Title`, the number from the filename |
| `## Status:`, `## status` | `## Status` |
| `accepted (2026-07-19)`, `ACCEPTED (2026-07-19)` | `Accepted (2026-07-19)` — case only |
| `accepted 2026-07-19` | `Accepted (2026-07-19)` — case and parentheses |
| `- target: path`, `  review-by: d` | `target: path`, `review-by: d` at column one |

**It does not invent content and it does not relocate it.** A bare `ACCEPTED` with no date
on the line is reported, not dated. A missing or empty section is reported for you to write,
never stubbed — a placeholder trades a warning for an `E-SECTION-EMPTY` error. A malformed
resolution banner is reported rather than guessed. A pre-template record that keeps its
status as a metadata bullet above the first heading keeps it, because turning that into a
section moves a line from outside every section into a new one; such a record gets its title
fixed and stays grandfathered, with a narrower `W-LEGACY-SHAPE` than before.

Before writing anything it canonicalises its own output against its input and aborts if they
differ over the regions the gate protects. That check is the gate's own allowance function,
not a second opinion about it, so it answers the only question worth asking: will the gate
reject this?

## Installing the gate

The gate is optional — both record formats stand alone — but a repo where reviews run
unattended (`$review-loop` inside `$work-issue` or `$campaign`) wants it, because there the
agent that wrote a record is the agent that would benefit from erasing it, and no human
sees the intermediate state.

Copy six files out of this skill's `assets/` directory. Resolve that directory from the
installed skill package before copying rather than assuming a client-specific config root:

| asset | destination |
|---|---|
| `check-records.sh` | `.github/scripts/check-records.sh` |
| `check-records-test.sh` | `.github/scripts/check-records-test.sh` |
| `migrate-records.sh` | `.github/scripts/migrate-records.sh` |
| `profiles/adr.sh` | `.github/scripts/profiles/adr.sh` |
| `profiles/debt.sh` | `.github/scripts/profiles/debt.sh` |
| `records.yml` | `.github/workflows/records.yml` |

**The migrator is not optional, even though it never runs in CI.** The suite the workflow
runs *first* resolves it beside itself — in an adopting repo, `.github/scripts/` —
because the migrator's self-check is the checker's own allowance function and the suite
exercises exactly that. Omit it and the suite reports the install as incomplete and stops, so
the `records` job never passes once, from the installing commit onward.

Copy **both** profile files even when only one record kind is in use. The self-protected
set that guards the gate's own files is derived from the base ref's `profiles/` listing,
not from which names are enabled, so an adopter checking only ADRs still carries and still
cannot delete `profiles/debt.sh`.

**Upgrade the same way: all six, never a subset.** The engine calls into the profiles by a
positional contract that changes between versions, so a newer profile against an older
engine aborts mid-run with a bare `profiles/<kind>.sh: line N: $4: unbound variable` — after
the reassuring `Checking N record(s)` line, and with no `E-` code to look up. The job fails
closed, which is the intent, but nothing in that message names the stale engine as the
cause. `REQUIRED_ASSETS` in the suite catches a *missing* file, never a mismatched one.
Cherry-picking the one file a fix touched is the way into this.

The workflow must set `RECORD_PROFILES` explicitly, naming every kind to enable, e.g.
`RECORD_PROFILES: adr debt` or `RECORD_PROFILES: debt`. There is no default — an adopter
that forgets it gets `E-PROFILE-NONE` rather than a silently skipped check.

First mark the three executables — and **only** those three:

```sh
chmod +x .github/scripts/check-records.sh \
         .github/scripts/check-records-test.sh \
         .github/scripts/migrate-records.sh
```

The natural glob (`.github/scripts/*.sh .github/scripts/profiles/*.sh`) is wrong and costs a
red job. The profiles are **sourced, never executed**, and correctly carry no shebang; a
shebang-less file with the execute bit set trips `check-executables-have-shebangs`, a stock
pre-commit hook, so a repo that runs pre-commit goes red from the installing commit. Sourcing
never consults the bit, so leaving the profiles at `0644` changes nothing functionally.

Then run `./.github/scripts/check-records-test.sh` and confirm it is green, run
`RECORD_PROFILES="adr debt" ./.github/scripts/check-records.sh` against the repo (naming
only the profiles you enabled), and commit the six files as one change. **The same
change must also add a real first record** for every enabled kind — there is no way
around this by design. Skip it and the local smoke-test run above still passes, because it
has no `BASE_SHA` and an absent record directory is only a failure once there is a base
ref to compare against (`E-PROFILE-DIR-MISSING`); the same commit stays red on every PR
from then on, since CI always supplies one. A placeholder such as `.gitkeep` does not help
— it makes the directory exist, but the placeholder itself is not a record and fails
`E-NOT-RECORD` regardless of `BASE_SHA`. Nothing depends on this skill afterwards — the
adopting repo owns its copy outright, and the copy will not track fixes made here.

Check before installing:

- **A deny-list `.gitignore`** may hide the new paths. `git check-ignore -v <path>` when a
  file refuses to add.
- **`actionlint` and `zizmor`** should pass on the workflow, and `shellcheck` plus
  `shfmt -i 2 -d` on the scripts. They pass as shipped; a repo with stricter settings may
  want a look. Bare `actionlint` only discovers `.github/workflows/`, so lint the template
  by explicit path while it still lives outside that directory.
- **What the scripts need at runtime:** `bash`, `git`, and the usual POSIX tools —
  `find`, `sed`, `awk`, `grep`, `sort`, `uniq`, `diff`, `mktemp`, `date`. No `perl`, no
  Python, no GNU-only flags, and no bash-4 constructs, so the macOS system bash runs them.
- **Branch protection.** Until the `records` job is a required status check the gate is
  advisory: a PR may edit the checker, and a PR that deletes the workflow stops the job
  rather than failing it. Say so when reporting the adoption rather than implying the gate
  is airtight.

## What the gate does and does not do

It fails a PR on a malformed or empty record, an unreadable `## Status`, a resolution or
supersession banner that names nothing, is malformed, or is dated in the future, an ADR
whose H1 number does not match its filename, a missing `target:` line, a missing or bad
`review-by:` on an open record, a duplicate number the change introduced, a stray file in
the directory, and
— the rules that matter — a record that stopped being a record: deleted, moved into a
subdirectory, replaced by a symlink, removed from git while left on disk, or **gutted in
place**. That last one is the cheapest erasure and the one every other rule misses, since
they all assume the file moves.

It also fails when the base ref held records for an enabled profile and the tree now
enumerates none, and when one of the gate's own files — the engine, the suite, either
profile, or a workflow that invoked it — is deleted or symlinked away, or renamed without
declaring the rename in `GATE_PREDECESSORS` (`E-GATE-EMPTY-SET`). The one exception prints
rather than fails: `I-GATE-BOOTSTRAP` is informational, not an error, and appears on the
PR that installs the gate in a repo that never had one.

The rules an adopter is most likely to hit first, and none are bugs: `RECORD_PROFILES`
empty or unset is `E-PROFILE-NONE`; a name in it with no matching file under `profiles/`
is `E-PROFILE-UNKNOWN`; an enabled profile whose record directory exists at neither the
base ref nor the tree is `E-PROFILE-DIR-MISSING` — see the note above about the first
record the adopting change must add.

Its degraded paths are fatal by design: a base ref that is not a commit, an unreadable
tree, the wrong working directory, or an empty `BASE_SHA` in CI all fail rather than
reporting a clean run over nothing. A checker that silently passes is worse than none.

It cannot see **substance**: whether a decision was right, whether a deferral was
correctly deferred, whether a stated boundary is the one the change holds, or whether a
banner's named artifact actually resolved or superseded anything. A record of well-formed
sections of nonsense passes. The gate makes a decision or a deferral auditable and hard to
erase; a human reading the record in the diff is what makes it honest.

`check-records-test.sh` is the checker's regression suite — 133 cases (132 as root, where
the unreadable-directory case skips because root ignores the permission bit it depends on).
It covers the migrator too, since the migrator's self-check is the checker's own allowance —
which is why the migrator ships with the gate rather than being run only from this skill.
Every rule has a case asserting both an exit status and which rule fired, and its
acceptance criterion is a mutation sweep — neutralising any single rule must turn the suite
red. Run it before trusting a change to the checker, and keep the six files together: the
suite, the migrator, both profiles, and the workflow are all part of the gate, and the gate
protects all but the migrator, whose absence the suite reports instead.
