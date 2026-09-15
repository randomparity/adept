# Widen the public-safety scanner to addresses and private-use suffixes — issue #377

Charter: issue #377 `WORK:SCOPE` token `q377-996fda3b`, which retains the
operator-approved exclusions and their owners. Design denominator: 250 changed
lines (M), from the live assessment frozen in that annotation.

## Problem

`skills/quest/scripts/check-public-safety` denies fifteen patterns covering
absolute home paths, private address ranges and credential shapes. `CLAUDE.md`
also names email addresses, internal domain suffixes and hostnames as PII to
redact before a public write, and no pattern matches any of the three. Since
PR #376 this gate is the only leak control between a model-composed hand-off
narrative and a public GitHub comment — and such a narrative is prose about a
failed run, exactly where an address appears.

## Scope and behavior

[ADR 0067](../../adr/0067-the-public-safety-gate-matches-shapes-not-names.md)
selects the shape of the widening. Two entries join `denied_patterns`:

- an email address — a local part, `@`, one or more domain labels, and an
  alphabetic top-level domain closed by a word boundary;
- a private-use domain suffix — a label followed by one of RFC 6762 Appendix G's
  six unofficial internal top-level domains, closed by a word boundary.

`.local` is deliberately absent, and no general hostname pattern is added. ADR
0067 records both, and the caller-facing sentence at `skills/quest/SKILL.md`
gains the limit rather than leaving a reader to infer it.

The exemption mechanism keeps its present shape: one anchored regular
expression compared against whole submatch text inside the existing `jq`
filter, so a line is reported when any submatch is non-exempt. It is renamed
from `public_home_match` and extended from one class to three — the published
CI home paths it already held, addresses in RFC 2606's reserved documentation
domains, and the SSH remote user and commit-trailer constant this repository's
tracked prose carries. Nothing else in the scan pipeline changes; the fifteen
existing patterns and the wrapper `scripts/check-public-safety.sh` are
untouched.

## Failure model

**Actors and deployments.** A local operator running `just verify`; `prek`
running `just commit-check` on every commit; CI running `just ci`;
`skills/quest/scripts/publish-forge-review` and
`skills/return-to-town/scripts/publish-handoff` scanning one composed body file
before a public write.

**Invariants and assets at stake.** The gate must stay green over this
repository's own tracked tree, or every commit in it reddens. A finding must
not be silenced by an exemption written for an unrelated pattern. A scan that
cannot run must not read as a scan that found nothing.

**Accepted failure classes.**

- A hostname, a link-local `.local` name, or an internal domain outside the six
  enumerated suffixes reaches a public comment — no tractable pattern exists
  (ADR 0067), and the gate is declared a shape backstop, not exhaustive PII
  detection.
- An address in a reserved documentation domain, `git@github.com`, or
  `noreply@anthropic.com` reaches a public comment — none identifies a person,
  and all three occur in this repository's tracked prose.
- An address whose top-level domain is not alphabetic is not matched — not an
  address in prose, and the alphabetic form keeps the pattern off binary content.

**Covered elsewhere.** Redaction of already-merged history, documents and
assets — excluded from #377 by the frozen charter. The fifteen existing
patterns' own behaviour — excluded by the same charter.

## Threat model

**Boundary inventory.** No boundary is added. One is widened: the exemption
alternation, the only input that can turn a match into a pass. The two new
patterns narrow the scan surface rather than widening it.

**Actor model.** The untrusted content is the text under scan — a hand-off or
review body assembled from model and tool output, and the tracked tree of a
public repository. The operator, the exemption list and the pattern list are
trusted; they are code review's subject, not the gate's input.

**Control per boundary.** Each exemption is compared anchored (`^…$`) against
whole submatch text, so it can exempt only an exact string, never a substring
or a line, and the `jq` filter reports a line when any submatch is non-exempt.
Nothing is echoed on a fault; the existing clean/finding/fault status branches
are unchanged.

**Explicitly out of scope.** Deliberate evasion by an author who controls the
scanned bytes — the subject is accidental leakage, and an author who can edit
the tree can edit the patterns. Detection of names, per ADR 0067.

## Success

1. The scanner denies an email address and a private-use suffix drawn from the
   six enumerated suffixes, each reported with the existing path, line and
   content record.
2. Every address form in this repository's tracked tree at the branch point is
   exempt, and the scan over that tree stays green.
3. No entry in the exemption alternation silences a non-exempt submatch sharing
   its line, because the comparison is against whole submatch text.
4. ADR 0067 exists, `skills/quest/SKILL.md` states the hostname limit, and
   `.claude-plugin/plugin.json` declares version `5.9.0`.

## Validation

Every entry below runs `just test check-public-safety` for its green command,
against fixtures in `scripts/check-public-safety-test.sh`.

- **Contract: the email pattern denies an address.** Mode: focused-test — a
  fixture carrying an address in a non-reserved domain; red before the pattern.
- **Contract: reserved and published addresses are exempt.** Mode: focused-test
  — fixtures for each exempt form; red if the exemption is absent.
- **Contract: the suffix pattern denies a private-use host.** Mode:
  focused-test — one fixture per enumerated suffix.
- **Contract: `.local` and an address without an alphabetic top-level domain
  stay green.** Mode: focused-test — two negative fixtures.
- **Contract: an exemption does not silence a leak on its line.** Mode:
  focused-test — one mixed-line fixture.
- **Contract: the gate stays green over this repository's tracked tree.** Mode:
  focused-test — `just public-safety`, exit 0.
- **Contract: ADR 0067 is a well-formed record.** Mode: focused-test —
  `just records`, exit 0.
- **Contract: the caller-facing sentence in `skills/quest/SKILL.md`.** Mode:
  task-test-not-applicable — one sentence of prose whose correctness no
  executable consumer validates, and anatomy rule 4 forbids a gate that asserts
  on prose.
- **Contract: the manifest version.** Mode: focused-test — `just version-check`,
  exit 0, and the CI bump rule against `BASE_SHA`.
