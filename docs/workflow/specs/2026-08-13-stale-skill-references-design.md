# Stale skill reference repair

## Scope authority

- Issue: [#39](https://github.com/randomparity/adept/issues/39)
- Scope token: `scope-39-20260813-a1`
- Outcome: every issue-listed file, heading, and step reference resolves against the
  current repository, and `bards-tale` can ground tuning proposals without predecessor
  artifacts.
- Exclusions: compatibility shims, predecessor-layout restoration, unrelated prose cleanup,
  and new workflow behavior beyond making the cited contracts resolvable.

## Design

Repair the references in place. Repository-instruction discovery will name both supported
instruction filenames, `AGENTS.md` and `CLAUDE.md`. Cross-skill references will use installed
skill invocations or current headings rather than predecessor filenames. Generic guidance
that runs against another repository will describe the artifact by role when no single path
can exist in every target repository.

The `warding` dependency sweep will discover version pins from the target repository's actual
provisioning and workflow files. When `osv-scanner` is absent, it will consult the scanner's
current official installation guidance and report an actionable install command instead of
claiming this repository owns an installer.

The change will not add a prose-reference gate. A literal Markdown-path resolver would cover
only part of the reported family: headings and numbered step references are semantic prose,
while backtick-quoted Markdown names can also be examples or target-repository paths. Expanding
the gate to cover those cases would violate the repository rule that automation does not assert
on prose. Existing shape checks remain responsible for actual Markdown links and skill layout.

## Components and flow

1. `attunement` and `spellcraft` discover applicable repository instructions and point their
   internal step references at the current numbered sections.
2. `bards-tale`, `restock`, and `warding` identify current evidence sources without requiring
   predecessor artifacts.
3. The `forge` dispatch templates name the existing `Choosing a model` section.
4. `trial-loop` names its existing `CHARTER` dispatch block.

These are instruction-only edits. There is no runtime state, persistence, migration, or new API.
`warding` already requires current-version research during a sweep; the repair makes the official
OSV-Scanner installation documentation the authoritative source for install guidance. If that
source cannot be read or does not provide an applicable command, the sweep reports the audit as
skipped and names the missing guidance; it must not invent a command or report the audit clean.
A missing target artifact continues to fail closed where the original workflow already required
verification; the repair changes which valid evidence can satisfy the rule.

## Reference repair matrix

| File | Stale reference | Current target |
|---|---|---|
| `skills/attunement/SKILL.md` | `AGENTS.md`, `AGENTS.md` | `AGENTS.md`, `CLAUDE.md` |
| `skills/attunement/SKILL.md` | coupling branch in `Step 6` | parallel-run context in step 7 |
| `skills/spellcraft/SKILL.md` | `AGENTS.md` / `AGENTS.md` | `AGENTS.md` / `CLAUDE.md` |
| `skills/spellcraft/SKILL.md` | assigned ADR number in attunement step 6 | attunement step 7 |
| `skills/spellcraft/SKILL.md` | coupling verdict in attunement step 4 | attunement step 5 |
| `skills/bards-tale/SKILL.md` | `shared/commands/*.md` or `AGENTS.md` | verified governing workflow or repository instruction source |
| `skills/restock/SKILL.md` | `return-to-town.md` and both `AGENTS.md` files | `$return-to-town` and applicable repository instructions |
| `skills/warding/SKILL.md` | `install-tools.sh` inventory/install command | actual provisioning/workflow pins and current official OSV-Scanner guidance |
| `skills/forge/implementer-prompt.md` | `Model Selection` | `Choosing a model` |
| `skills/forge/task-reviewer-prompt.md` | `Model Selection` | `Choosing a model` |
| `skills/trial-loop/SKILL.md` | `review-dispatch` block | `CHARTER` block |

The focused verification command is:

```bash
rg -n --no-config 'shared/commands|install-tools\.sh|Model Selection|review-dispatch|AGENTS\.md.*,.*AGENTS\.md|AGENTS\.md.*/.*AGENTS\.md|attunement.*step (4|6)' \
  skills/attunement/SKILL.md skills/spellcraft/SKILL.md skills/bards-tale/SKILL.md \
  skills/restock/SKILL.md skills/warding/SKILL.md skills/forge/implementer-prompt.md \
  skills/forge/task-reviewer-prompt.md skills/trial-loop/SKILL.md
```

Exit 1 with no output is the expected result. Any output is a blocking stale reference; exit
greater than 1 is a scan failure, not a pass. Review also follows each replacement target in the
matrix because the semantic targets cannot all be validated by matching prose.

## Acceptance criteria

- The duplicated `AGENTS.md` lists in `attunement` and `spellcraft` name `AGENTS.md` and
  `CLAUDE.md` once each.
- `attunement`'s coupling cross-reference points to its parallel-run section.
- Every `spellcraft` cross-reference to attunement's ADR assignment and coupling sections uses
  their current step numbers.
- `bards-tale` accepts a verified current workflow source or applicable repository instruction
  as proposal grounding, without requiring `shared/commands/` or a repository-local
  `AGENTS.md`.
- `restock` cites the installed `$return-to-town` workflow and applicable repository
  instructions for merge policy.
- `warding` discovers tool pins from real provisioning/workflow files and sources an absent
  `osv-scanner` install command from current official guidance.
- Both `forge` templates point to `Choosing a model`.
- `trial-loop` calls the labeled trailing block `CHARTER`.
- A repository-wide search finds none of the issue-listed stale strings in their affected
  files, and `just verify` passes.

## AI surface and evaluation

AI-SPEC: The users are operators invoking the affected workflow skills. The trigger is an
invocation that needs repository instructions, grounding evidence, dependency-tool discovery,
model selection, or review dispatch. Inputs are the target repository and the workflow's current
phase; outputs are instructions that resolve to artifacts or headings available in that context.
Allowed sources are the installed skills, applicable repository instruction files, target
repository provisioning/workflow files, and current official tool documentation. The skills must
not invent predecessor paths or treat an unverified artifact as evidence. If evidence or a tool
is absent, they fail closed or report the skip actionably as already required. The change adds no
latency or cost budget beyond an existing lookup at sweep time. Success is the acceptance search,
skill-shape validation, adversarial instruction review, and the full guardrail suite passing.

| Failure mode | Severity | Evidence |
|---|---:|---|
| A stale path still blocks or misdirects a workflow | 4 | Exact affected-file search and review |
| A replacement names an artifact unavailable in the target context | 4 | Context-specific review of each replacement |
| Generic wording weakens an existing fail-closed evidence rule | 4 | Review `bards-tale` and `warding` semantics |
| A new prose gate rejects valid examples or target paths | 4 | No new prose gate is introduced |
| Changes escape the issue-listed surface | 3 | Diff review against the frozen scope |

Evaluation is static instruction-contract review, not execution of the skills against synthetic
repositories. The reference matrix is the fixture, the implementation diff is the changed state,
and the focused search above is the machine oracle for stale literals. Semantic cases use an
independent `$gauntlet` branch review: the reviewer checks the stated predicate in the changed
instruction, cites its exact lines and the current target it followed, and reports an unsupported
or unresolved target as blocking. An invocation harness is outside this repair's scope and is not
claimed as evidence.

Evaluation cases:

- `REF-01` happy path: inspect the `attunement` instruction-file list after the edit. Pass: it
  contains `AGENTS.md` and `CLAUDE.md` once each; the focused search emits nothing. Gate: block.
- `REF-02` precedence predicate: the edited instruction still delegates instruction precedence to
  the agent's native applicable-instruction rules and adds no ordering of its own. Pass: the
  independent reviewer cites that unchanged delegation. Gate: block.
- `REF-03` fail-closed predicate: the edited `bards-tale` grounding rule still omits any proposal
  without a verified governing workflow or repository instruction source. Pass: the independent
  reviewer cites both the admissible-source rule and the omission rule. Gate: block.
- `REF-04` discovery predicate: the edited `warding` rule discovers pins from actual target
  provisioning/workflow files and makes no claim about a repository-owned installer. Pass: the
  reviewer cites the discovery rule and the focused search emits nothing. Gate: block.
- `REF-05` degraded-guidance predicate: the edited instruction requires a skipped result when
  official guidance is inaccessible or inapplicable, names the missing guidance, forbids an
  invented command, and forbids a clean result. Pass: the independent reviewer cites all four
  traits. Gate: warn.
- `REF-06` bounded behavior: the repair adds no agent loop or extra dispatch; existing workflow
  limits remain unchanged. Pass: `git diff --name-only main...HEAD` contains only the matrix files
  and required design records, and independent review finds no new dispatch. Gate: block.
- `REF-07` regression fixture: run the focused search above. Pass: exit 1 with no output; exit 0
  identifies a blocker and exit greater than 1 is a failed scan. Gate: block.

The focused search is code-based. Semantic cases require a context-isolated adversarial reviewer
whose evidence is checked by the controller against the cited lines and targets; the author does
not grade the same pass, and an unsupported citation fails the review. No model grades its own
output.

## Verification and rollback

Run focused searches for every reported stale reference, then `just verify`. Since the change is
instruction-only and creates no external state, `git revert` fully rolls it back.

## Durable execution context

- Branch: `feat/stale-skill-references-39`
- Base branch: `main`
- Guardrails: `just verify` locally; CI invokes the same chain through `just ci` on Ubuntu and
  macOS.
- Host architecture: `arm64`
- Target architectures: none declared
- Architecture relationship: `no-target-declared`
- ADR index coupling: not coupled; the directory listing is the index and the gate warns if a
  hand-maintained table appears.
