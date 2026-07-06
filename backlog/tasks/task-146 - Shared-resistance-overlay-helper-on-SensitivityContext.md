---
id: TASK-146
title: Shared resistance-overlay helper on SensitivityContext
status: To Do
assignee: []
created_date: '2026-07-06 08:42'
labels:
  - code-health
  - insights
  - cleanup
milestone: m-8
dependencies: []
priority: low
ordinal: 146000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/insights/illness_mode.dart:189-202` and `lib/insights/medication_mode.dart:46-60` duplicate the same overlay math (`resistanceMultiplier * boost`, `.clamp(0.5, 1.6)`, `confidence = max(base, 0.7)`, dedup-append reason) with separately defined constants that can drift.

**Reason for change.** Two copies of clinical overlay math with separate constants will diverge; one helper keeps the clamps and confidence floor consistent.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A `SensitivityContext.withResistanceOverlay({boost, reason, minConfidence})` exists in `analytics/therapy_settings.dart`
- [ ] #2 Both modes delegate to it
- [ ] #3 The constants are defined once
- [ ] #4 A unit test covers the helper
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

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
