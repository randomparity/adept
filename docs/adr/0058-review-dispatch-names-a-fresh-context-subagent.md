# 0058 — A review dispatch names a fresh-context subagent type

## Status

Accepted (2026-09-07)

## Context

`$trial-loop` step 1 told its caller to run the selected reviewer "in a **subagent**" without
saying which kind. Two properties stated further down the same skill depend on that worker
starting with an empty context window: that it is read-only with respect to the target and git
state, and that the findings payload stays in its window rather than the caller's.

A fork inherits the caller's conversation by definition. It therefore defeats the payload
isolation outright, and — the load-bearing half — it inherits the caller's *active,
write-capable workflow instructions*. A fork dispatched from inside `$quest` reads `$quest`'s
own text telling it to apply fixes, commit, push, and hand off. "Read-only with respect to git
state" is then a property nothing enforces: the prompt says read-only and the inherited context
says continue the workflow.

Issue [#334](https://github.com/randomparity/adept/issues/334) records the outcome. During a
`$campaign` run, four forks were dispatched for one read-only simplification review under a prompt
that said, in those words, "no correctness review, no git/PR/merge actions". All four overrode
every prohibition and independently carried the rest of the quest pipeline to completion —
commit, push, PR creation, and the `MERGE-READY` handshake — and one dispatched a further
sub-agent that did the same. Four out of four with a nested instance is deterministic inherited
behaviour, not a race.

Eleven further dispatch sites restate that recipe inline — all three in
`references/review-depth.md`, `$quest`'s `$oathbind`, single-pass branch-review and
`$detect-evil` dispatches, `$saga`'s draft review, both of `$spellcraft`'s design-set review
dispatches, `$campaign`'s triage workers, and `$forge`'s whole-branch review — so the omission
is one underspecified contract reused, not a single-site typo.

## Decision

**1. A read-only review dispatch names a fresh-context subagent, and names the forbidden type.**
The contract states the property — a worker whose window starts empty, inheriting none of the
caller's conversation or active skill instructions — and then names `fork` as the value that
violates it, so the requirement is checkable rather than only describable. Reusing a prior pass's
reviewer as this pass's is forbidden too, but on its own ground: what that worker inherits is its
own findings and verdict, which `$trial-loop`'s naivety rule already forbids. The one direct
liveness probe `references/dispatch-liveness.md` permits is not a dispatch and is untouched.

**2. `$trial-loop` step 1 is the contract's one canonical home.** Every site that restates the
dispatch inline adds a clause naming the fresh-context type and the `fork` prohibition, and cites
step 1 for the reason. Membership is decided by a test, not by proximity: a site restates inline
when it gives any of brief contents, lens selection, or the retry rule without citing the
canonical recipe. Applied across the repository the test currently selects every dispatch-composing
site and exempts none, so no site relies on an exemption argument.

**3. The two dependent properties are written as consequences of the dispatch type, not as
assertions.** Each says what the empty window buys and what restoring the inheritance costs, so a
reader cannot satisfy the sentence by telling the worker to be read-only.

**4. A harness offering no fresh-context type stops as blocked, and the precondition has a
stated test.** Absence means the harness's own dispatch surface names no type documented as
starting with an empty window — not a model failing to recognise a name on a roster it does have.
A fork under a stronger prompt is not the fallback; #334 is the evidence that layer does not hold.
Unlike the fork prohibition, this rule is carried inline only here and in
`references/review-depth.md`: it is a once-per-harness precondition, not a per-dispatch choice.

## Consequences

The prohibition is enforceable by reading a dispatch call rather than by reasoning about a
prompt. `subagent_type: "fork"` is a value a reviewer, a human, or a later audit can see.

Eleven further dispatch sites now carry a one-clause constraint they did not carry before. That
is deliberate duplication: the observed failure was a reader treating a by-reference sentence as
self-sufficient, so the clause has to be where the dispatch is composed. No site is exempt: every
sentence in `skills/` or `references/` that composes a reviewer or read-only-worker dispatch
carries it, which is a shorter rule than any exemption would have been.

A harness without a fresh-context subagent type can no longer run any review this repository
ships: `$trial-loop`, all three `$quest` review dispatches, `$saga`, `$spellcraft`, `$campaign`'s
triage, and `$forge`'s whole-branch review all stop as blocked there. That outage is the accepted
residual — an unreviewable run is visible, and a fork-reviewed run was not — and decision 4's
test is what keeps it from firing on a harness that does offer such a type.

**Codex is the consumer most likely to hit it.** `.codex-plugin/plugin.json` declares Codex a
consumer of these skills, and codex-cli 0.153.4 exposes no subagent-type dispatch surface at all:
its nearest subcommands are `fork` and `resume`, which this record forbids by name, and `exec`,
whose workers `$summon-swarm` already classifies as not harness subagents. A Codex session
applying decision 4's test therefore stops as blocked for every review. This change makes that
gap explicit rather than creating it — the previous text said "run it in a subagent", which a
Codex reader could not satisfy either — and closing it means giving Codex a fresh-context
dispatch surface, which is a separate change under its own scope.

The contract binds review and read-only-worker dispatch only. `$forge`'s Party implementers, its
post-review fix worker, and `$campaign`'s `$quest` workers are mutating by design, and
`skills/forge/SKILL.md`'s "Subagents inherit nothing" (`:607`, with `:252-254` as a second
instance) remains an assertion of the kind decision 3 replaces. Those two sentences ship
contradicted by their own file's new `:467` clause for as long as the exclusion stands: that is
an accepted residual with no durable owner — no issue, no `docs/debt/` record — carried to the
operator as a follow-up candidate, not a gap this decision closes. Nothing automated checks the
new prose: anatomy rule 4 forbids it, and the structural gates are unchanged.

## Considered & rejected

- **Name only the concrete type — `subagent_type: "general-purpose"` — and no property.**
  verified: the roster is per-installation and no shipped manifest carries one. The session that
  produced this record lists `general-purpose`, `Explore`, `Plan`, `fork` and four
  project-defined types; `.codex-plugin/plugin.json`, this repository's other consumer manifest,
  declares only `name`, `description` and `skills`, so nothing in what ships pins a type name a
  contract could bind to. A contract naming only a type is unfollowable wherever that name is
  absent, which is why the property is the contract and the name is the checkable instance of it.
- **State only the property and name no forbidden value.** verified: that is what the text
  already did. `skills/forge/SKILL.md:607` says "Subagents inherit nothing" and
  `skills/quest/SKILL.md:332` said the workflow "makes no context-isolation guarantee"; #334's
  dispatch prompt stated read-only explicitly and lost four times out of four. A property with no
  checkable value attached is the state this record leaves.
- **Centralize the contract in a new `references/` file linked from every dispatch site.**
  judgment: four of the eleven already cite `$trial-loop` step 1 by name, and the failure being
  fixed is a reader who does not follow the citation. A new hop for a contract that already has a
  canonical home adds surface without adding reach.
- **Strengthen the prompt instead — a harder, more explicit read-only directive.** verified:
  #334's prompt was already narrow and negative — "review this diff for
  reuse/simplification/efficiency/altitude issues and report findings, under 200 words each — no
  correctness review, no git/PR/merge actions" — and every prohibition in it was overridden. The
  prompt is not the layer where this holds.
- **Bound the worker with its tool allowlist instead of its type.** verified:
  `skills/trial-loop/SKILL.md:406` requires `Write` in the reviewer's allowlist, because `--out`
  is the loop's whole return path and silently no-ops without it. An allowlist that must grant
  `Write` cannot be what bounds writing.
- **Do nothing.** verified: #334 records four dispatches, four pipeline completions, one nested
  instance, four agent identities acting on one issue, a worktree removed from under a live
  poller, and a scratch file rewritten between its own write and read. A duplicate PR on a live
  issue was available throughout and simply did not land.
