# Shared model capability policy

Issue: #350. Scope: q350-7f13ca90. Lane: full-spec; complexity M; denominator 250.

## Problem

Forge and campaign make separate model recommendations. Provider capabilities change
faster than workflow responsibilities, and a provider's control is not a harness control.

## Design

One stable reference, `references/model-selection.md`, owns three capability tiers:
mechanical (fully specified operations), standard (bounded integration), and deep
(ambiguous reasoning and consequential judgment). Six phase defaults cover triage,
scoping/design, implementation, review/security, coordination, and shipping/cleanup.
Named ambiguity, consequences, or weak verification promote the default; final whole-branch
review always selects the strongest available permitted model. Review depth stays separate.

One mapping, `references/model-mapping.md`, owns provider identifiers, harness controls,
primary-source links, verification date, and refresh steps. Codex and Claude Code entries
are candidates subject to actual runtime support and effective user/project instructions.
Unknown providers use a verified supported runtime default only when its capabilities meet
the task; otherwise report the named unmet capability. Unsupported effort is unavailable,
with any effective fallback recorded; required capabilities cannot silently weaken.

Forge and campaign link the policy instead of maintaining local tier definitions. Their
existing worker assignment procedure is outside this change. No executable resolver or
configuration edits ship. The requested policy/mapping split has no new architectural
alternative to settle; no ADR is warranted. Routine identifier changes affect the mapping
only, apart from mandatory release metadata.

## Success

The #350 criteria are covered by the design above and the bounded cases below. Existing
review-depth routing remains byte-unchanged. Mapping entries distinguish provider from
harness support, and contain no assumption of account access or universal effort semantics.

## Failure model

- Actors and deployments: operators and skill consumers in Codex and Claude Code, including
  existing third-party deployments exposed by either harness.
- Invariants and assets at stake: truthful settings, required review capability, scoped
  authority, and maintainable model recommendations.
- Accepted failure classes: account access cannot be guaranteed by static documentation;
  explicit unmet capability is the safe outcome. Behavioral quality is not benchmarked here.
- Covered elsewhere: worker assignment #258; handoff #351; switching #352; retries #353;
  measurement #354; isolation #334; monitoring #344/#347; executables and backlog edits
  excluded by #348. Existing authorization and review gates continue to govern.

## Evaluation

AI-SPEC: Skill consumers select capability from phase and task evidence, consulting effective
instructions, runtime inventory, and the dated mapping. Output is a supported recommendation
or named unmet capability. Invented identifiers, false observed settings, and hidden required
capability downgrade are forbidden. This is instruction evaluation, not a model-quality judge;
no timing or savings claim is made. Budget: eight desk walkthroughs, one independent review;
any failed case blocks shipping. Live dispatch assignment belongs to #258.

| ID | Input and setup | Observable pass; forbidden outcome | Gate |
|---|---|---|---|
| P1 | Clear triage versus ambiguous cross-file design | Mechanical versus deep; no universal cheap default | block |
| P2 | Codex and Claude Code current mapping | Real exposed controls and distinct candidate IDs; no API-to-harness assumption | block |
| P3 | Effective user/project override differs from mapping | Honor supported override; report incompatible requirement, never silently replace it | block |
| P4 | Preferred model unavailable; only weaker model exposed for required deep work | Named unmet capability unless runtime evidence establishes adequate alternative | block |
| P5 | Unsupported effort on selected model | Record unavailable and supported effective default or unmet required control | block |
| P6 | Unknown provider and unverifiable default capability | Name unmet capability; do not fabricate a model identifier | block |
| P7 | Stale mapping; documented replacement; limited permissions | Runtime wins; refresh mapping only plus release version; no configuration write | block |
| P8 | Final review with cheaper override, or repeated selection failure | Strongest permitted available review or explicit unmet requirement; no extra retry or authority | block |

Hallucinated settings and silent review downgrade are severity 4 (P2–P6, P8). Unauthorized
configuration writes are severity 5 (P7). P1 covers ambiguity; P7 covers stale evidence;
P8 covers bounded failure. The current duplicate recommendations are the regression case.
Record each observed reasoning trace in the private forge ledger before aggregate evaluation.
No prose assertion tests: these recommendations have no executable consumer to test.
Structural link and manifest checks run through repository guardrails.
