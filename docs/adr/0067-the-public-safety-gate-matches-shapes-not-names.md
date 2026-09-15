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

The suffix set is four of RFC 6762 Appendix G's six top-level domains used on
private internal networks: `.intranet`, `.internal`, `.corp` and `.lan`. Three
of the appendix's seven candidates are left out — `.home` and `.private`
because they are also the trailing component of ordinary dotted identifiers, and
`.local` because that appendix recommends against using it this way.

The suffix is matched only where the label in front of it starts a dotted token,
using the leading-boundary idiom the private-address patterns already use. That
is the difference between a host written into prose and a suffix that is one
segment of a longer dotted name.

The email pattern requires an alphabetic top-level domain closed by a word
boundary. That is what an address looks like in prose, and it also keeps the
pattern off the certificate chains and other byte runs inside the tracked
binaries `--text` hands to every pattern here.

Exemptions stay one anchored alternation compared against whole submatch text,
extended rather than replaced. It carries three classes: the published CI home
paths it already held, addresses in RFC 2606's reserved documentation domains,
and the published constants a repository's prose carries — the commit trailer,
and the fixed `git` user of the three public forges' SSH remote URLs.

## Consequences

- A hostname in a hand-off narrative still reaches a public comment. The gate
  is a backstop against shapes; names stay a reading problem, and
  `skills/quest/SKILL.md` now says so. Link-local `.local` names are likewise
  not caught.
- A dotted token that starts a clause and ends in a kept suffix is denied even
  when it is an identifier rather than a host — a bare module path ending in
  `.internal` is the shape, and this record cannot spell one, because the gate
  scans this record too. Both publishers discard the scanner's stdout, so the
  operator sees a refusal and a pattern string but not the token; the remedy is
  to reword, and an exemption entry only where the same token recurs.
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
- **Appendix G's full six, with `\b` on both ends.** verified: over prose about
  code, that form matches `user.home`, `path.home`, `java.home`, `maven.home`,
  `gradle.home`, `CATALINA.HOME`, `this.private`, `vpc.private` and
  `com.acme.internal` — no host among them. Dropping `.home` and `.private` and
  requiring a leading boundary leaves all nine green while a real host still
  matches. `scripts/check-public-safety-test.sh` carries both halves; it
  assembles the denied literal, which this record cannot.
- **Keeping `.local` in the suffix set.** verified: at 29a64d5,
  `rg --no-config -n '[[:alnum:]-]+\.local\b' $(git ls-files)` reports seven
  lines, `.gitignore` lines 3 and 5 among them. The ground is this repository's
  own `CLAUDE.local.md` and `settings.local.json` convention, not a general one.
- **A per-pattern exemption array beside `denied_patterns`.** judgment: two
  parallel arrays on a Bash 3.2 floor to hold what one anchored alternation
  holds. The single alternation is sound because the classes' submatch shapes
  are disjoint, not because it is narrower — narrowing a pattern is a pattern
  change, and this change makes one.
- **Re-encoding `docs/assets/adept-logo-grimoire-original.png` to drop the
  embedded certificate chain whose subject holds an address.** verified: at
  29a64d5 the alphabetic-TLD-plus-boundary form exits 1 over `docs/assets/`, so
  nothing needs re-encoding — and retrofitting redaction into merged assets is
  excluded from issue #377.
- **Doing nothing.** judgment: since #376 this gate is the only leak control
  between a model-composed hand-off narrative and a public comment, and a
  narrative about a failed run is where an address appears.
