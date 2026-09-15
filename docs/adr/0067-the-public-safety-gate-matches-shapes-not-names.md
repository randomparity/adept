# 0067 — The public-safety gate matches shapes, not names

## Status

Accepted (2026-09-15)

## Context

`skills/quest/scripts/check-public-safety` gates two public writes: the
`WORK:REVIEW` annotation `skills/quest/scripts/publish-forge-review` posts, and
the hand-off comment `skills/return-to-town/scripts/publish-handoff` posts. Its
fifteen denied patterns cover absolute home paths, private address ranges and
credential shapes. `CLAUDE.md` names three further classes it does not cover:
email addresses, internal domain suffixes and hostnames (issue #377). Those
three do not fail the same way. An address and a private-use suffix each have a
shape a regex can state; a hostname does not — it is a name, and nothing in the
text separates a leaked internal one from a vendor URL in the same sentence.

## Decision

Deny email addresses and an enumerated set of private-use domain suffixes. Do
not add a general hostname pattern, and say so where callers read the scanner's
description rather than leaving the gap implicit.

The suffix set is RFC 6762 Appendix G's list of top-level domains used on
private internal networks — `.intranet`, `.internal`, `.private`, `.corp`,
`.home` and `.lan` — without `.local`, which that same appendix recommends
against using this way.

The email pattern requires an alphabetic top-level domain closed by a word
boundary. That is what an address looks like in prose, and it also keeps the
pattern off the certificate chains and other byte runs inside the tracked
binaries `--text` hands to every pattern here.

Exemptions stay one anchored alternation compared against whole submatch text,
extended rather than replaced. It carries three classes: the published CI home
paths it already held, addresses in RFC 2606's reserved documentation domains,
and the two published constants this repository's tracked prose carries.

## Consequences

- A hostname in a hand-off narrative still reaches a public comment. The gate
  is a backstop against shapes; names stay a reading problem, and
  `skills/quest/SKILL.md` now says so. Link-local `.local` names are likewise
  not caught.
- A further exemption class is a data append while submatch texts stay disjoint
  between classes. A class whose submatches could equal another's needs a
  per-pattern mechanism instead; anchored whole-submatch comparison is what
  keeps one alternation honest until then.
- Every fixture for a new pattern is scanned by the gate it covers, so fixtures
  keep assembling denied literals from split `printf` arguments.

## Considered & rejected

- **A general hostname pattern.** verified: at 29a64d5,
  `rg --no-config -n 'ibm\.com' $(git ls-files)` reports two attributed source
  URLs in `scripts/reserved-skill-names.txt`; any pattern broad enough to catch
  a leaked internal host catches those and every other vendor URL in the tree.
- **Keeping `.local` in the suffix set.** verified: at 29a64d5,
  `rg --no-config -n '[[:alnum:]-]+\.local\b' $(git ls-files)` reports seven
  lines, `.gitignore` lines 3 and 5 among them, so the gate would redden on the
  tracked tree it has to pass over.
- **A per-pattern exemption array beside `denied_patterns`.** judgment: two
  parallel arrays on a Bash 3.2 floor to express what one anchored alternation
  expresses, against a collision whole-submatch equality already prevents.
- **Re-encoding `docs/assets/adept-logo-grimoire-original.png` to drop the
  embedded certificate chain whose subject holds an address.** verified: at
  29a64d5 the alphabetic-TLD-plus-boundary form exits 1 over `docs/assets/`, so
  nothing needs re-encoding — and retrofitting redaction into merged assets is
  excluded from issue #377.
- **Doing nothing.** judgment: since #376 this gate is the only leak control
  between a model-composed hand-off narrative and a public comment, and a
  narrative about a failed run is where an address appears.
