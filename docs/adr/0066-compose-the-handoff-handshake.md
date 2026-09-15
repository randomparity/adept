# 0066 — Compose the hand-off handshake, and only the hand-off

## Status

Accepted (2026-09-06)

## Context

The merge gate admits a hand-off only when one comment carries three anchored whole-line
conditions at once: `<!-- WORK:TRAJECTORY -->`, `<!-- TRAJECTORY:COMPLETE -->`, and
`MERGE-READY: #<PR> @ <sha>`. `skills/return-to-town/SKILL.md` composed that block in prose, and in
one `$campaign` run every merge was held at least once on an annotation defect rather than a code
or CI problem — a backticked handshake, a missing sentinel twice, and a worker that died partway.

`WORK:TRAJECTORY` is dual-purpose. `$return-to-town` writes it for the merge hand-off, with a
`MERGE-READY` line. `$quest`'s *On a Blocker* path writes the same block type to park an issue at
`blocked` or `needs-human`, **without** that line. Quest-log's latest-complete-wins rule means a
naive reader would let a park note posted after a hand-off supersede it. Any helper that composes
this block type has to be shaped so it cannot collide with the park path.

Two accepted records bear on this and neither decides it. **ADR 0042** puts the complete merge gate
in `references/merge-gate.md` and makes that the single normative location, so this record cites the
reference rather than any skill's account of it — and the read-side selection rule quoted below is
0042's text, not a restatement of it. **ADR 0048** established the validation-only preflight
separation for `publish-forge-review`; this record follows it rather than re-deciding it.

## Decision

Ship one helper, `skills/return-to-town/scripts/publish-handoff`, that composes **only** the merge
hand-off block. It has a single mode. It always emits both markers and the handshake line, and it
rejects a narrative file that carries either marker or the token `MERGE-READY:` anywhere in it.
There is no flag selecting a different block shape.

The park path is unchanged and stays prose. Nothing about the dual purpose needs a write-side
control, because the reader the merge gate specifies already discriminates: `references/merge-gate.md`
part 4 selects the latest complete block *that carries a `MERGE-READY` line for `HEAD_SHA`*, not the
latest complete block simpliciter, and **the `jq` printed in part 4 itself** applies all three tests
before `last`. A park note therefore cannot revoke a valid hand-off through that reader, and the
helper does not change that.

The claim is bounded to that reader deliberately, because it does not hold of every reader part 4
mentions. Part 4 also directs readers to "the quest-log skill's selection rules", and quest-log's
general latest-complete recipe (`skills/quest-log/SKILL.md:523-530`) tests only the two markers —
it carries no `MERGE-READY` discriminator, so a park note posted after a hand-off *is* what `last`
returns there. That divergence between part 4's own `jq` and the recipe it points at is a defect in
the reader, not in this helper, and it is left to issue #235, which owns what the gate checks. It is
recorded here rather than silently relied past.

The helper computes the SHA from `git ls-remote origin` and requires GitHub's `headRefOid` to
agree, refusing when they differ. It asserts the gate's four whole-line conditions twice: once
against the body it composed, before anything is posted, and again against the body GitHub stored,
re-read through the API. The first makes `--preflight` mean something and stops a composition
defect from being published at all; only the second says what the gate will read.

**It corroborates the write destination before composing, from a source other than the argument it
is checking.** The issue number decides where the block lands, and every check after the write is
derived from that same argument — the expected comment-URL prefix is composed from it, and the
readback path is taken from the id in that URL — so no post-write check can detect it being wrong.
Resolving the issue and asking whether it exists and is an issue does not help either: those
questions are answered by the resource the argument selected, so a transposed but valid number
passes them.

The independent source is the pull request. The helper requires `ISSUE` to appear in the pull
request's `closingIssuesReferences`, read from the `gh pr view --json` call it already makes. That
binding runs from the pull request to the issue, so it does not inherit the argument under test. It
also requires the resolved resource not to be a pull request — GitHub's issues API serves pull
requests from the same number space and returns them with a `pull_request` key ordinary issues
lack, and a pull request number may legitimately appear in no closing-reference list, so the two
checks catch different mistakes. A pull request declaring no closing issue is refused as
uncorroborated.

**This ships an executable, so CLAUDE.md anatomy rule 2 has to be satisfied explicitly.** The bar
is that a script does "something a model cannot do reliably inline". The ground here is the rule's
second limb — performed inconsistently — and the evidence is the four holds issue #308 logs, from
three different agents, on work that was finished and green every time. It is not the first limb:
the block is short and composing it costs almost no context. What a model cannot do reliably is
emit the same handful of bytes correctly on every occasion.

## Consequences

- Three of the four logged defects are closed by construction: the caller no longer writes the
  sentinel, the handshake, or the markdown around them.
- The fourth — a worker dying mid-hand-off — is narrowed rather than closed. A dead process cannot
  be finished by the program it failed to run. What changes is that the hand-off becomes one
  command instead of several model actions across turns, and that re-running is the whole remedy:
  every run appends a fresh complete block, so latest-complete-wins resolves a duplicate.
- A disagreement between the remote tip and `headRefOid` now blocks the hand-off. That is a new
  refusal, and it is the intended one: it is precisely the moment the SHA a handshake would bind is
  already stale.
- That agreement binds the two reads to each other, not to merge time; and a nonzero exit does not
  by itself mean nothing was published. Both residuals, and the one exit whose remedy is *not*
  re-running, are stated once in the specification's *What this does and does not close*. They are
  not restated here: this record governs the decision, the specification owns the residuals, and
  four copies of a residual is the drift this record elsewhere accepts having created once already.
- **The helper becomes a second encoding of the gate's byte-level contract, and ADR 0042's drift
  concern now reaches it.** 0042 centralized the gate in one reference precisely because copies
  cannot be held in agreement — anatomy rule 4 forbids a gate that compares prose, so nothing
  automated can detect the divergence. This helper hardcodes the two markers and the handshake
  shape, so a change to `references/merge-gate.md` part 4 silently desynchronizes it. That is a real
  new drift surface and it is accepted rather than solved: the alternative is parsing the normative
  prose at runtime, which is the prose-assertion anatomy rule 4 exists to forbid. **What it is not
  is bounded.** An earlier draft of this bullet claimed the divergence "fails closed" and was
  therefore loud; that is wrong, and the correction matters. If part 4's byte contract changes and
  this helper does not, the helper still exits 0 on a block the gate no longer selects — silent on
  the writer's side, and on the reader's side indistinguishable from a worker that never handed
  off. That is precisely the pre-change symptom this record exists to remove, reproduced by the
  mechanism meant to remove it. Nothing automated can detect it, because rule 4 forbids the only
  check that would. The mitigation is procedural and stated as such: a change to
  `references/merge-gate.md` part 4 must change this helper in the same pull request. Issue #235,
  which owns what the gate checks, is the anticipated trigger.
- Park notes keep the sentinel-omission exposure the hand-off just lost. That is a real residual,
  not an oversight, and it is left as accepted exposure rather than absorbed here: a park note
  losing its sentinel makes a parked issue read as unparked, which a reader recovers from by
  opening the issue — where the hand-off case had no such recovery, because the gate reads bytes
  and no one reads the gate.
- A wrong issue number can no longer publish a complete block somewhere nobody reads. Without the
  destination binding the helper would exit 0 printing a verified URL for a complete block on the
  wrong issue, while the orchestrator's gate read the right issue and found none — reaching, with a
  success status, the exact symptom this record exists to make unreachable, and reaching it where
  re-running cannot help because latest-complete-wins never visits an issue nobody wrote to.
- **A pull request with no `Closes #<n>` trailer can no longer be handed off.** That is a new
  refusal and a real narrowing. Its ground is this helper's own requirement that the destination be
  corroborated before composing, not any rule in `references/merge-gate.md`, which imposes no
  closing-reference requirement at all. The remedy is the caller's and the message names it.
- **The helper runs from the plugin cache but against the consumer's checkout, and the two are
  different directories.** `$CLAUDE_PLUGIN_ROOT` locates the executable; the process working
  directory must remain the checkout whose `origin` is the repository being handed off, because
  that is what `git ls-remote origin` reads. `$return-to-town` already depended on such a checkout
  to read the SHA — the helper makes the requirement explicit and names it in its own failure
  message. A call site written as a repository-relative path satisfies neither half: it does not
  resolve from the consumer's working directory, so the hand-off would fall back to hand
  composition and the change would deliver nothing outside this repository.
- **A pull request opened from a fork cannot be handed off by this helper**, and that is a narrowing
  rather than a bug it hides. No single checkout has the upstream as `origin` and the fork's head
  under `refs/heads/`, so the SHA read cannot be satisfied at all. The helper reads
  `isCrossRepository` and refuses by name, before the remote read — because after it a fork is
  indistinguishable from a moved branch, and "re-run once the branch settles" would be a permanent
  refusal wearing a transient message. This repository's own work is branch-based, so nothing here
  is affected; a repository taking fork pull requests would need a different SHA source.

## Considered & rejected

- **An exact invocation written into `skills/return-to-town/SKILL.md`, shipping no executable.**
  judgment: this is the rung anatomy rule 2 exists to force, and it fails on its own terms. A
  fenced command block is still text the model must transcribe, and mis-transcription is the shared
  root of three of the four logged defects — the fourth is a worker that died mid-hand-off, which
  the Consequences above record as narrowed rather than closed, and which no inline block reaches
  either. So the inline route reintroduces the failure one step earlier for the three it does
  reach. The 40-character SHA read, the two-source corroboration, and the readback assertions do
  not fit an inline block honestly either.
- **A general `post-annotation` helper covering every `WORK:*` type.** judgment: the remaining
  types would gain markers-and-sentinel only, which is two `printf` calls at each call site, and
  three of the four other annotation types in quest-log's table are written by skills this change
  does not own. What this bullet must not claim is that the hand-off is the only type with a
  mechanical contract a helper can assert — `WORK:REVIEW` has one and `publish-forge-review`
  already asserts it.
- **A `--kind hand-off|park` mode flag on one helper.** judgment: the flag is itself the confusion
  surface. A park note that acquired a handshake would authorize a merge of work that is parked —
  strictly worse than the defect being fixed — and the flag is the only way that becomes reachable.
- **A validator the caller runs against a body it composed itself.** judgment: issue #308 records
  that a validator would catch three of the four logged defects; the one it misses is the dead
  worker, which this decision also misses. Coverage is therefore not the discriminator — prevention
  against detection is. A validator tells a competent agent it composed the wrong bytes; composition
  denies it the chance to. The issue prefers composition for that reason.
- **Extend `skills/quest/scripts/publish-forge-review` with a hand-off mode.** verified: it posts
  with `gh pr comment`, and `WORK:TRAJECTORY` is issue-side per `skills/quest-log/SKILL.md`'s
  annotation table; only the readback endpoint `/repos/.../issues/comments/<id>` is shared. Its
  mode-0600 private-file and recoverable-disposal apparatus exists for sensitive review payloads,
  which a hand-off block does not carry.
- **Trust `headRefOid` and skip `git ls-remote`.** verified: `skills/return-to-town/SKILL.md`
  already requires the SHA to come from `git ls-remote origin "refs/heads/<branch>" | cut -f1` and
  says "never `headRefOid`, never an abbreviation".
- **Assert the conditions against the composed body *instead of* the stored one.** judgment: only
  GitHub's copy can show a transport or storage difference, so the stored-side assertion is the one
  that cannot be dropped. But "instead of" was the wrong framing and is rejected in both directions:
  the composed body is not an input already known to be correct — the premise of this whole record
  is that a composer's output must be verified rather than trusted, and that applies first to this
  script's own. Both run, and the compose-side pass is three `grep` calls against a local file.
- **Validate the issue number for syntax only, and treat a wrong-but-well-formed one as the
  caller's problem.** verified: this was the first draft's behaviour and it is unsound, because the
  helper's own success signal is derived from the unchecked argument. `read_stored_body` builds its
  expected prefix as `https://github.com/$repo/issues/$issue#issuecomment-` from the same value it
  would need to be checking, so the URL match, the id extraction, the readback and all four stored
  assertions pass on the wrong issue. Exit 0 would then be a true statement about the wrong
  destination, which is a worse failure than the one being fixed: it is silent on the writer's side
  *and* on the reader's.
- **Reject a pull request number by checking the comment URL after posting.** verified:
  `gh api /repos/randomparity/adept/issues/374` returns pull request #374 carrying a `pull_request`
  key, observed on this repository at gh 2.100.0 — the `/issues/<n>` space is shared, so
  `gh issue comment <pr-number>` addresses a resource that does exist and the comment is created
  before anything can object. The failure would surface as a
  malformed-URL message one step after the write — the same one-actor-away misdiagnosis this record
  exists to remove, with a stray comment on the pull request as a side effect. Checking
  `pull_request` on the resource before composing costs one API read and refuses by name.
- **Do nothing.** verified: four holds across four hand-offs in one campaign run, from three
  different worker agents, every one an annotation defect on work that was finished and green
  (issue #308's table). Three further recurrences of the same shape have been logged on the issue
  since, at v5.7.4, from workers dispatched independently.
