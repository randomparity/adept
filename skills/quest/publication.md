# Quest delivery and review publication

Read this complete procedure before step 8's delivery or publication decisions or writes.
[Quest's entrypoint](SKILL.md#8-ship-it) retains phase ordering, G4 and the build-complete gate.
Use only after those gates and step 5's complete handoff validation; this is the rest of step 8.
Exceptional recovery is a separate [human-authorized procedure](publication-recovery.md);
an interrupted publication never restarts this ordinary route.

Run `$deliver <issue-number> --claim-token <scope-token>` to push the branch, create the PR, and drive it
to green CI and mergeable state. Keep a compact public review summary — the
fields below — as
an ignored private mode-0600 file beside the forge ledger; do not put outer
annotation markers or forge-review payload in it. `REVIEW_SUMMARY` is the exact
`review-summary:` path in the parsed handoff, not an ad-hoc filename. The
verbose per-iteration findings file is droppable.

After `$deliver` reports the PR, resolve it once and verify its repository,
number, head branch, base branch, and `headRefOid`. They must equal `REPO`, the
returned `PR`, the handoff branch, `BASE_BRANCH`, and `git rev-parse HEAD`
respectively. A missing, changed, or mismatched value parks before summary
creation and before the helper; never publish a review for an unverified PR
head. Persist that full `git rev-parse HEAD` value as `delivered-head-sha:`
when writing the `publication-in-progress` handoff.

After `$deliver` creates the PR, create that summary once with `mktemp` beside
the ledger and atomically rename it only after writing these exact, non-empty
single-line fields in order:

```text
verdict: <trial-loop reviewer verdict>
exit: <trial-loop run outcome, or none>
findings: <count>
iterations: <count>
security: <$detect-evil verdict or not triggered>
delivered-head-sha: <full exact delivered PR head SHA>
```

`verdict:` and `exit:` are two facts about the same run — the last `$trial-loop`
run on the branch, the one `findings:` and `iterations:` already count.
`verdict:` is the verdict the selected reviewer actually returned on the last
pass, never derived from the exit. `exit:` is one of two values, by how that run
ended:

- `none` — the run finished. Its last verdict is `approve` where the reviewer
  cleared the branch and `needs-attention` where the only blocking findings left
  were ones the run had already dispositioned; `exit:` does not distinguish those,
  because neither is blocked and `verdict:` already carries the difference.
- `blocked-at-budget` — a run stopped as blocked at the iteration budget, then
  continued through step 6's approved-continuation resume path. `verdict:`,
  `findings:`, and `iterations:` describe that stopped run; the approval is its
  aftermath, not a second ending.

Every other stop parks the quest before `$deliver` and publishes no summary at
all, a cycle ended for rescoping without new authority included, so there is no
run that reaches this field with nothing to write.

ADR 0053 is the authority for this field's values, amending ADR 0021, which
remains the authority for the field set. A run's payload — the lists step 6 carries:
deferrals with their owning paths or tracker issues, follow-up candidates, rejected findings,
outstanding notes, and a budget stop's remaining-findings summary — stays out of
the summary and out of every field: ADR 0028 sends it through the helper's payload
slot into `WORK:REVIEW` and through this step's named write moment into the PR body,
which is where `$trial-loop`'s own report obligation sends it.

If step 6 carried any of the lists it specifies — a deferral list, follow-up-candidates table,
rejected findings, outstanding notes, or a budget stop's remaining-findings summary — compose
the run's payload file once, immediately after the summary: write only the lists step 6
specifies into a `mktemp` file beside the ledger — no headings; each destination adds
its own — atomically rename it only after the write, reject carriage return, NUL, and
outer annotation markers, and keep the temporary and installed payload in mode 0600.
A run with nothing to carry creates no payload file and skips every payload step below.

The publication helper and its
`"<plugin root>/skills/quest/scripts/check-public-safety"` scanner ship together in this skill. Resolve both from the installed skill directory; never search the target repository for
Adept maintenance scripts. The scanner requires `rg` and `jq`; the helper checks these alongside
its other commands before composing content. Missing commands name an installation/PATH remedy.
A missing bundled scanner requires repairing the installed skill, not substituting a repository gate.
The scanner checks generic private paths (including Windows profile paths), private addresses,
email addresses, an enumerated set of private-use domain suffixes, and credential patterns. It
matches shapes, not names: it does not detect hostnames, and no enumeration covers every internal
domain. The suffix check reaches any dotted token whose second label is one of those suffixes —
an identifier as readily as a host — and misses a host whose suffix is its third label or later,
so a three-label FQDN passes. It is a backstop to the public-safety review, not exhaustive PII
detection.
Unsafe content and scan failures both stop publication and retain evidence, with distinct messages
that do not echo matched content.

Before any PR-body write, invoke the helper in validation-only mode with the exact publication
arguments:

```sh
"<plugin root>/skills/quest/scripts/publish-forge-review" --preflight --claim-token "$SCOPE_TOKEN" \
  "$REPO" "$PR" "$FORGE_MODE" "$FORGE_REVIEW_OR_REASON" \
  "$FORGE_LEDGER" "$REVIEW_SUMMARY" "$REVIEW_PAYLOAD"
```

Pass `SCOPE_TOKEN` from the parsed claim/scope binding, never from an untrusted
holder payload. Both helper modes require it; only normal publication verifies the
claim. Review preflight remains network-free. Handoff preflight retains its existing
bounded read-only discovery and composition. Require its sole stdout line to be `preflight-ok`. This mode validates and composes only: it must
not call GitHub, append the ledger, dispose a source, or retain its temporary body. On nonzero or
any other output, park with the `build-complete` handoff and retained evidence; do not write the PR
body or `publication-in-progress`. That is a local pre-write failure, not a consumed publication
attempt.

Then make the one named PR-body write, ADR 0028's second destination: read the
delivered PR body, append a blank line, the `## Review exit payloads` heading, and the
payload file's contents, write the result back with the installed `"<plugin root>/skills/deliver/scripts/deliver-write"
--claim-token "$SCOPE_TOKEN" "$REPO" "$ISSUE" pr-edit "$PR" BODY-FILE`, and
require the readback to match the composed body byte-for-byte apart from at most one
trailing newline, which GitHub's PR-body storage adds. This is the only moment the PR body gains the section — before the
`publication-in-progress` handoff rewrite, so the write never happens in the terminal
parked phase and never happens twice — and a failed or unverifiable write parks the
quest before the helper with the evidence retained.

Reject carriage return, NUL, outer markers, or any failed byte-for-byte
readback before rename; the temporary and installed summary both stay mode 0600.
If the summary already exists, do not overwrite or recreate it: park for human reconciliation
with the retained evidence. A handoff already in `publication-in-progress` follows the recovery
[procedure](publication-recovery.md) and otherwise parks. After successful preflight and any required PR-body write,
atomically rewrite and byte-verify
the private mode-0600 handoff with phase
`publication-in-progress` plus one `pr: <number>` and one
`delivered-head-sha: <full SHA>` field and one `review-payload: <absolute path|none>` field. On every resume, that phase is parked by default because a
prior comment write may be ambiguous.

Immediately before the helper, re-resolve that exact PR. Require its repository,
number, head branch, base branch, and full `headRefOid` to equal `REPO`, `PR`,
the handoff branch, `BASE_BRANCH`, and `delivered-head-sha:`. A mismatch parks
before posting. Transfer the summary file's lifecycle to the publication helper
and invoke it exactly once:

```sh
"<plugin root>/skills/quest/scripts/publish-forge-review" --claim-token "$SCOPE_TOKEN" \
  "$REPO" "$PR" "$FORGE_MODE" "$FORGE_REVIEW_OR_REASON" \
  "$FORGE_LEDGER" "$REVIEW_SUMMARY" "$REVIEW_PAYLOAD"
```

`REVIEW_PAYLOAD` is the payload file's path, empty when this run carries nothing;
the helper treats an empty seventh argument exactly as absent.

The helper is the sole `WORK:REVIEW` writer. It validates the required review,
the verified not-required reason, and any carried payload, posts one complete
annotation, reads it back,
records verification, and recoverably disposes its owned scratch files. On
nonzero, do not retry, do not post another `WORK:REVIEW`, and park the quest
with the helper's retained evidence and failure output; leave the handoff in
`publication-in-progress`. On success, capture its sole verified comment URL,
require it to parse for this exact `REPO` and `PR`, and require the exact
`review-publication-verified: <URL>` line to occur after this handoff's
`forge-result-record`. Then require the helper's subsequent closing
records -- a `review-publication-disposed:` line, a
`review-publication-undisposed:` line, or both -- to own between them all and
only its former paths, each listing its own subset in owned order and no path
appearing in both: in `required` mode the exact review, `REVIEW_SUMMARY`, and
one helper-created `.publish-forge-review.*` body beside the ledger; in
`not-required` mode the exact `REVIEW_SUMMARY` and that one body; and, when this
run carried a payload, the exact `REVIEW_PAYLOAD` in both modes, named last
among the owned paths. An owned path may contain spaces, so never decide
membership by splitting a record on whitespace: reconstruct the exact record
text for the partition under test from the known owned paths and compare whole
lines. The generated body is the one
owned path whose name this workflow does not already hold: isolate it as the
residue of whichever closing record the partition under test assigns it to,
after removing the known owned paths and their separators, and require it to be
`<ledger-directory>/.publish-forge-review.` plus six characters. The other
record's residue must be empty. An `undisposed` record is a completed publication whose cleanup did not
finish. Continue rather than parking: the ledger, not the exit status, says
whether publication happened, and the helper's stderr and that record already
name the retained paths. Add no field to the handoff for them -- the
`publication-verified` format admits none -- and never name them in a `WORK:*`
annotation, which is public. The body entry must be in the ledger directory
and be the helper's
single generated body identity, not an inferred or older path. Only then
re-resolve the PR and require its repository, number, head branch, base branch,
and full `headRefOid` to still equal the handoff and summary values. If the head
changed after the one comment, park without a retry or a second comment; record
the verified URL and the old full SHA, which the public summary visibly scopes.
Only an unchanged PR permits the private mode-0600 handoff to be atomically
rewritten and byte-verified as `publication-verified` with the PR number, the
preserved `delivered-head-sha:`, preserved `review-payload:`, and
`review-comment-url: <verified URL>`. Carry
that URL into step 9. `$return-to-town` needs no forge-scratch cleanup after a
`review-publication-disposed:` record that owns every path; after a
`review-publication-undisposed:` record the paths it names are still in the
private workspace. Report the incomplete cleanup in the private completion
report by naming the condition and the ledger record that holds the paths, never
the paths themselves -- a completion report is read by a caller that writes
public annotations. They survive only as long as the run's
checkout does -- a worktree teardown removes them along with the ledger -- and
removing them sooner is the operator's. Say why in that report: a retained
`REVIEW_SUMMARY` occupies the fixed path a later step 8 refuses to overwrite, so
leaving it parks the next quest in this checkout at that already-exists guard.

