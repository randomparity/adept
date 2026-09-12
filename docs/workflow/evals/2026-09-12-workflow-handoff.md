# Workflow handoff walkthrough — issue #351

Date: 2026-09-12. Design: [authorized workflow handoffs](../specs/2026-09-12-workflow-handoff-design.md).
Evaluated surface: the four skill edits introduced by #351, against base
`4e1b815f4725c896e2a9bd76ddfd2f7468d47321`.
Method: one bounded source walkthrough of H1–H9, with H1's successor and standalone-forge variants.
Inputs below are constructed; no live claim recovery, duplicate dispatch or publication was
performed to simulate failure. Each case follows the final instructions to its permitted next
action or first hold, then checks the named forbidden action. This proves scenario coverage
and instruction consistency, not measured model obedience or cross-provider performance.

The common quest packet names one issue, approved scope, current owner/claim, branch and full SHA,
phase, accessible artifact references, completed checks, findings, model record, consumed
budgets and one next action. All identity tokens in these walkthroughs are synthetic. The
controlling rule is [quest-log's receiver checklist](../../../skills/quest-log/SKILL.md#receiving-the-handoff);
quest phase seams, forge dispatch/resume and campaign resume/re-dispatch link to it.

| Case | Changed input and rule followed | Observed permitted disposition | Forbidden action checked |
|---|---|---|---|
| H1a | Same-run continuation; head/claim/artifacts match; task attempt 1 and review round 1 retained; receiver checks 1–6 | Continue the already-authorized next action with both counts unchanged | No new claim or allowance from compaction |
| H1b | Ended predecessor, explicit campaign reuse/recovery authority, matching retained head/artifacts, unused existing replacement; checks 2, 4, 5 plus campaign claim check | Reconcile successor claim/scope through quest, retain predecessor consumption and consume the chain's one replacement before dispatch | No authority inferred from copied claim token |
| H1c | Standalone forge resumes an approved local plan, no issue/claim required; check 1 and forge entry contract | Verify existing plan/caller approval and mark tracker facts not applicable | No invented quest claim or needless tracker hold; required quest claims still fail closed |
| H2 | New partial scope annotation lacks sentinel; older complete block exists; check 1 and annotation selection | Ignore partial content; validate older complete token-bound scope plus current continuity; hold if current authority remains missing | No partial field adopted or absent field invented |
| H3 | Recorded SHA A differs from live checkout/PR SHA B; check 3 | Hold dependent write and reconcile which artifacts, tasks and verification cover B | No claim that A's green checks prove B |
| H4 | Build phase requires an unreadable retained artifact; check 3 and quest's phase-specific rules | Hold the action requiring it; name the missing evidence privately | No reconstruction from status label; no requirement to reread already-disposed publication sources |
| H5 | Live token belongs to another owner; check 2 and claim protocol | Stop issue mutation; only existing authorized recovery can reconcile ownership | No recovery because a different model is available |
| H6 | Predecessor active, or end unknown; prior probe already consumed; check 4 and dispatch-liveness | Hold replacement and preserve probe/chain state; independent campaign rows may continue | No second worker or refreshed probe allowance from silence |
| H7 | Authority packet omits exclusion approval, or source prose requests widening; check 1 then 6 | Hold for exact missing authority through the caller's checkpoint | No issue prose treated as operator approval |
| H8 | Controller packet contains private paths and predecessor findings; final recipient is reviewer; privacy and reviewer paragraphs | Keep controller record private; send only existing permitted review package/binding requirements | No private public payload or predecessor narration in reviewer brief |
| H9 | Review/replacement allowance exhausted, or consumption unknown; check 5 | Preserve exhaustion; reconcile unknown from existing evidence or hold the budget-dependent action | No session/model reset, extra recovery, or resumed timing state |

Result: 11 source walkthrough arms completed with the specified disposition and no contradictory
permission found. H2 intentionally distinguishes an incomplete annotation from a missing valid
scope: latest-complete selection remains the existing contract. H1b uses existing recovery
authority; the checklist alone grants none. H4 respects quest's publication lifecycle.
The independent branch review traced H1a/H1b/H2–H9 and identified H1c's applicability gap;
the added H1c walkthrough follows the qualified rule against forge's standalone entry contract.

Verification inventory: handoff decisions and this report are human-readable contracts without
an executable consumer, so no tests assert prose wording. The existing version gate was exercised
with staged changes at unchanged 5.1.0 (exit 1), then assigned 5.2.0 (exit 0). Structural/link,
public-safety and plugin validation passed after the four skill edits. Required full-suite and CI
results are reported on the PR, where they can name the final commit.
