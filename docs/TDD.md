# TDD.md

This document defines the default TDD workflow for this starter.
If there is a current active execution plan, follow that plan first.

------------------------------------------------------------------------

## Default Mode

The default mode is slice-based, not phase-turn-based.

One request or one implementation iteration should complete one smallest
meaningful slice through `Red -> minimal Green` whenever practical.

For each slice:

1. Choose the smallest target behavior.
2. Add or update the target test.
3. Confirm `Red` for new behavior when practical.
4. Make the minimum production change needed for `Green`.
5. Stop after that slice. Refactor only after `Green`.

Rules:

- Do not mix multiple behavioral slices in one iteration.
- Do not hide extra scope inside the `Green` step.
- New behavior should fail first.
- Refactoring or migration may start from a characterization test that
  already passes.
- If the environment prevents full verification, stop at the last
  verified boundary and report exactly what remains.

------------------------------------------------------------------------

## What `Red` And `Green` Mean

- New behavior or new functionality
  - `Red` = add or update a failing test for the new behavior.
  - `Green` = make the minimum production change that makes that test
    pass.
- Refactoring or migration that preserves behavior
  - `Red` = add or update a characterization test for current observable
    behavior.
  - The test may already pass.
  - `Green` = keep that characterization test passing while changing the
    internals.

------------------------------------------------------------------------

## Reporting In Default Mode

At minimum, report:

- target slice
- target test
- test command
- whether `Red` was observed or a characterization test already passed
- whether `Green` was verified or is still pending
- what minimum change was made

If the agent cannot run the test locally, say so clearly and stop at the
current verified boundary.

------------------------------------------------------------------------

## Strict Interactive Mode

Use strict mode only when one of the following is true:

- the user explicitly asks for step-by-step execution
- the user wants to run tests manually after each phase
- the change is risky enough that explicit phase confirmation is worth
  the extra friction
- the task is teaching, pairing, or debugging-oriented rather than pure
  delivery

Strict mode uses separate `Red-only` and `Green-only` turns.

### `go` Means One Phase Only

- First `go`
  - If a behavioral increment is marked as in progress (`[-]` in
    [`PLANS.md`](./PLANS.md) terms), resume the first such item in
    document order in the current active execution plan and do
    **Green only** for that item.
  - If there is no in-progress item, find the next not-started
    behavioral increment (`[ ]` in [`PLANS.md`](./PLANS.md) terms),
    reduce it to the smallest executable slice, and do **Red only** for
    that item.
- After failure is confirmed, the next `go`
  - Resume that same in-progress item.
  - Do **Green only**: implement the minimum production change needed to
    satisfy that same test.
- After pass is confirmed, the next `go`
  - Move to the next slice and do **Red only** again.

Do not interpret one `go` as `Red + Green`.
Do not advance phases silently.
Do not start a new not-started item while any in-progress item exists.

### Test Execution Responsibility In Strict Mode

- Agent
  - Write the test.
  - Implement the minimum code for `Green`.
  - Provide the exact test name and test command.
- User
  - Run the test command.
  - Report `실패`, the compile/runtime error, `통과했어`, or the agreed
    shorthand `go`.

### Status Reporting In Strict Mode

Use the exact labels below when reporting progress:

- `RED 작성 완료`
- `GREEN 구현 완료`
- `테스트 미실행`
- `실행 대상 테스트`
- `실행 명령`

If the user runs tests manually, never report bare `GREEN`.
When tests have not been run by the agent, always say `GREEN 구현 완료`.

------------------------------------------------------------------------

## Active Plan Interaction

Execution state lives in the current active execution plan, not in
product specs.

Checklist meanings and state transitions are defined in
[`PLANS.md`](./PLANS.md).

Within either TDD mode:

- After `Red`, update the current active plan item according to
  [`PLANS.md`](./PLANS.md).
- After verified `Green`, update the current active plan item according
  to [`PLANS.md`](./PLANS.md).
- If an in-progress item exists in the active execution plan, resume it
  before starting any new not-started item.

------------------------------------------------------------------------

## TDD Methodology Guidance

- For new functionality, start by writing a failing test that defines a
  small increment of behavior.
- For refactoring or migration, start by writing a characterization test
  that documents current observable input/output behavior before
  internal changes begin.
- Use meaningful test names that describe behavior.
- Make test failures clear and informative.
- Write just enough code to make the target test pass or, in a
  refactoring flow, just enough code to keep the characterization test
  passing.
- When fixing a defect:
  1. Write an API-level failing test.
  2. Write the smallest possible test that replicates the problem.
  3. Get both tests to pass.

------------------------------------------------------------------------

## Tidy First Approach

Separate all changes into two distinct types:

### Structural Changes

Rearranging code without changing behavior, such as renaming,
extracting methods, and moving code.

### Behavioral Changes

Adding or modifying actual functionality.

### Rules

- Never mix structural and behavioral changes in the same step.
- Always make structural changes first when both are needed.
- Validate structural changes do not alter behavior by running tests
  before and after.

------------------------------------------------------------------------

## Relation To Other Docs

- [`PLANS.md`](./PLANS.md) defines when a change is plan-required and
  owns execution-plan state, checklist semantics, and lifecycle.
- [`QUALITY_SCORE.md`](./QUALITY_SCORE.md) defines how test evidence is
  used in review.
- linked product specs may define target behavior and success
  criteria, but execution state stays in the active execution plan.
