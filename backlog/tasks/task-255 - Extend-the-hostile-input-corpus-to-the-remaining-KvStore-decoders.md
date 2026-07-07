---
id: TASK-255
title: Extend the hostile-input corpus to the remaining KvStore decoders
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 14:29'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 520000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The corpus covers 4 targets (PumpSnapshot, TherapySettings, SavedMeal, NutritionPanel) but restoreJsonGuarded is used for at least six more persisted decoders not exercised: NotificationPrefs, UserProfile, AlertThresholds, MedicationMode, WeatherSettings, NightscoutConfig in providers.dart. restoreJsonGuarded catches an escaping throw, but wrong-type, huge or negative values that parse successfully into out-of-range settings are never exercised, so AC number 2 (each KV decoder survives the full table) is not met.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every restoreJsonGuarded-wrapped decoder is in the corpus
- [ ] #2 Cases assert output invariants for values that parse but are out of range, not just no-throw
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-193 AC number 2)
- Related: TASK-206 (guard persisted-store parsers), TASK-210 (shared fault-injection doubles)
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
