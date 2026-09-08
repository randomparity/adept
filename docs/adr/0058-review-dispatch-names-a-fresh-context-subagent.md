# 0058 — A review dispatch requires a worker with no parent conversation

## Status

Accepted (2026-09-07)

## Context

`$trial-loop` step 1 told its caller to run the selected reviewer "in a **subagent**" without
saying which kind. Two properties stated further down the same skill depend on that worker
starting with no parent conversation: that it is read-only with respect to the target and git
state, and that the findings payload stays in its window rather than the caller's.

"No parent conversation" is the documented property, and the precision matters. Claude Code's
subagent documentation states that a non-fork subagent's context "starts fresh, with no parent
conversation, but isn't empty" — it carries its own system prompt, the dispatch prompt, project
`CLAUDE.md`, and tool definitions. A contract demanding an *empty* window would therefore be
satisfied by nothing at all, on any harness, and would block every review rather than the
fork-shaped ones.

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

**1. A read-only review dispatch requires a worker with no parent conversation, and names the
forbidden instance.** The contract states the property — a worker starting with none of the
caller's conversation and none of its active skill instructions — and then names `fork` as the
value that violates it, so the requirement is checkable rather than only describable. It also
names one permitted value by way of example: on Claude Code, `general-purpose` is a built-in that
satisfies the property. That name is an illustration, never the contract, because a roster is
per-installation and even this built-in can be withdrawn — `CLAUDE_AGENT_SDK_DISABLE_BUILTIN_AGENTS=1`
removes it, after which a dispatch that omits `subagent_type` fails. A reader who has the property
and one worked example can resolve their own harness; a reader given only a prohibition cannot.

Reusing a prior pass's reviewer as this pass's is forbidden too, but on its own ground: what that
worker inherits is its own findings and verdict, which `$trial-loop`'s naivety rule already
forbids. The one direct liveness probe `references/dispatch-liveness.md` permits is not a dispatch
and is untouched.

**2. `$trial-loop` step 1 is the contract's one canonical home.** Every site that restates the
dispatch inline adds a clause naming the fresh-context type and the `fork` prohibition, and cites
step 1 for the reason. Membership is decided by a test, not by proximity: a site restates inline
when it gives any of brief contents, lens selection, or the retry rule without citing the
canonical recipe. Applied across the repository the test currently selects every dispatch-composing
site and exempts none, so no site relies on an exemption argument.

**3. The two dependent properties are written as consequences of the dispatch type, not as
assertions.** Each says what the absent inheritance buys and what restoring it costs, so a
reader cannot satisfy the sentence by telling the worker to be read-only.

**4. Any dispatch mechanism satisfying the property qualifies, and only a harness offering none
stops as blocked.** What the contract requires is the isolation, not a particular way of
obtaining it. A named fresh-context subagent type qualifies. So does a fresh non-interactive
process of the same agent — process isolation is a stronger guarantee than a roster label, not a
weaker one, because nothing has to be trusted to honour it. Absence means the harness's dispatch
surface offers no mechanism documented as starting a worker with no parent conversation — not a
model failing to recognise a name on a roster it does have, and not a mechanism that happens to be
spelled as a subcommand rather than a type. A fork under a stronger prompt is not the fallback;
#334 is the evidence that layer does not hold. Unlike the fork prohibition, this rule is carried
inline only here and in `references/review-depth.md`: it is a once-per-harness precondition, not a
per-dispatch choice.

## Consequences

The prohibition is enforceable by reading a dispatch call rather than by reasoning about a
prompt. `subagent_type: "fork"` is a value a reviewer, a human, or a later audit can see.

Eleven further dispatch sites now carry a one-clause constraint they did not carry before. That
is deliberate duplication: the observed failure was a reader treating a by-reference sentence as
self-sufficient, so the clause has to be where the dispatch is composed. No site is exempt: every
sentence in `skills/` or `references/` that composes a reviewer or read-only-worker dispatch
carries it, which is a shorter rule than any exemption would have been.

A harness offering no qualifying mechanism can run no review this repository ships: `$trial-loop`,
all three `$quest` review dispatches, `$saga`, `$spellcraft`, `$campaign`'s triage, and `$forge`'s
whole-branch review all stop as blocked there. That outage is the accepted residual — an
unreviewable run is visible, and a fork-reviewed run was not. Decision 4's test is what keeps it
narrow, and on both consumers this repository declares, it does not fire.

**Claude Code** satisfies it with a built-in: a non-fork subagent's context "starts fresh, with no
parent conversation", and `general-purpose` is invocable without defining anything.

**Codex satisfies it too, through a purpose-built surface.** codex-cli 0.153.4 — current at the
time of writing — ships `codex review` and `codex exec review`, which run a code review
non-interactively and take `--base <branch>`, `--uncommitted`, or `--commit <sha>` plus custom
review instructions, mapping onto the target and focus arguments `$trial-loop` already sends. Each
`codex exec` run is a fresh process, so it starts with no parent conversation by construction, and
non-interactive mode defaults to `--sandbox read-only`. It also supplies a return path the compact
object needs: `--output-schema <file>` constrains the final response to a JSON Schema and
`-o/--output-last-message <file>` writes it, with `--ephemeral` skipping session persistence. The
fork prohibition transfers by name, because Codex has one as well — `codex fork` and
`codex exec fork` both resume a prior session's context.

An earlier draft of this record asserted the opposite: that Codex exposed no qualifying surface
and would stop as blocked for every review. That was wrong. It was reached by reading `codex
--help` for subagent-type vocabulary and passing over the `review` subcommand on the same screen,
which is the same naming-over-property mistake decision 4 now forbids the contract from making.
The correction is recorded here rather than silently applied, because the false claim is what a
`MAJOR`-shaped consequence would have been argued from.

The contract binds review and read-only-worker dispatch only. `$forge`'s Party implementers, its
post-review fix worker, and `$campaign`'s `$quest` workers are mutating by design, and
`skills/forge/SKILL.md`'s "Subagents inherit nothing" — in its *Party* section, with a second
instance in *What goes in a dispatch* — remains an assertion of the kind decision 3 replaces.
Those two sentences ship contradicted by that file's own new whole-branch-review clause for as
long as the exclusion stands: that is
an accepted residual with no durable owner — no issue, no `docs/debt/` record — carried to the
operator as a follow-up candidate, not a gap this decision closes. Nothing automated checks the
new prose: anatomy rule 4 forbids it, and the structural gates are unchanged.

## Considered & rejected

- **Name only the concrete type — `subagent_type: "general-purpose"` — and no property.**
  verified: the roster is per-installation and no shipped manifest carries one. The session that
  produced this record lists `general-purpose`, `Explore`, `Plan`, `fork` and four
  project-defined types; `.codex-plugin/plugin.json`, this repository's other consumer manifest,
  declares only `name`, `description` and `skills`, so nothing in what ships pins a type name a
  contract could bind to. Even the built-in is withdrawable:
  `CLAUDE_AGENT_SDK_DISABLE_BUILTIN_AGENTS=1` removes it and a dispatch omitting `subagent_type`
  then fails. A contract naming only a type is unfollowable wherever that name is absent, which is
  why the property is the contract and the name rides along as decision 1's worked example.
- **Require a harness-*named subagent type*, so a fresh process does not qualify.** verified: this
  is what the record's own first draft did, and it produced a false conclusion — that Codex, a
  declared consumer, could run no review at all — while codex-cli 0.153.4 shipped `codex review`
  and `codex exec review` the whole time. A test keyed to how a mechanism is spelled rather than to
  what it guarantees fails exactly where the guarantee is strongest: a separate OS process cannot
  inherit a conversation it has no handle to.
- **State only the property and name no forbidden value.** verified: that is what the text
  already did. `skills/forge/SKILL.md` says "Subagents inherit nothing" and
  `skills/quest/SKILL.md`'s scope-audit step said the workflow "makes no context-isolation
  guarantee"; #334's
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
  `skills/trial-loop/SKILL.md` requires `Write` in the reviewer's allowlist, because `--out`
  is the loop's whole return path and silently no-ops without it. An allowlist that must grant
  `Write` cannot be what bounds writing.
- **Do nothing.** verified: #334 records four dispatches, four pipeline completions, one nested
  instance, four agent identities acting on one issue, a worktree removed from under a live
  poller, and a scratch file rewritten between its own write and read. A duplicate PR on a live
  issue was available throughout and simply did not land.
