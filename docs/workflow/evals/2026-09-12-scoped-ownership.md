# Scoped ownership decision evaluation — issue #361

The two synthetic Python planning cases were run once per instruction variant in fresh,
ephemeral, read-only Codex CLI 0.154.0 contexts using `gpt-5.6-sol` at medium reasoning.
The case packets were identical across variants. Baseline excerpts came from
`283926bf8e68459ac7246c2f2cc585ece21fd158`; revised excerpts came from
`9088425104b6a0e3437b3009da3d52893fcd9be5`. Each packet supplied the relevant
`quest`, `spellcraft`, and `oathbind` sections plus a complete synthetic fact pattern.
The budget was fixed at four runs, with no retries. All four runs completed; elapsed time
was roughly 19–32 seconds each. Raw prompts and outputs were retained privately for
inspection during this run, outside the repository.

| Case | Baseline decision | Revised decision | Observed result |
|---|---|---|---|
| OW-1 duplicated eligibility policy | Created one internal policy owner; kept both public `eligible(user)` adapters; removed duplicated internal rules; kept `invoice.py` on the protected renewal API. | Made the same owner and adapter choice; explicitly mapped each removal and test to criteria. | Both accounted for the invoice caller, justified the retained wrappers, and rejected removing the accepted public signature. No omitted migration or unjustified leftover was observed. |
| OW-2 clean notification extension | Extended `notify.py` and kept both callers on its existing internal interface, with no new layer or move. | Made the same extension choice and named why relocation would add surface. | Neither introduced a gratuitous move. Both described focused and caller-level validation. |

OW-1's protected-signature probe was observable: both variants rejected removal of the
public aliases as conflicting with the accepted decision. The revised run explicitly called
for a new scope decision before such a removal. The baseline also preserved the contract,
so this case does not demonstrate an improvement over it.

Both OW-2 outputs assumed an existing summary-delivery flow, although the packet only said
the new preference defers routine messages to the next summary. That is an unverified
assumption in these proposed plans. The packet did not supply actual source or tests, and
the runs produced designs rather than executing migrations; plan completeness was judged
from their stated file maps and validation, not a working implementation. The experiment
uses excerpts rather than the full installed skill set, one model/harness, and two Python
cases. It supports only these observed decisions, makes no numerical quality claim, and
does not substitute for issue #364's language-family evaluation.
