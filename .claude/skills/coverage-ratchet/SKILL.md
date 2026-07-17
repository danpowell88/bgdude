---
name: coverage-ratchet
description: Keep bgdude's line coverage from regressing. Use when adding or modifying testable lib/ code, or when the CI coverage-gate check fails on a PR. New testable code ships with its tests in the SAME change so the number never drops — CI machine-enforces this per PR against main's latest successful run, not just a floor.
---

# Coverage is a ratchet (per ticket)

CI's `coverage-gate` job fails a PR whose line coverage is **below the latest successful
`main` run's** — not merely below the floor. So a local pass can still fail CI if `main` is
higher. Rules:

- Any new **testable** code ships with its tests **in the same change**.
- If your change lowers coverage, add tests until it recovers **before** committing.
- If it raises the sustained level, that becomes the new baseline the ratchet holds; if it's
  a durable gain, bump the floor in `ci.yml` so it's locked in.

## Compute it the way CI does (match locally)
1. `flutter test --coverage test/`
2. Sum `LH:` / `LF:` over `coverage/lcov.info`, **excluding `lib/data/database.g.dart`**
   (drift's generated code — mostly uncalled boilerplate that dilutes the score without
   reflecting hand-written coverage).
3. Floor is **65%** in `ci.yml` (a floor, not a target — the real gate is the no-drop ratchet
   vs `main`). Actual sustained level is higher.

## What NOT to chase
UI screens (`lib/ui/**`) are covered by the `integration_test/` suite on a device, not unit
tests — don't chase their unit-coverage lines. The floor deliberately leaves headroom for
that gap rather than penalizing it.

## Every bug fix ships a failing-first test
A fix's negative-case test must assert on the real invariant/output (not `returnsNormally` /
"no throw"). Prove it: revert the fix, watch the test go red, restore. A test that can't fail
when the fix is reverted is hollow.
