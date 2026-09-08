# 0058 — A review dispatch requires a worker with no parent conversation

## Status

Accepted (2026-09-07)

## Context

`$trial-loop` step 1 told its caller to run the selected reviewer "in a **subagent**" without
saying which kind. Two properties stated further down the same skill depend on that worker
starting with no parent conversation: that it is read-only with respect to the target and git
state, and that the findings payload stays in its window rather than the caller's.

"No parent conversation" is the documented property, and the precision matters. Under *What
subagents inherit* at `code.claude.com/docs/en/agent-sdk/subagents`, a non-fork subagent's
context window "starts fresh, with no parent conversation, but isn't empty"; the table there
lists what it does carry — its own system prompt and the dispatch prompt, project `CLAUDE.md`,
and tool definitions. A contract demanding an *empty* window would therefore be satisfied by
nothing at all, on any harness, and would block every review rather than the fork-shaped ones.

Cite that page specifically. `code.claude.com/docs/en/sub-agents` covers the same feature in
different words and carries neither phrase, so "the subagent documentation" unqualified sends a
later reader to a page that appears to contradict this record.

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

**The clauses say `worker`, not `subagent`.** [ADR
0011](0011-canonical-workflow-review-vocabulary.md) already reserves `worker` for "a dispatched
agent **or process**", and `skills/summon-swarm/SKILL.md` instructs readers to "Reserve
`subagent` for a literal harness/API capability, never a workflow role". A clause demanding a
*subagent* therefore reads, correctly, as demanding one harness's capability — which is
unfollowable where that capability does not exist. `subagent_type: "fork"` keeps the narrow noun
because there it *is* the literal capability being forbidden.

Reusing a prior pass's reviewer as this pass's is forbidden too, but on its own ground: what that
worker inherits is its own findings and verdict, which `$trial-loop`'s naivety rule already
forbids. The one direct liveness probe `references/dispatch-liveness.md` permits is not a dispatch
and is untouched.

**2. `$trial-loop` step 1 is the contract's one canonical home.** Every site that restates the
dispatch inline adds a clause stating the fresh-context requirement and the `fork` prohibition,
and cites step 1 for the reason. Membership is decided by a test, not by proximity: a site
restates inline when it gives any of brief contents, lens selection, or the retry rule without
citing the canonical recipe. The test runs over **reviewer and read-only-worker** dispatch only —
that is the contract's subject — and within that population it currently selects every
dispatch-composing site and exempts none, so no selected site relies on an exemption argument.

One site is worth naming because it passes the inline test and is still out: `$restock` §3b
composes a worker dispatch inline, giving brief contents in full. Its workers build and test
inside an assigned worktree, so they are mutating by design and fall outside the contract's
subject along with the other mutating dispatches below — not by an exemption argument, but
because the population never included them. Stating that here spares a later auditor re-deriving
it to tell a considered call from a missed site.

**3. The two dependent properties are written as consequences of the dispatch type, not as
assertions.** Each says what the absent inheritance buys and what restoring it costs, so a
reader cannot satisfy the sentence by telling the worker to be read-only.

**4. Any dispatch mechanism satisfying the property qualifies, and only a harness offering none
stops as blocked.** What the contract requires is the isolation, not a particular way of
obtaining it. A named fresh-context subagent type qualifies. So does a **fresh** non-interactive
process of the same agent: started with no session to continue, it has no way to reach a parent
conversation, so nothing has to be trusted to honour the isolation.

That reasoning holds only while the process is fresh, and the qualifier is load-bearing rather
than decorative. A process that resumes a stored session inherits that conversation through its
session id, which is precisely the handle the argument says it lacks — so a resumed process is
disqualified on the same ground as a fork, and naming only `fork` would leave the wider hole
open under a different subcommand. Absence means the harness's dispatch
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

**Codex satisfies it too, through a purpose-built surface — but only one of the two spellings.**
codex-cli 0.153.4, current at the time of writing, ships both `codex review` and
`codex exec review`. They are not interchangeable here, and the difference decides which one a
`$trial-loop` dispatch can use.

`codex exec review` is the one that carries a return path. It takes `--base <branch>`,
`--uncommitted`, or `--commit <sha>` plus custom review instructions, mapping onto the target and
focus arguments the loop already sends, and it carries `--output-schema <file>` to constrain the
final response to a JSON Schema, `-o/--output-last-message <file>` to write it, `--json`, and
`--ephemeral` to skip session persistence. The two file flags are the compact object's return
path, and a process route needs them: a process writes its result to stdout, which a foreground
invocation hands straight to the dispatcher.

It does **not** carry `-s/--sandbox`. That flag is on `codex exec` itself and on neither review
subcommand — `codex exec review --sandbox read-only` exits with `unexpected argument
'--sandbox'` at this version. A dispatcher that needs the sandbox stated explicitly uses plain
`codex exec --sandbox read-only` and puts the review instructions in the prompt, composing the
diff itself instead of getting `--base`; one that uses `codex exec review` accepts whatever
sandbox that subcommand applies, which its help output does not state. Neither route changes this
record's decision — both start a fresh process with no parent conversation — but the record must
not hand a Codex reader a flag combination that errors.

`codex review` is not. Its complete option set at this version is `-c/--config`,
`--strict-config`, `--enable`, `--disable`, `--uncommitted`, `--base`, `--commit`, `--title` and
`-h`: no sandbox flag, no output schema, no last-message file. A dispatch composed against it has
no way to return the compact object, which is the loop's whole return path.

Each `codex exec` run is a fresh process, so it starts with no parent conversation by
construction. Pass `--sandbox read-only` explicitly rather than relying on a default: the
`codex exec --help` output for this version lists the three sandbox values without marking one as
default, so the default is not established by the evidence this record cites.

Both disqualifying spellings must be forbidden, not just the one named `fork`. Codex ships
`fork` **and** `resume` at the top level and again under `exec`; `codex exec resume --last`
continues the most recent session, which is the inheritance this record exists to prevent,
reached without the word "fork" appearing anywhere.

An earlier draft of this record asserted the opposite: that Codex exposed no qualifying surface
and would stop as blocked for every review. That was wrong. It was reached by reading `codex
--help` for subagent-type vocabulary and passing over the `review` subcommand on the same screen,
which is the same naming-over-property mistake decision 4 now forbids the contract from making.
The correction is recorded here rather than silently applied, because the false claim is what a
`MAJOR`-shaped consequence would have been argued from.

The contract binds review and read-only-worker dispatch only. `$forge`'s Party implementers, its
post-review fix worker, and `$campaign`'s `$quest` workers are mutating by design, and
`skills/forge/SKILL.md`'s "Subagents inherit nothing" — one occurrence, under *What goes in a
dispatch* inside the *Party* section — remains an assertion of the kind decision 3 replaces.
That sentence ships contradicted by its own file's new whole-branch-review clause for as
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
