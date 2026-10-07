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
- a private-use domain suffix — a dotted token's first label followed by one of
  `.intranet`, `.internal`, `.corp` or `.lan`, closed by a word boundary, matched
  case-insensitively.

`.local`, `.home` and `.private` are deliberately absent, and no general
hostname pattern is added. ADR 0067 records all three decisions, and the
caller-facing sentence at `skills/quest/SKILL.md` gains the limit rather than
leaving a reader to infer it.

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
repository's own tracked tree, or every commit in it reddens. A false positive
in a composed body fails a public write closed, and both publishers discard the
scanner's stdout, so the operator cannot see which token matched. A finding must
not be silenced by an exemption written for an unrelated pattern. A scan that
cannot run must not read as a scan that found nothing.

**Accepted failure classes.**

- A hostname, a link-local `.local` name, or an internal domain outside the four
  enumerated suffixes reaches a public comment — no tractable pattern exists
  (ADR 0067), and the gate is declared a shape backstop, not exhaustive PII
  detection.
- An address in a reserved documentation domain, `git@github.com`, or
  `noreply@anthropic.com` reaches a public comment. The two constants name no
  person; the reserved-domain class is safe because the domain reaches nobody,
  and its local part is unconstrained, so a half-redacted address that kept the
  name and rewrote the domain passes. All three occur in tracked prose here.
- A host whose kept suffix is its third label or later is not matched: the
  leading boundary admits no start position for `build01.dc2.corp` or
  `jenkins.eng.internal`. The permissive form that would reach them reddens on
  package paths (ADR 0067), so this false negative is taken deliberately, pinned
  by a fixture, and stated in `skills/quest/SKILL.md`.
- An address whose top-level domain is not alphabetic is not matched — not an
  address in prose, and the alphabetic form keeps the pattern off binary content.
- A dotted token is denied when its second label is a kept suffix, whatever
  follows it, provided its first label begins a whitespace- or
  punctuation-delimited run — anywhere in a line, not only at its start. That
  covers an identifier as well as a host: a package path whose second segment is
  one of the four. The cost is bounded: the write fails closed, the remedy is to
  reword the narrative, and the leading-boundary requirement already clears the
  reproduced collisions (`user.home`, `com.acme.internal` and their kind).

**Covered elsewhere.** Redaction of already-merged history, documents and
assets — excluded from #377 by the frozen charter. The fifteen existing
patterns' own behaviour — excluded by the same charter.

## Threat model

**Boundary inventory.** No boundary is added. Two existing ones move: the
exemption alternation, the only input that can turn a match into a pass, is
widened; and the denied-pattern list, which decides what fails a write closed,
gains two entries — availability, not confidentiality.

**Actor model.** The untrusted content is the text under scan — a hand-off or
review body assembled from model and tool output, and the tracked tree of a
public repository. The operator, the exemption list and the pattern list are
trusted; they are code review's subject, not the gate's input.

**Control per boundary.** Each exemption is compared anchored (`^…$`) against
whole submatch text, so it can exempt only a whole submatch — never a substring,
and never the line a non-exempt submatch shares with it. An exemption class may
still be open-ended, as the RFC 2606 one is. The `jq` filter reports a line when
any submatch is non-exempt. Nothing is echoed on a fault; the existing
clean/finding/fault status branches are unchanged.

**Explicitly out of scope.** Deliberate evasion, for a different reason at each
boundary. On the tracked tree, an author who can add a leak can edit the
patterns in the same commit, so the gate is not a boundary against them. On the
composed body that reason fails — the composer controls the bytes and cannot
reach the bundled pattern list — so the posture is stated instead: it is
untrusted but not adversarial, and a regex list is not claimed to stop a steered
one. Detection of names, per ADR 0067.

## Success

1. The scanner denies an email address, and a host written as one label plus one
   of the four enumerated suffixes in either case, each reported with the
   existing path, line and content record. A longer dotted name under the same
   suffix is out of shape, per the failure model.
2. Every address form in this repository's tracked tree at the branch point is
   exempt, and the scan over that tree stays green.
3. No entry in the exemption alternation silences a non-exempt submatch sharing
   its line, because the comparison is against whole submatch text.
4. ADR 0067 exists, `skills/quest/SKILL.md` states the hostname limit, and
   `.claude-plugin/plugin.json` declares version `5.9.0`.

## Validation

The first five entries run `just test check-public-safety` against fixtures in
`scripts/check-public-safety-test.sh`; each remaining entry names its own green
command.

- **Contract: the email pattern denies an address.** Mode: focused-test — a
  fixture carrying an address in a non-reserved domain; red before the pattern.
- **Contract: reserved and published addresses are exempt.** Mode: focused-test
  — fixtures for each exempt form; red if the exemption is absent.
- **Contract: the suffix pattern denies a private-use host.** Mode:
  focused-test — one fixture per enumerated suffix.
- **Contract: `.local`, `.home`, `.private`, a mid-chain suffix, and an address
  without an alphabetic top-level domain stay green.** Mode: focused-test —
  negative fixtures, each shown to bite by a reverted mutation.
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
