---
id: TASK-146
title: Shared resistance-overlay helper on SensitivityContext
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:42'
updated_date: '2026-07-07 15:27'
labels:
  - code-health
  - insights
  - cleanup
milestone: m-8
dependencies: []
priority: low
ordinal: 110400
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/insights/illness_mode.dart:189-202` and `lib/insights/medication_mode.dart:46-60` duplicate the same overlay math (`resistanceMultiplier * boost`, `.clamp(0.5, 1.6)`, `confidence = max(base, 0.7)`, dedup-append reason) with separately defined constants that can drift.

**Reason for change.** Two copies of clinical overlay math with separate constants will diverge; one helper keeps the clamps and confidence floor consistent.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A `SensitivityContext.withResistanceOverlay({boost, reason, minConfidence})` exists in `analytics/therapy_settings.dart`
- [x] #2 Both modes delegate to it
- [x] #3 The constants are defined once
- [x] #4 A unit test covers the helper
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add `withResistanceOverlay({boost, reason, minConfidence})` to `SensitivityContext` in `analytics/therapy_settings.dart`.
- Delegate illness and medication modes to it; define the clamp/confidence constants once.
- Add a unit test.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/insights/illness_mode.dart:189-202`, `lib/insights/medication_mode.dart:46-60`)
- Effort: S
- Where: `lib/analytics/therapy_settings.dart`, `lib/insights/illness_mode.dart`, `lib/insights/medication_mode.dart`
- Related: positions future modes to reuse
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 15:22
---
Started: reviewing illness_mode.dart and medication_mode.dart's duplicated resistance-overlay math to extract a shared SensitivityContext helper.
---

author: Claude
created: 2026-07-07 15:27
---
Added SensitivityContext.withResistanceOverlay({boost, reason, minConfidence}) to analytics/therapy_settings.dart, plus the three previously-duplicated constants defined once on the class: kOverlayResistanceFloor/kOverlayResistanceCeiling (0.5/1.6, now also reused in the constructor's own assert instead of separately hardcoded there) and kDefaultMinOverlayConfidence (0.7). illness_mode.dart and medication_mode.dart both now delegate to it and had their own separately-defined 0.7 confidence-floor constants removed entirely (the actual drift risk this ticket called out). Both files' dart:math imports dropped since overlay() no longer needs math.max directly. Added 5 unit tests on the helper itself (multiply+floor, confidence never lowered, both clamp directions, reason dedup, minConfidence override) plus re-ran the existing illness_mode_test.dart/medication_mode_test.dart suites unmodified to confirm behavior-preserving (all still pass with identical assertions). flutter analyze clean, flutter test test/ green (950 tests), flutter build apk --debug succeeded. No user-visible/native/screen changes -- DoD #5/#6/#7 n/a.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
