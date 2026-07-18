# decision-16 — Coverage is gated on non-UI Dart logic, with an explicit, reviewed exclusion list

**Date:** 2026-07-18
**Issue:** #378
**Status:** in effect

## Context

The `coverage-gate` job measured every line under `lib/` except one hard-coded generated file
(`lib/data/database.g.dart`, matched by an inline `awk` filename test), held a 65% floor and ran
a no-drop ratchet against `main`.

That number answered no useful question. `lib/ui/**` was *informally* considered out of scope —
CLAUDE.md and decision-5 both say screens are covered by `integration_test/` on a device, not by
unit tests — but it was never actually removed from the denominator, so ~6k lines of
deliberately-unit-untested UI silently dragged the percentage down. The result was a gate that
could not distinguish "business logic is untested" (a real problem) from "UI is tested somewhere
else" (working as designed), and a floor set low enough to tolerate the blend. There was also no
single place stating what was intentionally uncovered, or why.

## Decision

**The gated number is the line coverage of non-UI Dart logic**, and what is excluded from it is
declared in one reviewable file, `tools/coverage_exclusions.txt`, with a rationale per entry.

The bar for an exclusion is **"this code cannot be meaningfully unit tested"**, never "this code
isn't covered yet". Four categories qualify today:

1. **Generated code** (`lib/**.g.dart`) — machine-authored, exercised indirectly, and the
   generators are tested upstream.
2. **Drift table DSL** (`lib/data/meal_tables.dart`) — structurally unreachable at runtime:
   drift's generated `$SavedMealsTable extends SavedMeals` *overrides* every column getter, so
   the hand-written declarations never execute. No test can cover them.
3. **App bootstrap** (`lib/main.dart`) — the composition root; exercising it means booting the
   app, which is what `integration_test/` does.
4. **Vendor-SDK adapters behind an interface seam** (`glucose_meter_transport_fbp.dart`,
   `panel_ocr_mlkit.dart`) — each is the sole implementation of an interface the app codes
   against, containing only static third-party SDK calls with nothing injectable. Covering them
   would mean asserting that we called our own mock.

Plus the standing UI carve-out: **`lib/ui/**` is excluded** rather than unit-tested, confirming
decision-5 explicitly instead of leaving it as an unwritten intention.

Mechanism: `tools/coverage_report.dart` merges the per-shard lcov tracefiles, applies the
exclusion list and enforces the floor. **CI and local runs execute the same script**, so a
developer can no longer measure a different number than the gate enforces — previously CI's awk
and the `coverage-ratchet` skill's hand-written instructions were two implementations that could
drift apart.

**Floor re-based from 65% to 80%**, with the post-exclusion measurement at **85.6%** (`main` was
sitting at 71.3% on the old blended metric immediately before this change). The floor catches
collapse; the per-PR no-drop ratchet against `main` remains the real gate.

Note the two numbers measure different things and the jump is not a coverage *gain* — 71.3% was
UI-diluted, 85.6% is the same test suite measured against non-UI logic only. The genuine gain
from this change's new tests is the +31 tests, worth about 1.7 points.

## Consequences

- The number now means one thing, and 85.6% is a level worth defending. Ratcheting from a
  meaningful baseline is what makes the gate load-bearing. Verified end-to-end in CI: the
  4-shard merge reports the same 85.6% as a local single-tracefile run (7549 vs 7548 hit lines —
  one line differing between a sharded and unsharded run, not a merge error).
- **Widget tests under `test/ui/` still run and still fail on regressions, but no longer
  contribute to the gated number.** This is the accepted cost of a single clear semantic: their
  protection comes from the assertions themselves, not from coverage accounting. The script
  prints excluded coverage as an informational line so the excluded bulk stays visible — a
  suspiciously large excluded denominator is the signal that something was excluded to dodge
  tests rather than on merit.
- Adding an exclusion is a **reviewer-visible act**: it is a diff to a documented list, not an
  invisible slip in the percentage. A glob that stops matching any file warns as potentially
  stale.
- Known remaining gaps on *included* code are recorded on issue #378 rather than papered over
  with exclusions — notably `lib/state/providers.dart` (the largest single gap; splitting it is
  issues #42/#49) and the `permission_handler` call-through in `lib/state/ble_permissions.dart`,
  which has no injectable seam for its static permission API.

## What would reverse this

Committing to widget-testing `lib/ui/**` as a matter of policy. If that happens, drop the
`lib/ui/**` glob and re-base the floor downward *in the same change*, or the ratchet will block
every PR until UI coverage catches up.
