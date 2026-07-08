---
id: TASK-255
title: Extend the hostile-input corpus to the remaining KvStore decoders
status: Done
assignee:
  - Claude
created_date: '2026-07-07 14:29'
updated_date: '2026-07-08 07:38'
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
- [x] #1 Every restoreJsonGuarded-wrapped decoder is in the corpus
- [x] #2 Cases assert output invariants for values that parse but are out of range, not just no-throw
<!-- AC:END -->



## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-193 AC number 2)
- Related: TASK-206 (guard persisted-store parsers), TASK-210 (shared fault-injection doubles)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 07:37
---
Started+done: extended test/pump/hostile_input_corpus_test.dart to cover all 7 remaining restoreJsonGuarded decoders (NotificationPrefs, UserProfile, AlertThresholds, MedicationMode, WeatherSettings, NightscoutConfig, SystemHealthReport -- the last one was not named in the ticket description but is also restoreJsonGuarded-wrapped, so it belongs in AC number 1 "every decoder"). AC number 2 finding worth flagging: most of these decoders have NO clamp/range validation at all on their numeric fields today -- lowMgdl/highMgdl/urgentLowMgdl (AlertThresholds), lat/lon (WeatherSettings), repeatMinutes/startMinute/endMinute (NotificationPrefs), consecutiveFailures (SystemHealthReport), birthYear/weightKg/heightCm (UserProfile) all pass a hostile huge/negative number straight through unclamped -- unlike PumpSnapshot/SavedMeal which do clamp. Rather than silently expanding this ticket into fixing seven unrelated settings decoders, each new test group asserts the invariant the code actually guarantees today (never-null defaults, always-populated maps, enum fields that cannot come back invalid, finite-or-null for raw numeric fields) and documents the missing-clamp gap in a comment at the top of the new tests. Recommend a follow-up ticket if the missing range validation on AlertThresholds mg/dL values in particular is judged worth closing (it is the one thats plausibly safety-adjacent, since it drives alert firing) -- flagging rather than guessing at scope. Rigor-checked: temporarily broke NotificationPrefs.fromJsons "every category always populated" guarantee (skip instead of default-fill), confirmed 6 of the new tests failed with the predicted Expected 20 / Actual 1 symptom, reverted, confirmed git diff --stat clean. Pipeline green: analyze clean, 1314/1314 tests pass (129 new), coverage unchanged at 67.94% (floor 65%), apk debug build succeeds.
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
