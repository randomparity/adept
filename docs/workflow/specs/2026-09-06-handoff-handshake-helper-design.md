# Hand-off handshake helper — design

Decision record: [ADR 0066](../../adr/0066-compose-the-handoff-handshake.md).

## Goal

`$return-to-town` composes the merge hand-off annotation by hand, in prose. Replace that
composition with one executable that composes the block, computes the head SHA itself, asserts every
condition the merge gate checks against what it composed, posts the comment, and asserts them again
against the copy GitHub stored.

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

**R5 — the gate's byte-level conditions are asserted twice, on both copies.** Part 4 has five
requirements. Four are byte-level conditions on the body and are asserted here; the fifth pins the
comment's **author** to the pull request's author or a login with write permission, and is asserted
by the reader, not by this helper — it protects the reader from a forged hand-off, which no
writer-side control can do. Wherever this design says a block is gate-valid, it means the four
below hold, never that the fifth does.

The four:

1. no carriage-return byte anywhere in the body,
2. the opening marker as a whole line,
3. the closing sentinel as a whole line,
4. the handshake as a whole line for this PR and this SHA.

The CR check runs first of the four, because a CR on every line defeats the other three at once and
reporting "missing the opening marker" of a body whose opening marker is right there is the same
misdiagnosis the helper exists to remove.

They are checked **on the composed body, before anything is posted** — which is what makes
`--preflight` mean what R8 says, and what stops a composition defect from being published and only
then detected. They are checked **again on the stored copy**, after posting, plus a fifth:

5. byte-for-byte equality with the body the helper composed.

Neither pass substitutes for the other. Only the stored copy can show a transport or storage
difference, so the second pass cannot be dropped; and only the first pass can prevent an
unselectable block from reaching the issue at all, so neither can it. Asserting solely on the
composed body would be trusting this helper's own output — the exact trust the change exists to
withdraw from its caller.

**R6 — every failure names its condition.** A nonzero exit is accompanied by a message naming the
condition that failed, not a generic one. "Which of the gate's conditions failed" is what the
orchestrator currently has to diagnose by re-reading the stored body.

**R7 — the block is issue-side.** `skills/quest-log/SKILL.md:441` puts `WORK:TRAJECTORY` on the
issue. The helper posts with `gh issue comment`, and reads back through the shared
`/repos/.../issues/comments/<id>` endpoint.

**R8 — a preflight mode.** `--preflight` runs every argument, narrative, destination, SHA-resolution
and composition check — including R5's four gate conditions on the composed body — makes no comment,
and prints `preflight-ok`. `preflight-ok` therefore means the block the helper will compose
satisfies every byte-level condition the gate checks on the body, not merely that the narrative was
acceptable. It says nothing about part 4's author requirement, which is the reader's.

It follows ADR 0048's separation — learn that a publication is impossible before attempting
it — but **not** that record's stronger property, and the divergence is stated here rather than
left to be discovered. `publish-forge-review`'s preflight is purely local: it validates and
composes and makes no network call, so a preflight failure there is always a local failure. This
preflight cannot be local, because three of the things it must check are remote — the destination
resource, the pull request's state and head branch, and the remote tip that supplies the SHA. It
therefore makes read-only network calls and creates nothing. What it preserves is the part that
matters to a caller: no comment exists after a failed preflight, so the failure is recoverable
without an artifact on a public issue. What it cannot promise is that a preflight failure means the
network was never touched, and the requirement does not claim it.

**R9 — the body passes the repository's public-safety gate.** The composed body is posted to a
public issue. `scripts/check-public-safety.sh` already scans for absolute user paths, private
addresses, and credential shapes; the helper runs it on the composed body rather than growing its
own patterns.

That gate has a **three-way** status — 0 clean, 1 a finding, 2 it could not run — and the helper
routes all three. Collapsing 2 into 1 would report a scanner that never ran as one that found a
credential: a permanent refusal wearing a transient message, which no amount of re-running clears.

This is not a principle invented here. `CLAUDE.md` states it directly — capture a scan's exit status
explicitly rather than trailing `|| true`, because a tool exits 1 for "no matches" and greater than 1
for a real failure, and collapsing those makes a scan that could not run read as one that found
nothing. The repository hard-gates it for its own scripts (`just scan-fault-check`,
`scripts/check-scan-fault-discards.sh`), and a chain of accepted records develops it:
`docs/adr/0005-scan-faults-are-reported-not-collapsed.md` first decided it and is now superseded
through `0024` to **`docs/adr/0025-a-skip-reports-the-condition-not-the-cause.md`**, which is the
live record. The first draft of this helper breached the rule; the routing above is the
correction.
Status 2 is a fault (exit 2) naming that the scan did not run, and the gate's own stderr is passed
through rather than discarded, because on that branch it is the only text that says why. The helper
also requires `rg` in its own preflight, since that gate exits 2 without it — refusing at the
preflight names the missing binary, which the gate's fault status cannot.

**R10 — retry is safe by construction.** The helper only ever appends a fresh complete block.
Latest-complete-wins (`skills/quest-log/SKILL.md:523-530`) makes a second successful run supersede
a first, so a caller that cannot tell whether its previous invocation completed may simply run it
again. Nothing reads, modifies, or deletes an existing comment.

**R11 — the write destination is corroborated before composing.** The issue number decides where
the block lands, and it is the one argument whose correctness nothing downstream can check: the
expected comment-URL prefix is composed from it and the readback path is taken from the id in that
URL, so the URL match, the id extraction, the readback, and all four stored assertions in R5 pass
just as readily on the wrong issue. A transposed or stale number would therefore publish a
complete, gate-valid block where nobody reads, and the helper would exit 0 printing a verified URL
for it — reaching, with a success status, the exact symptom this change exists to make unreachable.
R10's remedy does not apply, because latest-complete-wins never visits an issue nobody wrote to.

**The corroboration must come from somewhere other than the `ISSUE` argument, or it corroborates
nothing.** Resolving the issue and asking whether it exists, reports the number requested, and
lacks a `pull_request` key establishes only that `ISSUE` names *an* issue — every one of those
questions is answered by the resource `ISSUE` selected. A transposed but valid number, which is the
likeliest form of the mistake, passes all three and lands the block on a real, open, wrong issue.

The independent source is the pull request. The helper reads `closingIssuesReferences` from the
`gh pr view --json` call it already makes for R3, and requires `ISSUE` to be among the numbers it
reports. That binding runs from the pull request to the issue, so it does not inherit the argument
it is checking: a caller who types the wrong issue number is refused by a fact the pull request
asserts about itself. `$deliver` writes `Closes #<issue-number>` into the body of every
issue-backed pull request, and this repository already reads the same field for the same purpose in
`skills/campaign/SKILL.md` and `skills/counterspell/SKILL.md`.

The helper therefore requires, in order:

1. `closingIssuesReferences` contains `ISSUE` — the check that catches a transposition;
2. the resolved resource is not a pull request — the check that catches a swapped `ISSUE`/`PR`,
   which the first cannot, because a pull request number may legitimately appear nowhere in that
   list and the failure would otherwise surface after the write as an unparseable URL;
3. the resource exists and reports the number requested.

**A pull request that declares no closing issue is refused, and the ground is stated honestly.**
It is *not* that the merge gate rejects such a pull request — `references/merge-gate.md` imposes no
closing-reference requirement, and a design that claimed otherwise would be asserting a contract
the reference does not contain. The ground is narrower: the helper's own completion criterion is
that the destination is corroborated before composing, an empty list leaves it uncorroborated, and
this helper's consistent stance is to refuse rather than publish something it cannot check. The
remedy is in the caller's hands and the message says so — add the `Closes #<issue-number>` trailer
the pull request was expected to carry. `skills/campaign/SKILL.md` records a missing reference and
defers it; this helper cannot, because deferring means publishing.

What this closes and what it does not: a transposed issue number, a swapped `ISSUE`/`PR` pair, and
a nonexistent resource are all refused before composition. A pull request whose `Closes` trailer is
itself wrong would corroborate the wrong issue — the binding is only as good as the trailer, and no
writer-side control can do better without a second independent statement of intent, which nothing
in the repository produces.

**R12 — the documented invocation resolves for a consumer.** This project ships only as a plugin:
the harness copies the whole repository into the plugin cache, so at run time the helper lives
under the plugin root while the calling agent's working directory must be the *consumer's*
checkout — it has to be, because R3 reads the head SHA with `git ls-remote origin` from there. The
call site written into `skills/return-to-town/SKILL.md` therefore resolves the executable through
`${CLAUDE_PLUGIN_ROOT}`, per `skills/quest-log/SKILL.md`'s resolution rule, which the same file
already follows elsewhere. A repository-relative path satisfies neither half: it does not exist at
the consumer's working directory, so the command fails at exec and the hand-off falls back to hand
composition — the change would deliver nothing outside this repository. The step states the
working-directory requirement alongside the path, because the two are different directories and
only naming one of them is what makes the mistake easy.

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
the three whole-line assertions. A comment the helper composed satisfies the four byte-level
conditions whether or not the readback succeeded, so an exit 1 from that side leaves a usable
hand-off on the issue. The message names which condition failed.

**The remedy for a nonzero exit is to re-run — except where the message says otherwise, and exactly
one condition says otherwise.** That condition is assertion 5's, described immediately below:
re-running it reproduces the same failure forever while appending another complete block each time.
Every other nonzero exit, on either side of the post, is re-run. The rule is stated in this
qualified form everywhere it appears — here, in the Interface section, in the decision record, and
in the `SKILL.md` text the plan writes — because a blanket "re-run on nonzero" instruction sends a
caller into an unbounded loop of public comments at the one exit that must not be retried.

**Assertion 5's evidence class, and what to do when it fails.** No GitHub documentation guarantees
that an issue comment's body round-trips byte for byte, and it is not checkable without posting to a
live issue. The evidence is a shipped precedent that is *adjacent* rather than identical:
`skills/quest/scripts/publish-forge-review` runs the same `jq -e --rawfile expected` equality
against a newline-terminated body in production — but it writes with `gh pr comment`, and this
helper writes with `gh issue comment`. Only the readback endpoint is shared. The write path is
assumed to behave the same and is not evidenced. Alongside that, and **assumed on the same terms
rather than evidenced**: bodies submitted through the web UI are believed to come back
CRLF-normalized while API-posted LF bodies do not. No command here establishes that, and condition 1
exists as a separate diagnostic whether or not it holds — a CR defeats all three whole-line
patterns at once, so it earns its own message regardless of how it got there.

The disposition matters more than the premise. If assertion 5 ever fails while conditions 1–4 pass
on the stored copy, a **gate-valid block is on the issue** — it is selectable and the hand-off has
in fact succeeded. Re-running would reproduce the identical failure forever while appending another
complete block, so re-running is the wrong remedy here and the only place in this design where it
is. The helper's message says so: inspect the stored comment and proceed. This is the one exit where
R10 does not apply.

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
`REPO` is always host-qualified to `github.com` internally, at the write as well as the readback —
`publish-forge-review`'s convention. A bare `owner/name` at the write would resolve against `gh`'s
configured default host, so on a workstation defaulting to an Enterprise instance the comment would
be created on one host and looked for on another.
Exit 1 before the comment is posted means nothing was published; exit 1 after it means a complete
block may be on the issue and merely unverified here. The distinction is carried by the message,
which names the condition. The remedy is re-running, per R10, unless the message says otherwise —
assertion 5's is the one exit that says otherwise, and it says to inspect the stored comment and
proceed.

## Failure modes and their messages

| Condition | Message names |
|---|---|
| `REPO` not `owner/name`, `ISSUE`/`PR` not a positive integer | the invalid argument |
| notes file missing, unreadable, empty, or not a regular file | the path |
| notes not UTF-8, or carrying NUL or CR | which byte class |
| notes carrying a whole-line `<!-- WORK:TRAJECTORY -->` or `<!-- TRAJECTORY:COMPLETE -->` | which marker |
| notes mentioning `MERGE-READY:` anywhere | that the helper owns that line |
| notes over the size cap | the cap |
| `ISSUE` not among the pull request's closing references | `ISSUE`, what the pull request does close, and that one of them is wrong |
| pull request declaring no closing issue at all | that the destination cannot be corroborated, and the `Closes #<n>` trailer as the remedy |
| issue unreadable (exit 2, as for an unreadable pull request) | the destination that could not be read, naming `ISSUE` as the first thing to check |
| issue reporting a number other than `ISSUE` | both numbers |
| `ISSUE` naming a pull request rather than an issue | the swapped argument, before anything is posted |
| pull request not `OPEN`, or its number disagrees | the observed state |
| pull request head branch in a fork | the fork, and that cross-fork hand-off is unsupported |
| `git ls-remote` returning no line, several lines, or a non-SHA | what it returned |
| `ls-remote` SHA ≠ `headRefOid` | both SHAs, and that the branch moved |
| composed body failing public-safety | that it did not pass |
| public-safety gate unable to run (exit 2) | that the scan did not run, with the gate's own stderr |
| composed body missing a marker, the sentinel, or the handshake | which one, before anything is posted |
| `gh issue comment` failing | that the comment was not created |
| comment URL not parseable for this repo and issue | the URL |
| readback request failing | that the stored copy could not be read |
| stored copy missing the opening marker | that marker, by name |
| stored copy missing the sentinel | that sentinel, by name |
| stored copy missing the handshake | the expected line, verbatim |
| stored copy carrying CR | that a carriage return reached the stored body |
| stored copy ≠ composed body | that GitHub's copy differs |

## Failure model

**Actors and deployments.**

- A `$return-to-town` hand-off step, run by a model in an operator's own session with that
  operator's `gh` credentials, from a checkout whose `origin` is the repository being handed off.
- The same, dispatched as a `$quest` or `$campaign` worker — up to five concurrently, each on its
  own issue and pull request.
- The repository's own behaviour suite, with a fake `gh` and a real local git remote.
- Not designed for: unattended CI, a checkout whose `origin` is not the target repository, a
  GitHub Enterprise host, or a pull request opened from a fork.

**Invariants and assets at stake.**

- A hand-off block that the merge gate can select — the whole point; an unselectable block reads
  as "never handed off".
- The handshake binds the pull request number to the head SHA that was actually the tip.
- Public issue content: anything composed here is published and cannot be unpublished.
- The destination: a block lands on the issue the caller named and nowhere else.
- No comment exists after a refusal that happened before the write.

**Accepted failure classes.**

- The head branch moving after a successful hand-off, leaving a complete block the gate will not
  select. Bounded and stated: nothing binds the head before `gh pr merge --match-head-commit`, so
  no writer-side control can do better; the remedy is re-running, per R10.
- A duplicate block from a re-run. Held by an existing guardrail: quest-log's
  latest-complete-wins selection makes the newest complete block the operative one.
- A caller that bypasses the helper and posts the comment itself. Not reachable by any control
  here — the helper makes the correct path easy, not the manual path impossible.
- A worker that dies mid-invocation. Narrowed rather than accepted whole: death before the command
  leaves nothing, death during it leaves at most one unverified comment, and R10 is the remedy.
- Byte-level round-trip differences introduced by GitHub's storage. Bounded and stated: assertion
  5 detects them, and where conditions 1–4 still hold on the stored copy a usable block is on the
  issue, so the disposition is to inspect rather than retry.
- A park note losing its sentinel. Out of this change's surface — the park path stays prose — and
  its cost is bounded: a parked issue reads as unparked to a human who opens it, where the hand-off
  case had no reader at all.
- A pull request whose `Closes #<n>` trailer names the wrong issue. The destination binding is only
  as good as that trailer, and nothing in the repository produces a second independent statement of
  intent to check it against. Bounded and stated: the trailer is written by `$deliver` from the
  issue number the run was dispatched with, so it is wrong only when the run itself was aimed at
  the wrong issue — a condition no writer-side control at hand-off time can detect.
- A stray `GIT_DIR` or `GIT_INDEX_FILE` in the caller's environment. **Not accepted** — the helper
  clears git's local environment variables before `git ls-remote`, the way
  `skills/quest/scripts/check-public-safety` does before its own `git` calls. Listed here because
  silence would read as acceptance: without that clearing, the SHA could be read from a different
  repository than the process working directory, and the handshake would bind a real SHA from the
  wrong remote.

**Covered elsewhere.**

- What the merge gate should check, beyond the four conditions above: issue #235.
- Stating the sentinel requirement in prose for an author who composes by hand: issue #375, which
  this change supersedes by removing hand composition.
- A forged hand-off from an account that is not the pull request's author: `references/merge-gate.md`
  part 4's author pinning, which protects the reader and which no writer-side control can do.
- The normative text of the gate itself: ADR 0042, which makes `references/merge-gate.md` the
  single normative location.

## Threat model

The helper posts to a public repository and reads a caller-supplied file, so it crosses a trust
boundary and this section is required.

**Boundaries added.** Two: the narrative file, read from the filesystem and composed into a body
that is published; and the `ISSUE` argument, which selects the destination that body is published
to. **Boundaries widened.** None — `$return-to-town` already posts this comment; the helper changes
who composes it, not who may post it.

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
- *`ISSUE` argument → publication destination.* This is a boundary because the argument selects
  where public content is written and no later control re-derives it independently — every
  post-write check is built from the same value, so all of them agree with a wrong one. Validation:
  digits only; then the **pull request's** `closingIssuesReferences` must contain `ISSUE`, which is
  the only check here whose evidence does not come from `ISSUE` itself; then the resolved resource
  must carry no `pull_request` key, exist, and report the number asked for. The number becomes a
  REST path segment, so the digits-only check precedes any read, and the whole corroboration
  precedes composition so a refusal leaves nothing posted.
- *`gh pr view` JSON → closing-issue numbers.* Each element's `number` is compared as an integer
  against `ISSUE` and is never interpolated into a path or a command; a non-numeric or absent
  `number` is a malformed response and faults rather than being skipped, because silently skipping
  an unparseable element would weaken the check to "some element matched or none did".
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

The suite covers one case per row of the failure table above except the two named below, plus the
happy path, the preflight path, and one regression case per logged defect in issue #308.

**The exempt rows are named here rather than left to be discovered, and there are exactly two.**
Both are guards against something no input to this suite can produce, so neither can be driven by a
case; both are instead covered by the controlled-fault verification, which introduces the defect
into the helper and observes the red.

- *A non-SHA from `ls-remote`* is not reachable without faking `git`, and faking `git` would
  forfeit the property this suite is built around: that the SHA the contract turns on is read from
  a real remote. It shares a failure-table row with two conditions that are **not** exempt: *no
  line* has a case, and *several refs for one head branch* has one too — reachable only through a
  branch name containing a glob character, which GitHub will not return but the fake can, since the
  fake controls the name the pull request reports.
- *The composed body missing a marker, the sentinel, or the handshake* is unreachable by
  construction: the helper writes all three itself, so no input makes it compose a body without
  them. This is the R5 compose-side assertion, and the only way to observe it is to break the
  composer — which the controlled-fault table does, in its first two rows, and which is why those
  two rows exist.

Every other row has a case. In particular *a stored copy carrying CR* is **not** exempt: the fake
returns whatever stored body a case gives it, so a CR-laden stored copy is directly inducible even
though the helper rejects a CR in the narrative long before composing.

Four cases exist for R11, which no failure-table row existed for before: an issue number the pull
request does not close, a pull request declaring no closing issue at all, an issue number naming a
resource that cannot be read, and an issue number naming a **pull request**, which the fake reports
with a `pull_request` key. All four must refuse before any comment is created — each asserts that
`gh issue comment` was never called, since refusing *before* the write is the entire value of the
control. The first is the transposition case and is the one that matters most: the fake reports a
`closingIssuesReferences` list naming a different, valid, open issue, so the case bites on the
binding rather than on the destination being unreachable.

`just test` discovers suites from the repository's tracked shell sources, so a brand-new suite file
must be staged or committed before `just test publish-handoff` will find it. Running it directly is
what works on a first, unstaged pass.

The regression cases:

- a narrative that wraps the handshake in backticks is rejected (defect 1),
- a stored copy returned without its sentinel fails the readback with the sentinel named
  (defects 2 and 3),
- a second invocation after an unverified first posts a fresh complete block and succeeds
  (defect 4's remedy, R10).

Each contract named in the implementation plan's Verification blocks is verified to bite: the fault
is introduced, red is observed, and the fault reverted. That is the plan's enumerated fault set, not
one controlled fault per case — the claim is bounded to what the plan actually schedules, because a
promise to bite-test all thirty-odd assertions individually is one no step in the plan discharges.

## Non-goals

- What the merge gate should *check* — issue #235 owns that, and issue #308 distinguishes it
  explicitly.
- A general `WORK:*` annotation helper. See the decision record.
- Changing the park protocol, whose block is written by `$quest`'s *On a Blocker* section.
- Changing `references/merge-gate.md`. The reader side already discriminates correctly.
- Cross-fork hand-off. A pull request opened from a fork has its head branch in the fork, and no
  single checkout has the upstream as `origin` and that branch under `refs/heads/`, so R3's SHA read
  cannot be satisfied. The helper detects and refuses it by name rather than leaving it to surface as
  a moved branch. This repository's own work is branch-based; a repository taking fork pull requests
  would need a different SHA source, which is a different design.
