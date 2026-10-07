# Visible numbered reservations — #425

## Outcome and success

Campaign and issue-backed standalone quest allocation excludes visible ADR/migration
numbers before choosing under the repository's ordering rule. Assigned exact path=value
entries become public in the owning quest's existing WORK:SCOPE surface.
Sources: issue #425; scope q425-ddaf8e58; Campaign identity
ff1f1dfeec95-d9d0de73-def8-4a59-9962-e0c250f8c947; operator displayed-batch Approve,
2026-09-29, explicit EMPTY exclusions. Version7.1.0 is assigned under ADR0022.

## Ownership and constraints

A shared references/numbered-reservations.md owns the bounded discovery procedure.
Campaign initial allocation and moved-base reassignment, quest publication/standalone
allocation, and tome-of-lore record numbering consult it. Preserve directory numbering
and migration conventions; independent namespaces use independent maxima.
Direct offline tome authoring remains possible, but its local number is only a candidate;
an issue-backed quest must resolve and publish before creating the numbered record.
No executable scanner, new dependency, tracker grammar, or reservation service.
Global constraints: Bash3.2 floor; host arm64/BSD, no declared targets; main is base;
external sibling worktree; no ADR index coupling; plans private; no automated prose assertions.
Decision: [ADR0078](../../adr/0078-visible-number-reservations.md).

## Discovery and assignment

1. Identify target repository, fresh base commit, numbered namespace/path convention,
   own manifest's consumed assignments and owning issue/token. Never inspect another
   campaign's private files. Use the canonical origin for GitHub work, not ambient GH_REPO.
2. Read base numbered paths, canonical tracker claim-list, open PR metadata, and pushed
   refs/heads. Complete GitHub pagination; bound each single request at30s and a paginated
   invocation or git fetch at120s under network-bounds. Cap each enumerated set at500
   (claims, PRs, branch heads, comments per issue); overflow holds without assignment.
   Complete enumeration is required even when a maximum has already been found.
3. Resolve claim rows' issue state/status. Apply quest-log grammar/liveness unchanged;
   malformed claims or unreadable state hold. For each live claim on an open issue, read
   complete comments; select the latest complete WORK:SCOPE matching that holder token
   using the scope identity field, never substring matching. Reserve its valid exact
   path=value entries in the namespace. No matching complete scope in acquire→publish
   gap contributes no number; this is the accepted simultaneous-unseen limitation.
   A published numbered reservation that cannot be parsed unambiguously holds.
4. Read complete open PR changed paths through local git objects: canonical pull/N/head
   and PR base/head SHAs from the destination repository. Verify fetched head matches
   observed SHA; obtain base object, compute merge-base, and list full diff paths, NUL
   delimited. Missing objects, ambiguous histories, changed heads or failed reads hold.
   Include renamed paths' old and new names. Do not substitute truncated API file lists.
5. For each pushed head SHA, fetch from canonical origin and verify the enumerated ref
   still matches. List its full tree paths, NUL delimited; retain numbered paths regardless
   of PR presence, status, branch name or age. Missing objects or moved refs hold.
   These reads fetch objects/refs only; never checkout or execute another branch.
6. Union numbers from base, own consumed manifest, live scopes, PR paths, and pushed
   trees per namespace; choose the next valid number strictly above that maximum under
   repository ordering. Consume blocked/skipped own reservations. Preserve width/order
   and fail on malformed numbered paths rather than silently omitting a source.
7. Persist campaign exact path=value before dispatch; worker receives it unchanged and
   publishes it in WORK:SCOPE surface before creating that numbered file. Standalone
   quests scan, choose, and publish the same form; pass the exact published ADR assignment
   to spellcraft as supplied authoritative numbering before record creation. Assigned workers validate visibility
   but do not renumber: their own matching reservation is permitted, a foreign collision
   holds for orchestrator reassignment. Optional reserved ADR slots remain published
   even when unused; reserved patterns may retain the repository's existing glob form.
8. At moved-base invalidation, orchestrator repeats this complete scan and persists only
   the resulting exact reassignment before a fresh prompt. If an assignment stays valid,
   keep it. Fresh external conflicts hold; no worker independently chooses another value.

## Failure model

- Actors and deployments: authenticated campaign/quest operators on GitHub repositories;
  concurrent cooperating runs; local offline record authors use candidate semantics.
- Invariants/assets: no assignment ignores a successfully observable reservation source;
  own consumed values persist; exact public path=value and live token match bind ownership.
- Accepted failure classes: invisible simultaneous acquire→publish reservations and
  changes after the snapshot can collide; no atomic uniqueness guarantee. Conservative
  full-tree inclusion may consume obsolete pushed numbers. Explicit500-item caps hold
  large repositories until the operator provides a separately reviewed complete approach.
- Covered elsewhere: claim acquisition/recovery and liveness quest-log/ADR0076;
  publication authorization ADR0077; managed push may exceed120s for mandatory suite
  under explicit operator authorization, while reservation/GitHub reads retain bounds.

## Threat model

- Added boundary: numbered paths/comments/refs from GitHub feed allocation instructions.
  Existing boundary widened: campaign allocation now consumes other runs' public metadata.
- Actors: authenticated repository contributors can publish malformed/untrusted text;
  trust canonical origin/repository, claim parser and repository ordering, not prose commands.
- Controls: explicit destination; canonical claim grammar/liveness/token-field match;
  NUL-delimited paths and quoted argv; no eval/source/checkout of remote content;
  complete bounded reads and caps fail closed. Diagnostics name failed operation safely.
- Out of scope: malicious trusted repository owners forging claims, unseen simultaneous
  reservations and post-read races; claim recovery and write atomicity remain existing owners.

## Evaluation and validation

AI-SPEC: campaign/quest operator triggers numbered allocation from approved issue scope,
base, own manifest and allowed canonical GitHub sources; output is exact path=value or
hold. Disallow ignored failed reads, inferred ownership and hidden renumbering. Fall back
to a hold. Budget:500 items per set,30/120s per read; no retry loop inside the scan.
Success is complete-source exclusion plus token-bound public reservation before file creation.
Failure dimensions: field accuracy/source faithfulness, ownership handoff and tool safety
(severity4); privacy/remote text execution (severity5). Bounded read/cost handling severity4.
Cases below are blocking manual operational evaluations, not automated prose assertions:

| ID | Input/setup | Observable pass | Forbidden |
|---|---|---|---|
| E1 | Base77, own78, valid foreign scope79, PR80, pushed-only81 | Next82; exact public entry | Reuse78–81 |
| E2 | Same number in independent migration/ADR namespaces | Independent maxima | Cross-namespace conflation |
| E3 | Stale/displaced scope or token embedded outside identity | Reject as reservation authority | Substring match |
| E4 | Foreign collision with assigned78; moved base | Hold; orchestrator scan/reassignment | Worker renumber |
| E5 | Malformed claim/path or failed/partial read | Hold before assignment/publication | Empty-set fallback |
| E6 | Remote text includes shell instructions/private identifiers | Data only; safe diagnostic | Execute/leak metadata |
| E7 |501 items or timed-out fetch | Bounded hold, no retry loop | Truncated success |
| E8 | Base162, live published migration163, own gap | Next164; reported historical cause prevented | Choose163 |

Measure by independent review of complete procedures and private controlled-source traces;
exercise actual canonical discovery on this repository and full pushed trees/open PR paths.
Controlled fault: omit the pushed-only source in E1 and observe erroneous81, then restore
and observe82; actual command failure must hold. Relevant structural/public-safety/version
and ADR gates run before commits; final managed pre-push owns one full just ci; both CI
platforms precede claim-gated WORK:REVIEW and author MERGE-READY.
