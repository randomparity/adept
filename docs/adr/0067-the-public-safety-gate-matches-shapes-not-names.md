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
private internal networks: `.intranet`, `.internal`, `.corp` and `.lan`. The
appendix's other two are left out — `.home` and `.private` are also the trailing
component of ordinary dotted identifiers. So is `.local`, which is not in that
list at all: the same appendix recommends against using it this way, and RFC
6762 §3 reserves it for link-local names.

The suffix is matched only where the label in front of it starts a dotted token,
using the leading-boundary idiom the private-address patterns already use, and
case-insensitively, because an uppercase host is the ordinary rendering where
these suffixes are most used. The boundary is what separates a host written into
prose from a suffix that is one segment of a longer dotted identifier — and, as
the consequences below record, it also puts a host of three or more labels out
of reach.

The email pattern requires an alphabetic top-level domain closed by a word
boundary. That is what an address looks like in prose, and it also keeps the
pattern off the certificate chains and other byte runs inside the tracked
binaries `--text` hands to every pattern here.

Exemptions stay one anchored alternation compared against whole submatch text,
extended rather than replaced. It carries three classes: the published CI home
paths it already held, addresses in RFC 2606's reserved documentation domains,
and the two published constants this repository's tracked prose carries — the
`git` user of a GitHub SSH remote URL, and the commit trailer. The RFC 2606
class pins the domain and leaves the local part unconstrained: what makes it
safe is that the domain reaches nobody, not that the address names nobody.

## Consequences

- A hostname in a hand-off narrative still reaches a public comment. The gate
  is a backstop against shapes; names stay a reading problem, and
  `skills/quest/SKILL.md` now says so. Link-local `.local` names are likewise
  not caught.
- A dotted token is denied when its **second** label is a kept suffix, whatever
  follows it, provided its first label begins a whitespace- or
  punctuation-delimited run — anywhere in a line, not only at its start. So a
  vendor URL whose host carries a kept suffix in second position is denied along
  with a bare two-label host, and so is an identifier such as a package path
  whose second segment is one of the four. This record cannot spell either,
  because the gate scans it. Both publishers discard the scanner's stdout, which is
  where the token is; `publish-handoff` passes stderr through, so it names the
  pattern, and `publish-forge-review` discards that too. The operator re-runs
  the scanner by hand. The remedy is to reword, and an exemption entry only
  where the same token recurs.
- The other direction is the false negative: a host whose kept suffix is its
  third label or later is out of reach, because the leading boundary admits no
  start position — `build01.dc2.corp` and `jenkins.eng.internal` both pass. The
  permissive form that would reach it was measured and reddens on package paths
  such as `com.acme.internal`, which is the collision this record's rejected
  alternative already names — so the shape limit is taken and stated rather than
  traded away. `skills/quest/SKILL.md` says it where callers read it.
- A token that is not an address but has an address's shape is denied — a retina
  asset filename and a version-suffixed package spec are the ones seen, and this
  record cannot spell either, because the gate reddened on the first attempt to.
  Nothing in the text separates them from an address, so the write fails closed
  and the remedy is again to reword. Requiring a letter in the first domain label
  does not clear them, so no cheap narrowing was available.
- The pattern's character classes are ASCII, so an address at an
  internationalised domain is not matched. The Rust regex engine's `\w` is
  Unicode-aware and would close it, but it widens the ASCII behaviour too and
  needs its own green run over the tracked tree before it is adopted.
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
  matches. The case-insensitive flag was dropped with them and then restored:
  its only measured cost was `CATALINA.HOME`, a `.home` collision, and with the
  four kept suffixes it is green over this repository's tracked tree. It does
  admit a capitalised two-label namespace fragment — this record cannot spell
  one, because the gate reddened on the first attempt to — which falls in the
  identifier class the spec's failure model already accepts.
  `scripts/check-public-safety-test.sh` carries both halves; it assembles the
  denied literal, which this record cannot.
- **The permissive multi-label form
  `(^|[^[:alnum:].-])[[:alnum:]-]+(\.[[:alnum:]-]+)*\.(intranet|internal|corp|lan)`.**
  verified: it reaches `build01.dc2.corp` and `jenkins.eng.internal`, and over
  the tracked set built from `git ls-files` plus `git ls-tree -r HEAD` it exits
  0 on the package paths this change's own records and fixtures carry. Reaching
  the FQDN costs the identifier protection outright, so the false negative is
  taken and recorded above.
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
