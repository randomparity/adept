# 0078 — Visible numbered reservations

## Status

Accepted (2026-09-30)

## Context

Issue #425 exposes independent campaigns selecting the same migration number because
private manifests do not communicate reservations. Public branch and PR work may exist
without a current claim-bound scope, so scope-only discovery is incomplete.

## Decision

One shared numbered-reservations reference governs campaign, quest and record allocation.
Use a bounded complete snapshot of base, own consumed manifest, canonical live-token scopes,
open PR full changed paths and pushed-head full trees. Select the next repository-valid
number above the namespace maximum; failures and overflow hold. Publish assigned exact
path=value in WORK:SCOPE surface before numbered file creation. Moved-base reassignment
repeats discovery, with the orchestrator as sole assignment writer.

## Consequences

Visible reservations survive cross-run isolation. Git object reads avoid truncated PR file
lists; retained pushed branches conservatively consume numbers. Offline record creation
remains local candidate authoring. Discovery is not an atomic allocation service: unseen
simultaneous reservations and post-read changes remain possible. Existing claim grammar,
liveness and external-write authorization are unchanged.

## Considered & rejected

- Own manifest only. verified: campaign at2d9ed62 reserves privately in step4 and
  reassigns in step6 without external discovery; issue #425 records the resulting collision.
- Scope-only scan. judgment: cannot cover an open PR or pushed branch without a live scope.
- New allocation service/lock. judgment: adds infrastructure and lifecycle ownership
  beyond a bounded workflow snapshot; the requested prevention concerns visible work.
