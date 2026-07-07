---
id: TASK-273
title: >-
  PumpSnapshot hardening skips the glucose reading and dosing fields — the
  safety-critical ones
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 21:27'
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
- [ ] #1 An out-of-physiological-range cgmMgdl (e.g. negative or absurdly large) is treated as ABSENT/unknown (null), NOT clamped to a plausible-looking value and NOT passed raw — a fake in-range glucose number is worse than no reading for a value the user may act on
- [ ] #2 Dosing fields (basal/maxBolus/maxBasal/lastBolus) reject implausible values to null rather than surfacing a fake dose
- [ ] #3 hostile_input_corpus_test assertSane asserts a glucose invariant and a dosing invariant, so the corpus covers these fields
- [ ] #4 Happy-path decode of valid values is unchanged
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-250)
- File: lib/pump/pump_snapshot.dart:211 cgmMgdl, :205-207 dosing, :214 lastBolus; test/hostile_input_corpus_test.dart assertSane
- Judgment: reject-to-absent (not clamp) for glucose/dosing — clamping -81 to 39 would show a fake LOW the user might treat; contrast reservoir where clamp-to-0 errs in the safe/alarming direction
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
