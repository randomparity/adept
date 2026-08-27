# Commit-bound merge gate

Its subject is a commit, not a pull request. Read the head from the ref itself and hold
every part against that one value:

```sh
git fetch origin
HEAD_SHA=$(git ls-remote origin "refs/heads/<branch>" | cut -f1)
API_SHA=$(gh pr view <PR> --repo <owner/name> --json headRefOid --jq .headRefOid)
```

Every command below either answers or fails. A non-zero exit from any of them — `git
ls-remote`, `gh pr view`, `gh run list`, `git fetch` — is a fault that holds the merge, never
an answer and never "not ready". The one command with three answers is part 3's
`git merge-base --is-ancestor`: exit 0 contained, exit 1 base moved, **any other exit a
fault**.

1. **SHA parity.** `HEAD_SHA` is non-empty and equals `API_SHA`. `gh pr view --json
   headRefOid` reads the pull-request API and **can lag `git ls-remote`**; the ref is
   authoritative. `HEAD_SHA` comes from `origin`, so this gate covers same-repository
   heads: check `gh pr view <PR> --json isCrossRepository` first and give a fork-based
   pull request its own named blocker, or its head — which is not in `origin` at all —
   reads as an empty `ls-remote` and gets diagnosed as a deleted branch. An empty
   `HEAD_SHA` is otherwise not a match and not a lag: `git ls-remote` prints nothing and
   exits 0 for a ref that is not there, so the head branch is gone — take the blocker path
   immediately under that name rather than entering the re-read below. A
   mismatch between two real values has two causes and re-reading tells them apart: an
   `ls-remote` value that holds still while `headRefOid` catches up is the API lagging, and
   an `ls-remote` value that keeps moving is an author still pushing. Neither may be merged
   through. Make at most three reads total with short backoff between them; if they do not
   converge, take the hold or blocker path rather than spinning, which an unattended run
   would otherwise do indefinitely against a live branch. This part is a diagnosis and
   pre-empt device, not a safety property: `HEAD_SHA`'s authority is the ref, every other
   part keys on it, and the merge binds it — so a mismatch is held to turn an opaque merge
   refusal into a legible one, at the cost of occasionally parking a correct row.
2. **Checks green for `HEAD_SHA`.**

   ```sh
   RUNS=$(gh run list --repo <owner/name> --commit "$HEAD_SHA" --limit 100 \
     --json workflowName,event,status,conclusion)
   RUN_COUNT=$(printf '%s\n' "$RUNS" | jq 'length')
   printf '%s\n' "$RUNS" | jq '.[] | {workflowName,event,status,conclusion}'
   ```

   Retain the complete array as shown: filtering first destroys the count and makes
   all-success indistinguishable from no runs. Partition on `conclusion`'s vocabulary. A
   result count equal to the limit is potentially
   truncated and holds rather than proving every run green. **Green** is a non-empty list
   in which every run is
   `completed` at `success`, `skipped`, or `neutral`; `skipped` is an ordinary result for a
   conditional workflow, so treating it as failure deadlocks the gate on valid configuration.
   A workflow-level path filter may create no run at all. **Not yet** is no run at all
   *or* any run not yet `completed`. **Failed** is `failure` or `timed_out`. **Cancelled,
   `action_required`, `stale`, and `startup_failure` hold under their own names** — none is a
   verdict about the code. The set read is *all* Actions runs for the commit, not the
   required set: required-ness
   belongs to a branch rule and is not SHA-addressable, so this is deliberately stricter
   than the "required checks are green" it replaces and will hold on an optional run the
   old wording ignored. Do not substitute `gh pr checks` or `statusCheckRollup`: both read
   the pull-request API and inherit exactly the staleness part 1 is about, so they can
   report green about a different commit. `gh run list` sees GitHub Actions runs only;
   where a required check is not one, also read `gh api
   repos/<owner/name>/commits/"$HEAD_SHA"/check-runs`, which is SHA-addressed the same way.

   `[]` means no run exists for that commit, and that is two conditions. A run not yet
   started resolves — use part 1's same three-read bound and take the hold path under that
   name if none appears. A path-filtered commit may never produce a run, so it reaches the
   same bounded hold instead of spinning. A repository with no workflows never resolves:
   establish it
   by a **conjunctive** test — `gh api repos/<owner/name>/actions/workflows` empty **and**
   `check-runs` for `HEAD_SHA` empty **and** `gh api
   repos/<owner/name>/commits/"$HEAD_SHA"/status` reports `total_count == 0` — and record
   part 2 **not applicable** for this run, never persisted. All three parts are required;
   any one alone skips part 2 over a repository whose checks are live elsewhere. Without
   that the gate deadlocks permanently wherever there are no automated checks.
3. **Merge base current.** `git fetch origin`, then `git merge-base --is-ancestor
   "origin/<BASE_BRANCH>" "$HEAD_SHA"`. The fetch is part of this check, not preparation
   for it: this is a local test against a remote-tracking ref, and against a stale one it
   passes wrongly — the exact failure the part exists to catch — so re-fetch here even
   though the block opened with one. Exit 0 passes — the base tip is already in the head,
   so the merge result is the commit CI ran on. Exit 1 means the base moved under a green check: merge
   `BASE_BRANCH` in, regenerate artifacts, rerun guardrails, and re-run this gate from
   part 1, because the refresh produced a new head. Any other exit is a fault, not a
   verdict. `mergeStateStatus` does not answer this: it reports `BEHIND` only where the
   base branch requires up-to-date branches, and stays `CLEAN` otherwise. Run this part
   **immediately** before the merge — nothing binds the base at merge time, so a sibling
   landing in the interval moves it under a check that already passed, and a short
   interval is the only mitigation there is.
4. **Author handshake.** A `MERGE-READY: #<PR> @ <sha>` line whose `<sha>` equals
   `HEAD_SHA`, occurring as a **whole line** inside the latest complete
   `WORK:TRAJECTORY` block **that carries such a line for `HEAD_SHA`** — not the latest
   complete block simpliciter, because the park protocol writes that block type too and a
   hold posted after a valid hand-off would otherwise revoke it. `$return-to-town`'s hand-off
   is what writes the block, and it computes `HEAD_SHA` from `git ls-remote` at that moment;
   read it there rather than relying on a report reaching you. Use the quest-log skill's
   selection rules, not an ad-hoc `jq` over every comment: a block missing its
   `TRAJECTORY:COMPLETE` sentinel is a write that died midway and counts as absent, and
   `last` is what implements latest-complete-wins.

   ```sh
   gh issue view <n> --repo <owner/name> --json comments |
     jq --arg pr "<PR>" --arg sha "$HEAD_SHA" '
       [.comments[]
        | select(.body | test("(?m)^<!-- WORK:TRAJECTORY -->$")
                 and test("(?m)^<!-- TRAJECTORY:COMPLETE -->$")
                 and test("(?m)^MERGE-READY: #" + $pr + " @ " + $sha + "$"))]
       | last | {author: .author.login, body}'
   ```

   **Pin the expected account outside the comment channel.** On a public repository an
   account that can post a `MERGE-READY:` line can equally post a complete-looking hand-off
   block and name itself the author, so "whoever posted the hand-off" is circular on its
   own. The comment's `author.login` must **also** be the pull request's own author —
   `gh pr view <PR> --repo <owner/name> --json author --jq .author.login` — or hold write
   permission (`gh api repos/<owner/name>/collaborators/<login>/permission`). SHA-binding
   does not help against this: `HEAD_SHA` is the public head of a public pull request.

   The one other permitted author is you, where you created the head yourself by refreshing
   a stale base — your own `gh api user --jq .login`. **That self-attestation is derivative
   and never original:** attest only for a head you produced by refreshing one that already
   carried a valid author handshake. A row that reaches part 3 with no handshake for its
   current head takes the hold path — never the refresh path followed by attesting to your
   own work, which would let the refresh mint the handshake this part exists to require. A
   green pull request with no handshake is **pending**, not ready, and a handshake naming a
   different commit is no handshake for this one.

**Scope.** This gate governs issue-backed merges. `$return-to-town`'s restock PR-only mode
is outside it: a dependency pull request has no issue for part 4 and no `$quest` run
authored it, and that mode keeps binding its caller-supplied `$EXPECTED_HEAD_SHA` — the
head restock evaluated — rather than a merge-time read, because refusing a head that moved
after evaluation is the behaviour its `MERGE_REFUSED` outcome depends on.

Only with all four holding for one `HEAD_SHA`, merge — binding that commit at the server,
which is the only place the head can be bound:

```sh
gh pr merge <PR> --repo <owner/name> "$MERGE_FLAG" --match-head-commit "$HEAD_SHA"
```

A refused `--match-head-commit` merge means the branch moved. Re-run the gate from part 1;
never retry the merge on the stale reads.
