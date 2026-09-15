# Widen the public-safety scanner to addresses and private-use suffixes

**Goal.** Make `skills/quest/scripts/check-public-safety` deny email addresses
and enumerated private-use domain suffixes, say where callers read it that the
gate matches shapes and not names, and keep it green over this repository's tree.

**Architecture.** The scanner is one bash script: it builds a list of scan
targets, then loops over a `denied_patterns` array running one
`rg --no-config --json` per pattern and filtering the structured output through
`jq`, which drops a match whose every submatch is exempt by comparing each
submatch's whole text against one anchored regular expression. This change adds
two array entries and extends that expression from one exemption class to
three. Nothing else in the pipeline moves.

**Tech stack.** bash, ripgrep, jq, awk, git; `just` recipes; `prek` hooks.

## Global Constraints

Transcribed from `CLAUDE.md` and [the
spec](../specs/2026-09-15-public-safety-names-design.md):

- **Bash 3.2 is the floor** (macOS ships 3.2.57): no `mapfile`, no `readarray`,
  no associative arrays.
- Shell is bash with **tab indentation**, `#!/usr/bin/env bash`, `set -euo pipefail`.
- Every `rg` invocation in a gate script passes `--no-config`.
- Capture a scan's exit status explicitly. `rg` exits 1 for no matches and
  greater than 1 for a real failure. Run gates bare: no `| tail`, no
  `>/dev/null`, no `|| true`.
- This repository is **public**, and the gate scans its own tracked tree.
  A fixture must assemble any denied literal from split `printf` arguments so
  the suite file is not itself a match.
- **Nothing automated asserts on prose** (anatomy rule 4): no test pins a
  sentence or a table row.
- `.claude-plugin/plugin.json` `version` is `5.9.0` exactly — the reserved
  value for this pull request under
  [ADR 0022](../../adr/0022-versioned-manifest-and-bump-gate.md). This
  repository has **no ADR index**; add no index row.
- The decision is already recorded in
  [ADR 0067](../../adr/0067-the-public-safety-gate-matches-shapes-not-names.md),
  written in the design phase. No task creates or edits it.

Expected implementation size: 130–190 changed lines (M) — derived from this
plan's file map: two pattern entries plus the rewritten exemption assignment and
its comment in the scanner, seven fixture blocks in the suite, four lines in
`skills/quest/SKILL.md`, and one version field.

## File map

| File | Owns now | Owns after |
|---|---|---|
| `skills/quest/scripts/check-public-safety` | fifteen denied patterns, one home-path exemption | seventeen patterns, one three-class exemption |
| `scripts/check-public-safety-test.sh` | cases for the fifteen | the same, plus the two additions and the exemptions |
| `skills/quest/SKILL.md` | a sentence describing the scanner's coverage | the same sentence, stating the hostname limit |
| `.claude-plugin/plugin.json` | `version` | `version` `5.9.0` |

All four are modified; nothing is created, moved or removed. No caller changes: `scripts/check-public-safety.sh`,
`skills/quest/scripts/publish-forge-review` and
`skills/return-to-town/scripts/publish-handoff` keep their contracts — exit 0
clean, 1 on a finding, 2 on a fault, one JSON record per finding. Nothing is
obsoleted, no compatibility path is retained, no caller migration arises.

## Task 1 — Deny addresses and private-use suffixes

Creates nothing. Modifies `skills/quest/scripts/check-public-safety`. Tests in
`scripts/check-public-safety-test.sh`.

**Interfaces.** Consumes nothing from an earlier task. Later tasks rely on
nothing from it. Inside the scanner this task renames the shell variable
`public_home_match` to `exempt_submatch`; that name is local to the file and
reaches the `jq` filter only through the existing `--arg allowed` binding.

**Where it fits.** The whole behaviour change; Task 2 documents it.

### Verification

- **Contract: an email address in a non-reserved domain is denied.**
  Mode: `focused-test`. Observable contract: the scanner exits 1 and prints a
  JSON record for the matching line. Case: the "an email address is a leak"
  block added to `scripts/check-public-safety-test.sh`. Expected red before the
  pattern exists: `public-safety-test: an email address should be denied`.
  Green: `just test check-public-safety`.
- **Contract: each of the four private-use suffixes is denied.**
  Mode: `focused-test`. Case: the per-suffix loop added to the same suite.
  Expected red at step 4: `public-safety-test: a private-use suffix should be
  denied: intranet`. Green: `just test check-public-safety`.
- **Contract: reserved documentation addresses and the published constants
  are exempt.** Mode: `focused-test`. Case: the exempt-constants block.
  Expected red at step 6: `public-safety-test: published address constants
  should not be denied`. Green: `just test check-public-safety`.
- **Contract: an uppercase private-use host is denied.** Mode: `focused-test`.
  Case: the uppercase block. Bite shown at step 10 by dropping `(?i)`:
  `public-safety-test: an uppercase private-use host should be denied`. Green:
  same command.
- **Contract: a host of three or more labels is outside the suffix shape.**
  Mode: `focused-test`. Case: the FQDN block. Bite shown at step 10 by the
  permissive multi-label form: `public-safety-test: a multi-label host is
  outside the suffix shape`. Green: same command. This pins an accepted false
  negative so it stays a decision (ADR 0067) rather than an accident.
- **Contract: a dotted identifier ending in a kept suffix stays green.**
  Mode: `focused-test`. Case: the identifier block. Bite shown at step 10 by
  restoring `\b` in place of the leading boundary: `public-safety-test: a dotted
  identifier is not a private-use host`. Green: same command.
- **Contract: an address without an alphabetic top-level domain is not
  matched.** Mode: `focused-test`. Case: the certificate-subject block. Bite
  shown at step 10 by relaxing `[[:alpha:]]` to `[[:alnum:]]`:
  `public-safety-test: a non-alphabetic top-level domain is not an address`.
  Green: same command.
- **Contract: `.local`, `.home` and `.private` stay green.** Mode:
  `focused-test`. Case: the excluded-suffix block. Bite shown at step 10 by
  adding `local` to the alternation: `public-safety-test: excluded suffixes
  should not be denied`. Green: same command.
- **Contract: an exemption does not silence a leak on its line.** Mode:
  `focused-test`. Case: the mixed-line block. Bite shown at step 10 by changing
  the `jq` filter from `any` to `all` over submatches — but the pre-existing
  home-path fixture asserts the same per-submatch contract and reaches it first,
  so the observed red is `public-safety-test: home leak sharing a line with a CI
  path should fail`. The new block extends that contract to the address class
  rather than establishing it. Green: same command.
- **Contract: the gate stays green over this repository's tracked tree.**
  Mode: `focused-test`. Command `just public-safety`, exit 0.

### Steps

1. Write the failing cases first. In `scripts/check-public-safety-test.sh`,
   immediately after the block ending with the Atlassian tenant-hostname case
   and its `rm -f "$SCRATCH/repo/tenant.md"`, insert:

   ```bash
   # An email address is PII CLAUDE.md names and no pattern matched (issue #377).
   # Assembled at runtime so this file is not itself a match for the gate.
   printf 'reached person@leaky-ho%s\n' 'st.net' >"$SCRATCH/repo/contact.md"
   if "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
   	printf 'public-safety-test: an email address should be denied\n' >&2
   	exit 1
   fi
   rm -f "$SCRATCH/repo/contact.md"

   # Four of RFC 6762 Appendix G's six unofficial internal top-level domains.
   # The suffix is interpolated so this file carries no labelled instance of one.
   for suffix in intranet internal corp lan; do
   	printf 'the box is build-agent.%s\n' "$suffix" >"$SCRATCH/repo/host.md"
   	if "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
   		printf 'public-safety-test: a private-use suffix should be denied: %s\n' \
   			"$suffix" >&2
   		exit 1
   	fi
   done
   rm -f "$SCRATCH/repo/host.md"

   # An uppercase host is the ordinary rendering where .corp and .intranet are most
   # used, so the suffix pattern is case-insensitive.
   printf 'the box is BUILD-AGENT.%s\n' 'CORP' >"$SCRATCH/repo/shouting.md"
   if "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
   	printf 'public-safety-test: an uppercase private-use host should be denied\n' >&2
   	exit 1
   fi
   rm -f "$SCRATCH/repo/shouting.md"

   # The same leading boundary that keeps a dotted identifier out also keeps a host
   # of three or more labels out: no start position can reach the suffix. That is a
   # false negative the gate accepts rather than a bug (ADR 0067), and it is pinned
   # here so it is a decision rather than an accident.
   {
   	printf 'the box is build01.dc2.%s\n' 'corp'
   	printf 'jenkins.eng.%s timed out\n' 'internal'
   } >"$SCRATCH/repo/fqdn.md"
   if ! "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
   	printf 'public-safety-test: a multi-label host is outside the suffix shape\n' >&2
   	cat "$SCRATCH/output" >&2
   	exit 1
   fi
   rm -f "$SCRATCH/repo/fqdn.md"

   # Reserved documentation domains identify nobody, and the GitHub SSH user and
   # the commit trailer are published constants this repository's prose carries.
   {
   	printf 'clone with git@github.com:randomparity/adept.git\n'
   	printf 'Co-Authored-By: Claude <noreply@anthropic.com>\n'
   	printf 'git config user.email fixture@example.invalid\n'
   	printf 'write to user@example.com, or to hook@example.test\n'
   } >"$SCRATCH/repo/exempt.md"
   if ! "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
   	printf 'public-safety-test: published address constants should not be denied\n' >&2
   	cat "$SCRATCH/output" >&2
   	exit 1
   fi
   rm -f "$SCRATCH/repo/exempt.md"

   # A dotted identifier is not a host. The suffix pattern requires the label in
   # front of the suffix to start a dotted token, which is what separates a name
   # written into prose from one segment of a longer dotted identifier.
   {
   	printf 'System.getProperty("user.home") in package com.acme.internal;\n'
   	printf 'path.home was unset and java.home pointed at a stale JDK\n'
   	printf 'at com.example.internal.FooService.bar(FooService.java:42)\n'
   	printf 'the class exposes this.private and self.private accessors\n'
   } >"$SCRATCH/repo/identifiers.md"
   if ! "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
   	printf 'public-safety-test: a dotted identifier is not a private-use host\n' >&2
   	cat "$SCRATCH/output" >&2
   	exit 1
   fi
   rm -f "$SCRATCH/repo/identifiers.md"

   # An address in prose ends in an alphabetic top-level domain. --text hands
   # binaries to every pattern, and a certificate subject inside one runs into
   # the bytes after it; that is a byte run, not an address.
   printf 'certificate subject ca@vendor.ai1 and more\n' >"$SCRATCH/repo/binaryish.md"
   if ! "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
   	printf 'public-safety-test: a non-alphabetic top-level domain is not an address\n' >&2
   	cat "$SCRATCH/output" >&2
   	exit 1
   fi
   rm -f "$SCRATCH/repo/binaryish.md"

   # .local, .home and .private are outside the suffix set (ADR 0067): the first
   # collides with this repository's own file naming, which .gitignore carries,
   # and the other two with ordinary dotted identifiers.
   printf 'ignore CLAUDE.local.md, settings.local.json, user.home, vpc.private\n' \
   	>"$SCRATCH/repo/excluded.md"
   if ! "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
   	printf 'public-safety-test: excluded suffixes should not be denied\n' >&2
   	cat "$SCRATCH/output" >&2
   	exit 1
   fi
   rm -f "$SCRATCH/repo/excluded.md"

   # The exemption is compared against each submatch, not the line: a real
   # address beside an exempt one is reported, and it is the one printed.
   printf 'mail git@github.com or person@leaky-ho%s\n' 'st.net' \
   	>"$SCRATCH/repo/mixed.md"
   if "$CHECKER" "$SCRATCH/repo" >"$SCRATCH/output" 2>&1; then
   	printf 'public-safety-test: an address leak beside an exempt one should fail\n' >&2
   	exit 1
   fi
   if ! grep -qF 'leaky-host.net' "$SCRATCH/output"; then
   	printf 'public-safety-test: the reported line should name the real address\n' >&2
   	cat "$SCRATCH/output" >&2
   	exit 1
   fi
   rm -f "$SCRATCH/repo/mixed.md"
   ```

2. Confirm the first expected failure: run `just test check-public-safety`.
   Expect a non-zero exit and, in the replayed output,
   `public-safety-test: an email address should be denied`. Each fixture block
   ends in `exit 1`, so the suite stops at the first one and the edits below
   unblock the next red in turn. Only the three blocks that assert a denial can
   be red before the patterns exist; step 10 shows the three that assert a pass.

3. Add the email pattern. In `skills/quest/scripts/check-public-safety`, in the
   `denied_patterns` array, insert immediately after the
   `'[[:alnum:]-]+\.atlassian\.net'` entry:

   ```bash
   	'[[:alnum:]._%+-]+@[[:alnum:]-]+(\.[[:alnum:]-]+)*\.[[:alpha:]]{2,}\b'
   ```

4. Confirm the second expected failure: run `just test check-public-safety`.
   The email block now passes and the suite reaches the suffix loop. Expect a
   non-zero exit and `public-safety-test: a private-use suffix should be denied:
   intranet`.

5. Add the suffix pattern, on the line after the one step 3 added:

   ```bash
   	'(?i)(^|[^[:alnum:].-])[[:alnum:]-]+\.(intranet|internal|corp|lan)\b'
   ```

   The leading alternative is the idiom the `10\.` private-address entry already
   uses: ripgrep's Rust regex engine has no lookbehind, so the character in
   front is matched rather than asserted. It is what keeps `com.acme.internal`
   and `java.home` out while a bare label in front of the suffix stays in. This
   plan spells no such label: the gate scans this file too, which is why the
   fixture above interpolates the suffix instead of writing it.

6. Confirm the third expected failure: run `just test check-public-safety`. The
   suffix loop now passes and the suite reaches the exempt-constants block,
   which the email pattern denies until the exemption below lands. Expect a
   non-zero exit and `public-safety-test: published address constants should not
   be denied`.

7. Replace the exemption. In the same file, keep the existing two paragraphs of
   comment beginning `# Two names under /home are not people.` exactly as they
   are, insert this paragraph above them, and replace the
   `public_home_match='^/home/(runner|linuxbrew)$'` line below them with the
   three lines here:

   ```bash
   # Three classes of submatch are not leaks, and one anchored alternation holds
   # all three. What lets them share one expression is that their shapes are
   # disjoint: a home path can never equal an address, so no class can silence
   # another's finding (ADR 0067). Anchoring bounds each entry to a whole
   # submatch, which is not the same as bounding it to one string -- the RFC
   # 2606 class below is deliberately open-ended, and a fourth class may be too.
   #
   # RFC 2606 reserves .test, .example and .invalid as top-level domains and
   # example.com, example.net and example.org as second-level domains, precisely
   # so documentation and fixtures can name an address that reaches nobody. This
   # repository's suites use them for every fixture Git identity.
   #
   # git@github.com is the fixed user in an SSH remote URL rather than a mailbox,
   # and noreply@anthropic.com is the published constant in this repository's
   # commit trailers. Neither names a person, and both occur in tracked prose
   # here; another forge's equivalent is not exempt until one does. An address
   # under users.noreply.github.com deliberately is not exempt either: it
   # carries a username, which CLAUDE.md lists as PII.
   exempt_submatch='^(/home/(runner|linuxbrew)'
   exempt_submatch="$exempt_submatch"'|[[:alnum:]._%+-]+@([[:alnum:]-]+\.)*(example\.(com|net|org)|invalid|test|example)'
   exempt_submatch="$exempt_submatch"'|git@github\.com|noreply@anthropic\.com)$'
   ```

8. Point the filter at the new name. In the same file, in the `jq` invocation
   inside the `0)` branch of the pattern loop, change
   `--arg allowed "$public_home_match"` to `--arg allowed "$exempt_submatch"`.

9. Confirm the pass: run `just test check-public-safety`. Expect exit 0 and
   `test: 1 suites passed`.

10. Show that the three blocks asserting a pass bite. Make each mutation, run
    `just test check-public-safety`, confirm the named message, then revert the
    mutation and re-confirm exit 0 before making the next one:

    - replace the suffix pattern's `(^|[^[:alnum:].-])` with `\b` — expect
      `public-safety-test: a dotted identifier is not a private-use host`;
    - replace the email pattern's `[[:alpha:]]{2,}` with `[[:alnum:]]{2,}` —
      expect `public-safety-test: a non-alphabetic top-level domain is not an
      address`;
    - add `|local` to the suffix alternation — expect `public-safety-test:
      excluded suffixes should not be denied`;
    - drop `(?i)` from the suffix pattern — expect `public-safety-test: an
      uppercase private-use host should be denied`;
    - replace the suffix pattern with the permissive multi-label form
      `(^|[^[:alnum:].-])[[:alnum:]-]+(\.[[:alnum:]-]+)*\.(intranet|internal|corp|lan)\b`
      — expect `public-safety-test: a multi-label host is outside the suffix
      shape`;
    - change the `jq` filter's `any` to `all` over submatches — expect
      `public-safety-test: home leak sharing a line with a CI path should fail`,
      the suite's first instance of the per-submatch contract;
    - delete the RFC 2606 branch from `exempt_submatch` and run
      `just public-safety` — expect exit 1 naming reserved-domain fixture
      identities across the tracked tree.

11. Run `just public-safety`, then `just lint`, then `just format-check`. Expect
    exit 0 and no output from each.

12. Commit with `git add -A && git commit` and a conventional subject such as
    `feat: deny addresses and private-use domain suffixes`. `prek` runs
    `just commit-check`, which includes `public-safety`; expect it to pass.

**Acceptance criteria.** The two patterns are present in `denied_patterns`, and
`public_home_match` no longer appears in
`skills/quest/scripts/check-public-safety` — the design records keep their own
references to the old name, which are the record of the rename rather than
residue of it. `just test check-public-safety`, `just public-safety`,
`just lint` and `just format-check` each exit 0. **Rollback:** `git revert` the
commit; nothing outside the working tree changed.

## Task 2 — State the limit where callers read it, and bump the manifest

Creates nothing. Modifies `skills/quest/SKILL.md` and
`.claude-plugin/plugin.json`.

**Interfaces.** Consumes the behaviour Task 1 shipped. Nothing relies on this
task.

**Where it fits.** Issue #377's third acceptance criterion requires the recorded
decision to be said where callers read it. ADR 0067 is the record; this is the
saying.

### Verification

- **Contract: the caller-facing description of the scanner's coverage.**
  Mode: `task-test-not-applicable`. The changed surface is one sentence of prose
  in a skill document; no executable consumer validates its wording, and anatomy
  rule 4 forbids a gate that asserts on prose, so no task-specific observation
  could fail meaningfully.
- **Contract: the manifest version.** Mode: `focused-test`. Observable contract:
  `scripts/check-plugin-version.sh` accepts the declared version. Command
  `just version-check`, exit 0. The strictly-greater rule runs in CI, which
  supplies `BASE_SHA`; a local run checks presence and format and says so.
- **Contract: ADR 0067 is a well-formed record.** Mode: `focused-test`.
  Observable contract: the `adr` profile of `.github/scripts/check-records.sh`
  accepts it. Command `just records`, exit 0. The record was written in the
  design phase, so no step edits it; this is where the plan verifies it.

### Steps

1. In `skills/quest/SKILL.md`, replace the two lines at 866-867 — the sentence
   beginning `The scanner checks generic private paths` and the one that follows
   it — with these four. The surrounding paragraph wraps at 90-101 columns, so
   the replacement does too; a narrower rewrap would reflow this paragraph alone
   and no gate in this repository formats Markdown.

   ```markdown
   The scanner checks generic private paths (including Windows profile paths), private addresses,
   email addresses, an enumerated set of private-use domain suffixes, and credential patterns. It
   matches shapes, not names: it does not detect hostnames, and no enumeration covers every internal
   domain. It is a backstop to the public-safety review, not exhaustive PII detection.
   ```

2. In `.claude-plugin/plugin.json`, set the `version` field to `5.9.0`.

3. Run `just version-check`, `just records`, `just shape-check` and
   `just plugin-check`. Expect exit 0 from each.

4. Commit with `git add -A && git commit` and a conventional subject such as
   `docs: say the public-safety gate matches shapes, not names`.

**Acceptance criteria.** `skills/quest/SKILL.md` names the two new classes and
the hostname limit. `.claude-plugin/plugin.json` declares `5.9.0`.
`just version-check`, `just records`, `just shape-check` and `just plugin-check`
each exit 0.
Then `just verify` bare exits 0 over the finished branch; the managed pre-push
hook re-runs `just ci` in an isolated worktree on `git push` and regularly
exceeds a two-minute tool timeout — slowness, not a hang, so raise the timeout
rather than re-invoking. **Rollback:** `git revert` the commit.
