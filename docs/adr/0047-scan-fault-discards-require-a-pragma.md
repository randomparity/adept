# 0047 — Scan-fault discards require an inline pragma

## Status

Accepted (2026-08-28)

## Context

[ADR 0005](0005-scan-faults-are-reported-not-collapsed.md) records the rule that a scan
whose result feeds a verdict captures its own exit status and branches three ways — matched,
did not match, could not run — and never lets the third fall into the second. Its own
Consequences say plainly that nothing enforces the record. The defect class has now been
found four times — #25 (`if ! grep`), #55 (`cmd || true` and siblings), #63 (pipelines),
#64 (`git cat-file blob` fail-open) — each time by a human reading the scripts, and each
time after the previous fix had already landed. Issue #66 asks whether a guard should
enforce the rule, and in which shape.

Two shapes avoid the central-allowlist failure that sank the naive scanner 0005's
Considered & rejected already dismisses:

- **Diff-scoped** — check only the lines a PR adds, so pre-existing deliberate discards are
  never in view and no allowlist is needed. Cheaper to keep honest, but it does not cover
  code that already exists.
- **Inline pragma** — require `# scan-fault: deliberate — <reason>` on the same line as any
  discarding idiom in the gate scripts, and fail the gate on an undocumented one. The
  allowlist lives beside the code it exempts and cannot drift away from it.

The issue's sequencing note — "the set of legitimate exceptions is actually known" once
#55, #63 and #64 have landed — is what makes the inline-pragma shape decidable. The
exceptions are now known. Reading the gate scripts after #55, #63, #64, #89 and #90, every
remaining status discard is deliberate and falls into one of five classes:

- in-memory pipes over shell variables (`printf '%s' "$var" | grep …`), exempt by ADR 0032
  decision 4 — the command reads no external bytes, so there is no could-not-run case to
  lose;
- the `|| :` discard form, which ADR 0032 decision 2 sanctions *with an inline comment
  naming the record*;
- cleanup and probe discards (`rm -f … || :`, `command -v … || true`), where absence or a
  failed best-effort action is ordinary;
- documented residuals — `run_profile "$name" || true` so one profile's failure cannot hide
  another profile's findings, `dir_in_ref`'s fail-open base-ref guards, and the
  process-substitution profile listing whose status has no reporting channel (ADR 0005's
  "guarded at its input or moved out");
- path-pattern and in-memory predicates (`is_two_space`, `cleared_dependency_candidate`).

One empirical fact constrains the match set. `if !` appears roughly 140 times across the
shell-source inventory, and every site reports its fault in the then-branch — the #25 sweep
converted the silent ones, and the survivors call `err`, `fail`, `report`, `die`, or exit
non-zero. A structural check cannot separate a reporting `if !` from a collapsing one
without parsing the then-branch — nested blocks, heredocs, `case` — and matching the shape
syntactically would require a pragma on every reporting site, noise that teaches readers to
skim pragmas. The same reading excludes `|| return N>0` and `|| exit N>0`: failure
propagation is loud (fail-closed), not the silent pass the rule exists to prevent.

## Decision

**1. A guard enforces the rule, in the inline-pragma shape.** A new structural check over
the repository's gate scripts requires every status-discard idiom to carry
`# scan-fault: deliberate — <reason>` on the same line, and fails on an undocumented one.
The check is structural — it matches discard operators and a pragma token, never prose — so
CLAUDE.md anatomy rule 4 permits it.

**2. The match set.** A line in a scanned file is a finding when it contains one of:

- `|| true` or `|| :` on a command that is not a test and not a pure builtin;
- `|| continue`, `&& continue`, `|| return 0`, `&& return 0`, `|| exit 0`, `&& exit 0` on
  such a command;
- `[ -n "$(cmd)" ]` or `[ -z "$(cmd)" ]` — a command substitution whose status is discarded
  inside a test.

Excluded by construction: `[ … ]`, `[[ … ]]`, `(( … ))` and `test` commands (a test's
status is the verdict, not a scan); pure builtins with no pipeline (`printf`, `read`, `:`,
`unset`, `cd`, …); comment lines; heredoc bodies. `|| status=$?` — the required capture form
ADR 0005's Consequences prescribe — is not one of the matched operators and never fires.

**3. The pragma.** `scan-fault: deliberate — <reason>`: the token, an em dash, and a
non-empty reason. The guard checks the token and the non-empty reason; it never reads the
reason's content, which would be a prose assertion.

**4. The scan scope.** The guard scans the same shell-source inventory the other gates use
(`scripts/list-shell-sources.sh --all`), minus test scripts — paths under `tests/fixtures/`
and names ending `-test.sh`. Test scripts are test mechanics, not gates: their fixture stubs
deliberately contain the idioms, and a collapse there fails the test loudly rather than
passing a verdict.

**5. Placement.** The guard runs in `just commit-check`, and therefore in `just verify`,
the pre-push hook, and CI. It is a line scan of roughly two dozen files — cheap enough for
every commit.

**6. The guard follows the rule it enforces.** It is itself a scan whose result feeds a
verdict: it captures its own exit status, reports its own faults (an unreadable file, a
failed source listing) as exit 2, and never collapses them into a pass.

## Consequences

- **The sweep.** Every deliberate discard in the gate scripts gains an inline pragma naming
  its reason — roughly fifty annotations across `check-records.sh`, `migrate-records.sh`,
  the `profiles/` scripts and their byte-identical twins under `skills/tome-of-lore/assets/`
  (the `just records` mirror), plus `list-shell-sources.sh`, `github.sh`,
  `cleared-dependencies.sh`, `detect-host-architecture`, and `create-verified-issue.sh`.
  The ADR 0032 decision 2 comment requirement is subsumed: the pragma is the comment, and
  its reason cites the record.
- **The initial run found no new fail-open instances in the gate scripts.** The #55/#63/#64
  sweeps held; every flagged site is a deliberate exception with a documented reason. The
  fail-closed instances in test fixtures (a `rg -c … || true` whose fault fails the
  assertion loudly) are outside the scan scope by decision 4.
- **Residuals, recorded.** The `if !` negation shape is not matched: every sampled site
  across the inventory reports its fault, and separating reporting from collapsing requires
  then-branch parsing the repo's culture rejects; a new `if ! scan; then <silent negative>; fi`
  is a review matter, not a gate matter. Bare pipelines without a trailing discard are not matched: ADR
  0032 lifted every reading stage, and a new one is the same review matter. `|| return N>0`
  and `|| exit N>0` are not matched: propagation is loud. A heredoc tracker that misreads
  `<<` inside a string would skip subsequent lines (fail-open); the current inventory has no
  such line, and the tracker requires a word character after the operator to open.
- **The gate is honest by construction.** A new unannotated discard in a gate script reds
  the commit that introduces it. The pragma forces the author to look at the line and state
  why the discard is deliberate, and the reason is visible to every reviewer.
- Nothing enforces this record's own exclusions — a future author could add an `if !` with a
  silent negative and the guard would not catch it. That is the recorded residual, not an
  oversight.

## Considered & rejected

**Diff-scoped guard.** verified: the four recurrences were all pre-existing code found by
reading, so a guard that checks only added lines would have caught none of them; it needs a
base ref that a local `just verify` does not have (a local skip is a fail-open hole, and the
version-check precedent that "checks the first two rules only and says so" is a weaker gate
locally); and the issue's sequencing note — the exceptions must be known before the sweep —
only matters for a whole-file shape.

**No guard.** judgment: the four recurrences, each found by a human after the previous fix
landed, are the strongest available evidence the class recurs; the issue asks for the
decision; and a structural check is permitted by anatomy rule 4. The residual cost of a
false red is bounded by the guard's own suite.

**Central allowlist.** verified: ADR 0005 rejected it on the ground that `check-records.sh`
discards a status deliberately — one so a profile's failure cannot hide another profile's
findings — and an allowlist that drifts is how a gate starts passing over the thing it
checks. The inline pragma is that allowlist relocated beside the code it exempts.

**Match the `if !` shape.** verified: 142 sites across the inventory, each reporting its
fault in the then-branch; a structural check cannot distinguish reporting from collapsing
without parsing then-branches, and matching syntactically would require a pragma on every
reporting site — noise that teaches readers to skim pragmas, which is the failure mode of
the allowlist this shape exists to avoid.

**Match `|| return N>0` / `|| exit N>0`.** judgment: failure propagation is loud
(fail-closed), not the silent-pass collapse the rule exists to prevent; the fail-closed
misattribution class is #64's, already fixed and owned by the `E-*-SCAN` codes.

**Scan test scripts too.** judgment: fixture stubs deliberately contain the idioms as
code-under-test, and a collapse there fails the test loudly; the issue's scope is "the gate
scripts", and a second inventory that excludes them would drift from the first.

**Parse then-branches to catch silent-negative `if !`.** judgment: a mini shell-block parser
(heredocs, nested ifs, `case`) is exactly the complexity this repository's history rejects
— the 1,337-line installer and the 563-line prose gate were both retired for it — and its
false-positive surface on legitimate probe guards (`if ! command -v x; then return 0; fi`)
would be worse than the residual it closes.