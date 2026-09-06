# 0056 — Compose the hand-off handshake, and only the hand-off

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

## Decision

Ship one helper, `skills/return-to-town/scripts/publish-handoff`, that composes **only** the merge
hand-off block. It has a single mode. It always emits both markers and the handshake line, and it
rejects a narrative file that carries either marker or the token `MERGE-READY:` anywhere in it.
There is no flag selecting a different block shape.

The park path is unchanged and stays prose. Nothing about the dual purpose needs a write-side
control, because the read side already discriminates: `references/merge-gate.md` part 4 selects the
latest complete block *that carries a `MERGE-READY` line for `HEAD_SHA`*, not the latest complete
block simpliciter, and its `jq` applies all three tests before `last`. A park note therefore cannot
revoke a valid hand-off today, and the helper does not change that.

The helper computes the SHA from `git ls-remote origin` and requires GitHub's `headRefOid` to
agree, refusing when they differ. It asserts its five conditions against the comment body GitHub
stored, re-read through the API, not against the body it composed.

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
- That agreement binds the two reads to each other, not to merge time. A push to the head branch
  after the hand-off leaves a complete block the gate will not select, and exit 0 does not survive
  that — it asserts the bytes GitHub stored, never that the SHA is still the tip. The remedy is
  re-running, which appends a fresh block for the new head. Nothing binds the head before
  `--match-head-commit`, so no writer-side control can do better and none is added.
- Exit 1 does not mean nothing was published. Three conditions are checked after the comment is
  created, and a comment the helper composed is gate-valid whether or not the readback succeeded.
  The message names which condition failed, and the remedy is the same either way: re-run.
- Park notes keep the sentinel-omission exposure the hand-off just lost. That is a real residual,
  not an oversight, and it is left as accepted exposure rather than absorbed here: a park note
  losing its sentinel makes a parked issue read as unparked, which a reader recovers from by
  opening the issue — where the hand-off case had no such recovery, because the gate reads bytes
  and no one reads the gate.
- `$return-to-town` gains a dependency on a checkout whose `origin` is the repository being handed
  off. It already required one to read the SHA; the helper makes the requirement explicit and names
  it in its own failure message.

## Considered & rejected

- **A general `post-annotation` helper covering every `WORK:*` type.** judgment: of the five
  annotation types, only the hand-off has a mechanical contract a helper can assert; the rest would
  get markers-and-sentinel only, which is two `printf` calls at each call site. Three of the five
  are written by skills this change does not own.
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
- **Assert the conditions against the composed body instead of the stored one.** judgment: the
  composed body is the one input already known to be correct; what the gate reads is GitHub's copy,
  and only that copy can show a transport or storage difference.
- **Do nothing.** verified: four holds across four hand-offs in one campaign run, from three
  different worker agents, every one an annotation defect on work that was finished and green
  (issue #308's table).
