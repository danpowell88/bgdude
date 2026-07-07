---
id: TASK-273
title: >-
  PumpSnapshot hardening skips the glucose reading and dosing fields — the
  safety-critical ones
status: Done
assignee:
  - Claude
created_date: '2026-07-07 21:27'
updated_date: '2026-07-07 21:37'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 118000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-250 added physical-range hardening to PumpSnapshot.fromJson but applied it only to cosmetic fields: batteryPercent (_clampPercent), reservoirUnits and iobUnits (_clampNonNegative). The single most safety-critical numeric field, cgmMgdl (the glucose reading, pump_snapshot.dart:211), plus every dosing field (basalUnitsPerHour, maxBolusUnits, maxBasalUnitsPerHour at :205-207, lastBolusUnits at :214) are still parsed raw as (j[...] as num?)?.toInt()/.toDouble() with no guard. A torn or hostile platform-channel payload with cgmMgdl -81 (or a huge value) parses to a PumpSnapshot with that value intact and flows unclamped into toCgmSample(), into the predictor currentMgdl (providers.dart), and straight to the UI (BgRange.fromMgdl, home_screen, pump_screen). This is the exact physically-impossible-reading-flows-unchecked failure the commit comment claims to prevent, applied to battery (cosmetic) and skipped for glucose (the core signal). The corpus assertSane in hostile_input_corpus_test.dart only asserts battery/reservoir/IOB invariants, so it does not cover the dangerous field either.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 An out-of-physiological-range cgmMgdl (e.g. negative or absurdly large) is treated as ABSENT/unknown (null), NOT clamped to a plausible-looking value and NOT passed raw — a fake in-range glucose number is worse than no reading for a value the user may act on
- [x] #2 Dosing fields (basal/maxBolus/maxBasal/lastBolus) reject implausible values to null rather than surfacing a fake dose
- [x] #3 hostile_input_corpus_test assertSane asserts a glucose invariant and a dosing invariant, so the corpus covers these fields
- [x] #4 Happy-path decode of valid values is unchanged
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-250)
- File: lib/pump/pump_snapshot.dart:211 cgmMgdl, :205-207 dosing, :214 lastBolus; test/hostile_input_corpus_test.dart assertSane
- Judgment: reject-to-absent (not clamp) for glucose/dosing — clamping -81 to 39 would show a fake LOW the user might treat; contrast reservoir where clamp-to-0 errs in the safe/alarming direction
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 21:37
---
Fixed all 4 ACs in lib/pump/pump_snapshot.dart:

- Added _rejectOutOfRangeInt/_rejectOutOfRangeDouble (reject-to-null, NOT clamp-and-keep like TASK-250's battery/reservoir/IOB helpers -- clamping -81 mg/dL to 39 would show a fake LOW the user might act on for a reading that never happened; contrast reservoir/battery where clamping toward 0 only ever makes the reading MORE alarming, so a clamped garbage value is a safe fallback there).
- Applied to cgmMgdl (20-600, matches the existing sanity band already used in lib/analytics/metrics.dart) and all 4 dosing fields -- basalUnitsPerHour/maxBasalUnitsPerHour (0-15 U/hr) and maxBolusUnits/lastBolusUnits (0-25 U), matching the t:slim X2's real hardware limits and this repo's own default maxBolusUnits=25 in therapy_settings.dart.
- Extended test/hostile_input_corpus_test.dart: added the 4 dosing fields to the 'good' fixture (so hostileVariantsOf's per-key mutation sweep covers them) and added glucose/dosing range invariants to assertSane.
- AC#4 (happy-path unchanged): test/contracts_test.dart's existing golden-fixture contract test already asserts exact pass-through values (basalUnitsPerHour 0.8, maxBolusUnits 15.0, maxBasalUnitsPerHour 3.0, cgmMgdl 120, lastBolusUnits 5.5) -- all comfortably inside the new bounds -- and still passes unchanged.

Rigor check: reverted the fix (git stash), reran hostile_input_corpus_test.dart -- 10 tests failed (huge-number variants for basalUnitsPerHour/cgmMgdl/lastBolusUnits/maxBasalUnitsPerHour/maxBolusUnits and their negative-number counterparts), confirming the new assertions genuinely pin this. Restored the fix; full suite green again.

Pipeline: pub get, build_runner build, flutter analyze clean, flutter test test/ -- 1077/1077 green, flutter build apk --debug succeeded. No native Kotlin touched.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [x] #8 backlog item updated with comments
<!-- DOD:END -->
