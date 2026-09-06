# Hand-off handshake helper — design

Decision record: [ADR 0056](../../adr/0056-compose-the-handoff-handshake.md).

## Goal

`$return-to-town` composes the merge hand-off annotation by hand, in prose. Replace that
composition with one executable that composes the block, computes the head SHA itself, posts the
comment, and asserts every condition the merge gate checks against the copy GitHub stored.

Scope is the merge hand-off block alone. The park protocol writes the same block type and is not
changed here; see the decision record.

## Context

`references/merge-gate.md` part 4 admits a hand-off only when a comment satisfies three anchored
conditions at once:

- `^<!-- WORK:TRAJECTORY -->$` as a whole line,
- `^<!-- TRAJECTORY:COMPLETE -->$` as a whole line,
- `^MERGE-READY: #<PR> @ <sha>$` as a whole line, where `<sha>` is the gate's own `HEAD_SHA`.

`skills/return-to-town/SKILL.md:72-83` is the sole composer of that block today and is entirely
prose: *"Add a whole line reading `MERGE-READY: #<N> @ <HEAD_SHA>`"*, *"Read the complete comment
back and verify the markers"*. Nothing checks the bytes before they are posted.

Issue #308 records what that costs. In one `$campaign` run over three issues, every merge was held
at least once and every hold was an annotation defect rather than a code or CI problem — four holds
across four hand-offs, from three different worker agents:

| Hand-off | Defect |
|---|---|
| Issue A | handshake wrapped in backticks |
| Issue B, 1st | opening marker emitted, closing sentinel never emitted |
| Issue B, 2nd | same block reposted, sentinel still absent |
| Issue C | worker died mid-hand-off; no handshake at all |

The failure is silent where it occurs and surfaces one actor away, in the orchestrator's gate, as
"zero matching blocks" — indistinguishable from "the worker never handed off". Markdown makes the
backtick case especially easy: wrapping a SHA in backticks is the natural way to write it and
renders identically to a reader while defeating an anchored regex.

A directly comparable helper already ships. `skills/quest/scripts/publish-forge-review` composes,
posts, and byte-verifies the `WORK:REVIEW` annotation for the same reasons.

## Requirements

**R1 — the helper owns the whole block.** The caller supplies only the hand-off narrative. The
helper emits the opening marker, the narrative, the handshake line, and the closing sentinel, each
line written by the helper. The caller cannot omit the sentinel, because the caller does not write
it.

**R2 — the helper owns the handshake line.** The helper composes
`MERGE-READY: #<PR> @ <sha>` itself, as a bare whole line: no fence, no backticks, no list marker,
no leading or trailing whitespace, no carriage return. A narrative file containing the token
`MERGE-READY:` **anywhere** — at a line start, inside backticks, or mid-sentence — is rejected
before anything is posted. The scan is a substring scan, not a line-anchored one, and the
difference is the whole point: the defect it closes wrapped the handshake in backticks, which no
anchored pattern sees, and in a list item or indented block it does not begin its line at all. The
narrative has no legitimate reason to carry the token, and a copy of it would either duplicate the
helper's line or contradict its SHA, with no way to tell which was intended.

The marker rejection in R1 is deliberately the opposite shape — whole-line only. A backticked
marker in the narrative is harmless, because the helper writes the real one on its own line
regardless.

**R3 — the helper computes the SHA.** The SHA is read from
`git ls-remote origin "refs/heads/<head-branch>"`, per `skills/return-to-town/SKILL.md:79-82`:
never `headRefOid`, never an abbreviation. The head branch is read from the pull request rather
than supplied by the caller, so the SHA is bound to the PR by construction. The value must be
40 lowercase hex characters.

**R4 — GitHub's `headRefOid` corroborates but never supplies.** The helper reads `headRefOid` as a
second, independent observation and requires it to equal the `ls-remote` value. A disagreement means
the branch moved between the two reads, which is exactly the moment a handshake must not be posted;
the helper refuses and names the two SHAs. The value posted is always the `ls-remote` one.

**R5 — the assertions run against the stored copy.** After posting, the helper re-reads the comment
through `/repos/<repo>/issues/comments/<id>` and asserts, against those bytes:

1. the opening marker as a whole line,
2. the closing sentinel as a whole line,
3. the handshake as a whole line for this PR and this SHA,
4. no carriage-return byte anywhere in the body,
5. byte-for-byte equality with the body the helper composed.

Assertions 1–4 exist for their diagnostics; 5 is the catch-all. Checking the composed body instead
would prove nothing about what the gate will read.

**R6 — every failure names its condition.** A nonzero exit is accompanied by a message naming the
condition that failed, not a generic one. "Which of the three conditions failed" is what the
orchestrator currently has to diagnose by re-reading the stored body.

**R7 — the block is issue-side.** `skills/quest-log/SKILL.md:307` puts `WORK:TRAJECTORY` on the
issue. The helper posts with `gh issue comment`, and reads back through the shared
`/repos/.../issues/comments/<id>` endpoint.

**R8 — a preflight mode.** `--preflight` runs every argument, narrative, SHA-resolution, and
composition check, makes no comment, and prints `preflight-ok`. It exists so a caller can learn
that its narrative is unpublishable while that is still a local failure, the same separation
ADR 0048 drew for `publish-forge-review`.

**R9 — the body passes the repository's public-safety gate.** The composed body is posted to a
public issue. `scripts/check-public-safety.sh` already scans for absolute user paths, private
addresses, and credential shapes; the helper runs it on the composed body rather than growing its
own patterns.

**R10 — retry is safe by construction.** The helper only ever appends a fresh complete block.
Latest-complete-wins (`skills/quest-log/SKILL.md:296-298`) makes a second successful run supersede
a first, so a caller that cannot tell whether its previous invocation completed may simply run it
again. Nothing reads, modifies, or deletes an existing comment.

## What this does and does not close

Three of the four logged defects are closed by construction: the helper writes the sentinel (R1),
writes the handshake (R2), and cannot write it inside backticks because it does not write markdown
around it.

The fourth — a worker that died mid-hand-off — is **narrowed, not closed**, and the spec says so
rather than inheriting the issue's claim that a helper "could not produce any of the four defects".
A dead process cannot be resurrected by the program it failed to finish running. What changes is
the width of the window and the ambiguity of what it leaves:

- today the hand-off is several model actions across turns — compose, post, read back, verify — and
  death between any two leaves a half-written state a successor must diagnose;
- with the helper it is one command that either exits 0 having verified the stored bytes, or does
  not. Death before it leaves nothing posted; death during it leaves at most one unverified comment,
  and R10 makes the successor's remedy "run it again" rather than "work out what the corpse did".

Two further limits, stated here rather than left to be discovered.

**Exit 0 is not a promise about merge time.** R4's agreement binds the `ls-remote` read and the
`headRefOid` read to each other; it binds neither to the moment the gate later computes its own
`HEAD_SHA`. If the head branch moves after the hand-off — a CI fixup, a review commit — the posted
block is complete, both markers anchored, and invisible to the gate's selection, which admits only a
block carrying a line for the gate's `HEAD_SHA`. Exit 0 asserts the bytes GitHub stored, never that
the SHA is still the tip. The remedy is R10. No writer-side control can do better, because nothing
binds the head before `gh pr merge --match-head-commit`, so none is added.

**Exit 1 does not imply nothing was published.** Three of the failure conditions below are checked
after the comment is created — a failed readback, a stored copy differing from the composed one, and
the three whole-line assertions. A comment the helper composed is gate-valid whether or not the
readback succeeded, so an exit 1 from that side leaves a usable hand-off on the issue. The message
names which condition failed, and the remedy is the same on either side of the post: re-run.

**Assertion 5's evidence class.** No GitHub documentation guarantees that an issue comment's body
round-trips byte for byte, and it is not checkable without posting to a live issue. The evidence is
the shipped precedent — `skills/quest/scripts/publish-forge-review` runs the identical
`jq -e --rawfile expected` equality against a newline-terminated body in production — plus the
observation that bodies submitted through the web UI come back CRLF-normalized while API-posted LF
bodies do not, which is why assertion 4 exists as a separate diagnostic. If the assumption ever
fails, it fails loudly and specifically at assertion 5 rather than silently, which is the correct
direction for an unverifiable premise.

## Interface

```
publish-handoff [--preflight] REPO ISSUE PR NOTES
```

- `REPO` — `owner/name`.
- `ISSUE` — the issue the hand-off is recorded on.
- `PR` — the pull request being handed off.
- `NOTES` — path to a file holding the hand-off narrative: the `outcome:` line, guardrail status,
  and any surprises. Markers, sentinel, and handshake are not the caller's to write.

On success the sole stdout line is the verified comment URL. The exit taxonomy is the one the
repository's other executables use: 0 success, 1 a condition failed, 2 the helper could not run.
Exit 1 before the comment is posted means nothing was published; exit 1 after it means a complete
block may be on the issue and merely unverified here. The distinction is carried by the message,
which names the condition, and the remedy is the same either way — re-run, per R10.

## Failure modes and their messages

| Condition | Message names |
|---|---|
| `REPO` not `owner/name`, `ISSUE`/`PR` not a positive integer | the invalid argument |
| notes file missing, unreadable, empty, or not a regular file | the path |
| notes not UTF-8, or carrying NUL or CR | which byte class |
| notes carrying a whole-line `<!-- WORK:TRAJECTORY -->` or `<!-- TRAJECTORY:COMPLETE -->` | which marker |
| notes mentioning `MERGE-READY:` anywhere | that the helper owns that line |
| notes over the size cap | the cap |
| pull request not `OPEN`, or its number disagrees | the observed state |
| `git ls-remote` returning no line, several lines, or a non-SHA | what it returned |
| `ls-remote` SHA ≠ `headRefOid` | both SHAs, and that the branch moved |
| composed body failing public-safety | that it did not pass |
| `gh issue comment` failing | that the comment was not created |
| comment URL not parseable for this repo and issue | the URL |
| readback request failing | that the stored copy could not be read |
| stored copy missing the opening marker | that marker, by name |
| stored copy missing the sentinel | that sentinel, by name |
| stored copy missing the handshake | the expected line, verbatim |
| stored copy carrying CR | that a carriage return reached the stored body |
| stored copy ≠ composed body | that GitHub's copy differs |

## Threat model

The helper posts to a public repository and reads a caller-supplied file, so it crosses a trust
boundary and this section is required.

**Boundaries added.** One: the narrative file, read from the filesystem and composed into a body
that is published. **Boundaries widened.** None — `$return-to-town` already posts this comment; the
helper changes who composes it, not who may post it.

**Actor model.** The caller is a model running inside the operator's own session with the
operator's `gh` credentials. It is not an untrusted party, and the helper does not pretend
otherwise: anything the caller could pass to the helper it could equally post with `gh issue
comment` directly. The narrative is treated as *unreliable* rather than hostile — the failure being
fixed is a competent agent composing the wrong bytes, not an adversary composing malicious ones.
The genuinely untrusted input is GitHub's response, which the helper parses.

**Control per boundary.**

- *Narrative file → composed body.* Validation: regular file, readable, non-empty, UTF-8, no NUL,
  no CR, under the size cap, no whole-line outer marker, no `MERGE-READY:` line. Then
  `scripts/check-public-safety.sh` over the composed result, which is the repository's existing
  control for exactly this — content leaving for a public destination. Nothing is executed and
  nothing is interpolated into a shell command; the body reaches `gh` as `--body-file`.
- *Comment URL → API path.* The URL is matched against the exact expected prefix for this repo and
  issue, and the remainder must be digits only before it is placed in a REST path. This is the
  control `publish-forge-review` already applies, for the same reason: the id becomes a path
  segment.
- *`gh pr view` JSON → head branch name.* The branch name is passed to `git ls-remote` as a
  `refs/heads/` argument, never interpolated into a shell string, and the SHA that comes back must
  match `^[0-9a-f]{40}$` before it is composed into the handshake.

**Explicitly out of scope.** Authentication and authorization: the helper runs whatever `gh` is
configured with and asserts nothing about who that is. The merge gate, not this helper, pins the
expected account — `references/merge-gate.md:108-116` requires the comment's author to be the PR's
author or hold write permission, and that check stays where it is because it protects the *reader*
from a forged hand-off, which no writer-side control can do. Also out of scope: a caller that posts
the comment itself and never invokes the helper. Nothing prevents that, and nothing here tries to;
the helper makes the correct path easy, it does not make the manual path impossible.

## Testing

A behaviour suite under `tests/fixtures/return-to-town/`, outside the shipped tree per the
repository's layout rule, with a fake `gh` on `PATH` driven by a mode variable and a **real** local
git repository with a bare remote — `git ls-remote` is exercised for real rather than stubbed,
because the SHA it returns is the value the whole contract turns on.

The suite covers one case per row of the failure table above bar one, plus the happy path, the
preflight path, and one regression case per logged defect in issue #308.

The exception is stated rather than left to be discovered. Two rows are guards on the parse of
GitHub's and git's responses rather than reachable conditions. *Several refs for one head branch* is
reachable only through a branch name containing a glob character, which GitHub will not return —
but it is testable, because the fake controls the name, so it has a case. *A non-SHA from
`ls-remote`* is not reachable at all without faking `git`, and faking `git` would forfeit the
property this suite is built around: that the SHA the contract turns on is read from a real remote.
That guard therefore ships without a case, deliberately, and this sentence is the record of why.

The regression cases:

- a narrative that wraps the handshake in backticks is rejected (defect 1),
- a stored copy returned without its sentinel fails the readback with the sentinel named
  (defects 2 and 3),
- a second invocation after an unverified first posts a fresh complete block and succeeds
  (defect 4's remedy, R10).

Each new assertion is verified to bite: the fault is introduced, red is observed, and the fault
reverted.

## Non-goals

- What the merge gate should *check* — issue #235 owns that, and issue #308 distinguishes it
  explicitly.
- A general `WORK:*` annotation helper. See the decision record.
- Changing the park protocol, whose block is written by `$quest`'s *On a Blocker* section.
- Changing `references/merge-gate.md`. The reader side already discriminates correctly.
