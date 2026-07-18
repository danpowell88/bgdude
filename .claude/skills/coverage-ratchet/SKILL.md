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
```
flutter test --coverage test/
dart tools/coverage_report.dart --uncovered 20
```
CI's `coverage-gate` job runs that **same script** on the merged shard tracefiles, so the
number you see locally is the number the gate enforces — there is no second implementation to
drift out of sync. `--uncovered N` lists the N worst included files by uncovered lines, which
is where to aim tests. Floor is **80%** in `ci.yml`, measured at **85.6%** (2026-07-18); it's a
floor, not a target — the real gate is the no-drop ratchet vs `main`.

## What counts, and what doesn't (decision-16)
The gated number is **non-UI Dart logic**. What's excluded lives in one reviewable file,
`tools/coverage_exclusions.txt`, each entry with its rationale: generated code, the drift table
DSL (structurally unreachable — the generated table subclass overrides every getter),
`lib/main.dart`, vendor-SDK adapters behind an interface seam, and `lib/ui/**` (covered by
`integration_test/` on a device per decision-5 — don't chase their unit-coverage lines).

**Adding an exclusion is a last resort, and it's a reviewed diff.** The bar is "this cannot be
meaningfully unit tested", never "this isn't covered yet". If a seam exists to inject a fake,
the code is testable and gets a test. Before excluding a vendor adapter, check all four:
it implements an interface the app codes against, its body is only vendor-SDK calls, nothing
can be injected to observe it, and the logic using it is already tested against a fake.

## Every bug fix ships a failing-first test
A fix's negative-case test must assert on the real invariant/output (not `returnsNormally` /
"no throw"). Prove it: revert the fix, watch the test go red, restore. A test that can't fail
when the fix is reverted is hollow.
