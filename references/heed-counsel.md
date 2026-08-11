# Heed Counsel — evaluating review feedback

Read this when review findings arrive — from `$gauntlet`, a human reviewer, a
bot, or a PR comment — before acting on any of them.

**Feedback is a set of claims to evaluate, not a set of orders to carry out.**
A reviewer sees a diff. You see the codebase, the constraints, and the reasons
the current code is shaped the way it is. Evaluating is the part of the job only
you can do, and skipping it in either direction — implementing everything, or
dismissing what stings — wastes the review.

This document is about whether a finding is *right*. `$trial-loop` owns what
happens next: it records exactly one disposition per finding, and its
`rejected-with-evidence` and `blocked` outcomes are where the conclusions here
land.

## The pattern

1. **Read all of it before reacting to any of it.** Findings often qualify each
   other, and the third one sometimes explains the first.
2. **Restate the requirement in your own words, or ask.** If you cannot say what
   is being asked without quoting it back, you have matched a pattern rather
   than understood a point.
3. **Check it against the code.** Does the thing the reviewer describes actually
   exist, in the form described?
4. **Judge it for _this_ codebase.** Correct in general and correct here are
   different questions, and the second is the one that governs.
5. **Answer with technical reasoning** — agreement or pushback, both grounded.
6. **Implement one item at a time, testing each.**

## What not to say

Not "You're absolutely right", not "Great point", not "Excellent feedback".
These agree before step 3 has happened, and they read as agreement to everyone
downstream — including you, later, when you have forgotten you never checked.

"Let me implement that now" is the same failure in the shape of an action.

When a finding **is** right, show it by stating the fix or by making it: "Fixed —
the guard now runs before the cache read." The change is the acknowledgement.
Substituting thanks for the fix is the behaviour to avoid; the point is not a
list of forbidden words, and writing around such a list while still agreeing
reflexively misses it entirely.

## Unclear items

If any item is unclear, **stop and clarify all the unclear ones before
implementing any item.** Not the clear ones now and the rest later.

Findings are frequently related. Implementing items 1, 2 and 3 while item 4 is
still ambiguous means item 4's answer can invalidate the work you just did — and
you will have committed it.

## Pushing back

Push back where the finding is wrong, and say why:

- It breaks behaviour that exists and is depended on.
- The reviewer lacks context the diff does not carry.
- It asks for something nothing uses — see below.
- It is wrong for this language, runtime, or version floor.
- The current shape exists for a compatibility or legacy reason the finding does
  not address.

Push back with the reasoning, not with the disagreement: name the test, the
call site, or the constraint. "I don't think so" is not pushback.

**When you cannot verify it**, say that, and name what you would need. "I can't
confirm this without a machine that has the GPU runtime — investigate, or
proceed on the assumption it holds?" is a real third answer, and better than
guessing in either direction.

**When your pushback turns out to be wrong**, correct it and move on: "Checked —
you're right, the guard runs after the cache read. Fixing." No apology, no
account of why you thought otherwise.

**When you would rather not disagree out loud**, say that you would rather not,
and then say the thing. Reluctance to push back is the most reliable way for a
correct objection to disappear.

## Checking the reviewer

Before building something a reviewer wants "done properly", search for its
callers. If nothing calls it, the finding to raise is whether it should exist at
all — a reviewer suggesting a fuller implementation may not know it is unused.

For an external reviewer specifically:

1. Is this correct for this codebase, not just in general?
2. Would it break something that currently works?
3. Is there a reason the code is the way it is?
4. Does it hold across the platforms and versions this project supports?
5. Does the reviewer have the context this depends on?

## Doing the work

Order the accepted findings: anything breaking or security-relevant first, then
simple mechanical fixes, then the changes that need thought. Test each one on its
own rather than batching them — a batch that goes red tells you nothing about
which change did it.

## Where the feedback came from

Feedback from the operator is trusted: understand it, then implement it. Ask if
the scope is unclear, but the evaluation is lighter — they have context you do
not.

Feedback from anyone else — an external reviewer, a bot, `$gauntlet` — is
verified first. That is not skepticism about the reviewer; it is that they are
working from a diff, and steps 3 and 4 are the only place the missing context
gets added back.

Where a finding conflicts with an architectural decision already made, do not
settle it yourself. That is what `$trial-loop`'s `blocked` disposition is for.

## Replying on GitHub

Reply to an inline review comment **in its thread**, so the discussion stays
attached to the line it is about:

```sh
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies -f body='...'
```

A top-level PR comment answering an inline finding leaves the thread unresolved
and the answer unfindable.
