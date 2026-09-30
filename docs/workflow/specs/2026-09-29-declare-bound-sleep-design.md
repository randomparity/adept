# Declare the bounded-call sleep prerequisite

## Problem

Issue #404 identifies sleep used by the bound and grace polls but omitted from
three standalone executables' existing required-command lists. A restricted PATH
can therefore reach a polling dependency failure instead of a clear preflight refusal.

## Scope

Add sleep to the existing lists in publish-forge-review, publish-handoff and
collect-telemetry. Preserve each executable's current missing-command diagnostic
and failure class. Extend existing restricted-PATH fixtures, supplying the other
preflight commands but withholding sleep, and assert refusal before gh calls.
The sourced quest-log assets have no equivalent standalone preflight boundary;
introducing that architecture is excluded. No ownership transition is needed.
No poll, bound, timeout dependency or caller classification changes are required.
Set the mandatory plugin version to the campaign reservation 5.14.7.

### Failure model

1. Actors/deployments: operators and CI invoking the three standalone scripts on
   Bash 3.2 with a PATH whose required commands may be absent.
2. Invariants/assets: a missing sleep produces its named preflight diagnostic,
   existing failure exit, empty success stdout and no gh invocation.
3. Accepted: a resolved sleep may later fail or disappear; command availability
   preflight does not validate runtime behavior. Existing command checks own this limit.
4. Elsewhere: sourced tracker preflight architecture belongs to separately
   authorized future work; the existing caller boundary is retained.

## Success

Each of the three executables names sleep in its existing dependency preflight.
Each corresponding suite observes the script's existing error class and diagnostic
with sleep withheld, before a network operation. Other preflight cases keep passing.

## Validation

focused-test: publish-forge-review-test.sh missing-dependency case expanded to sleep;
red before repair must fail its named-diagnostic assertion; green: just test publish-forge-review.
focused-test: publish-handoff-test.sh missing-sleep case; red must fail exit/diagnostic
or no-call assertion; green: just test publish-handoff.
focused-test: collect-telemetry-test.sh restricted PATH case; red must fail exit/diagnostic
or no-call assertion; green: just test collect-telemetry.
These cases run before repair, then all three suites run green together. Version
structure uses just version-check; assembled checks use just commit-check.
Managed pre-push just ci owns final full local verification; Ubuntu/macOS CI follows.
