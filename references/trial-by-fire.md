# Trial By Fire — the test-driven development standard

Read this before writing a test, when a test is hard to write, or when you are
about to argue yourself out of writing one first. `$forge` owns the cycle you
execute; this document owns why the order is the point and what a test has to do
to be worth having.

## The law

**No production code without a failing test that ran first.**

This binds new features, bug fixes, refactors, and any change to observable
behaviour. Throwaway prototypes, generated code, and configuration are outside
it — and those are agreed with the operator, not decided alone in the moment you
would like an exception.

Code written before its test does not become test-driven by having a test added
afterwards. Delete it and implement again from the test. Not kept open in
another tab as a reference, not adapted line by line while the test is written —
both of those are writing the test to fit the code, which is the failure the law
exists to prevent. The hours already spent are spent either way; the only
question left is whether you end up with code you can trust.

Reading the exceptions as a loophole is breaking the rule. Violating the letter
is violating the spirit.

## Why the order is the whole point

A test you never watched fail has proved nothing. It might assert the wrong
thing, assert nothing at all, or exercise a path the feature never takes — and
you cannot tell which, because you have never seen it distinguish a working
implementation from a broken one. Watching it fail is the only evidence that it
is capable of failing.

So the failure has to be the **right** failure. Read it before continuing:

- **It fails for the reason you expect** — the behaviour is missing. A failure
  from a typo, a bad import, or a missing fixture tells you nothing about your
  assertion. Fix the mistake and run it again until it fails properly.
- **It fails rather than errors.** An error means the test never reached its
  assertion.
- **It passes immediately?** Then it is describing behaviour that already
  exists, and it will keep passing no matter what you do next. The test is
  wrong, not the code — sharpen it until it fails.

After you implement, the direction of repair reverses: when the test fails, the
code is wrong. Changing the assertion to match what the code did is how a suite
stops meaning anything.

## What a good test looks like

**One behaviour per test.** An "and" in the name is the signal — split it. A test
that checks three things reports one failure and hides the other two.

**Named for the behaviour it demonstrates.** The name is read far more often than
the body, usually in a failure report by someone who did not write it.

**Driven against real code.** Reach for a mock only where the real thing is slow,
non-deterministic, or outside your process — and see below, because mocks are
where suites most often stop testing anything.

Cover the edges and the error paths, not only the path you had in mind. A handled
error with no test that triggers it is an assumption, not a behaviour.

## Bugs

A bug means a behaviour nobody tested. Reproduce it as a failing test first, then
fix it. The test proves the fix works and stops the bug returning quietly a year
later; fixing first and confirming by hand gives you neither.

## Mocks

Mocks isolate. They are not the thing under test, and the anti-patterns below all
come from forgetting that.

**Never assert that a mock exists or was called, in place of asserting on real
behaviour.** `expect(getByTestId('sidebar-mock')).toBeInTheDocument()` proves the
mock rendered. It would pass if the component under test did nothing at all.

**The check:** delete the mock and see what happens. A test that fails *only*
because the mock is gone was testing the mock. So was one that passes whether or
not the real dependency works.

**Never add a method to a production class that only tests call.** A `destroy()`
that exists so a fixture can tear down looks like production API, can be called
as one, and ties the object's lifecycle to the test's. Put it in test utilities.

**Know what the real method does before replacing it.** Mocking a method that
writes config will break any test depending on that write, usually by making it
pass for the wrong reason. Work out which side effects the test needs, then mock
at the lowest level that preserves them — the slow call, the network, the clock —
not the high-level operation the test is actually about. "I'll mock it to be
safe" is how this starts.

**Mock the complete structure as it exists in reality.** Include the fields the
system consumes downstream, not only the ones your assertion reads. A partial
mock encodes your current guess about the shape and fails silently the moment
something reaches for a field you omitted.

**When the mock setup outgrows the test logic, stop.** That is the design telling
you an integration test against real components would be simpler and would
actually prove something.

## The arguments against it

**"I'll write the tests after — same coverage."** Tests written after the code
pass on the first run, and a test that has never failed is unproven. Worse, they
are written by someone who now knows the implementation, so they check what was
built rather than what was required, and they cover the edge cases you
remembered rather than the ones you would have discovered.

**"I already tested it by hand."** Ad hoc, unrecorded, and unrepeatable. It
cannot run again when someone changes the code next month, which is when it would
matter.

**"Deleting hours of work is wasteful."** The hours are gone regardless. Keeping
code whose behaviour nobody has demonstrated is not saving them; it is taking on
debt in their name.

**"Being pragmatic means adapting the rule."** Test-first *is* the pragmatic
choice — a failing test localises a defect in seconds, where the same defect
found after integration costs a debugging session. The shortcut is only faster
until the first bug.

**"It's about spirit, not ritual."** The spirit is knowing your tests can fail.
There is no way to know that without watching them do it.

## When a test is hard to write

Difficulty writing a test is information about the design, not an obstacle to
route around:

| Difficulty | What it is telling you |
|---|---|
| You cannot see how to test it | Write the API you wish existed, then the assertion. If it is still unclear, the behaviour is not yet defined — ask |
| The test is complicated | The interface is complicated. Simplify the interface |
| You have to mock everything | The code is too coupled. Inject its dependencies |
| The setup dwarfs the test | Extract helpers. If it is still large, the design is doing too much in one place |
