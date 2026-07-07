---
id: TASK-275
title: Restore dropped line coverage and lock it in by raising the CI floor
status: Done
assignee:
  - Claude
created_date: '2026-07-07 21:42'
updated_date: '2026-07-07 22:56'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 120000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Line coverage has eroded. The CI gate (TASK-159) only fails on a collapse below a 60% floor, so gradual dilution goes unnoticed: a fresh flutter test --coverage test/ on 2026-07-08 measures 65.5% (7553/11523 lines excluding database.g.dart), down from the trend the floor comment tracks, because recent commits added lib/ lines (new screens system_health_screen and db_recovery_screen, big churn in glucose_report_screen and meal_library_screen, plus supporting logic) without matching unit/widget tests. UI-only screens are meant to be covered by the integration_test/ suite rather than unit tests, so the fix is to (a) identify which recently-added TESTABLE code lost coverage, (b) add unit/widget tests to recover it, and (c) raise the ci.yml floor toward the current sustained level so the gain is locked and future erosion is caught. Going forward each ticket verifies coverage does not drop before committing (added to the Definition of Done and the CLAUDE.md verify pipeline in the same change as this ticket).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Identify the files/commits that diluted coverage since the last known-good level and add unit or widget tests for the testable code among them
- [x] #2 Line coverage is restored to at least its prior sustained level (target: raise above the current 65.5%)
- [x] #3 The ci.yml coverage floor is raised from 60% toward the current level so erosion is caught by CI, with the threshold comment updated
- [x] #4 Genuinely UI-only files with no unit-testable logic are covered by an integration_test or consistently excluded from the metric (documented), not left as silent 0% dilution
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: user report 2026-07-08 (line coverage dropped)
- CI gate: .github/workflows/ci.yml Coverage gate step (floor 60%, LH/LF over coverage/lcov.info excluding database.g.dart)
- Related: TASK-159 (the coverage gate), TASK-274 (generated-file exclusion)
- Process change shipped alongside: DoD item 4 (coverage did not drop) + CLAUDE.md verify step 4 now require a per-ticket coverage check
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 22:41
---
Started: identify testable (non-UI-screen, non-generated) files with the worst coverage, add unit tests for the highest-value gaps, then raise the ci.yml floor to lock in the gain.
---

author: Claude
created: 2026-07-07 22:56
---
All 4 ACs done. Line coverage 65.5% -> 67.4% (7785/11546, excl. database.g.dart).

AC#1/#2 (identify + restore): targeted the biggest non-UI, non-generated gaps (screens are covered by integration_test/, see AC#4) --
- lib/data/health_sync.dart: 5.5% -> 93.7% (test/health_sync_test.dart, 27 tests). HealthSyncService.fetch() had its entire per-type transformation table (16 numeric mappings), nutrition-carb extraction, workout activity naming, and sleep-stage aggregation (asleep/deep/awake minutes, pre-noon night-key rollback, zero-total efficiency guard) completely untested -- only ever exercised against the real Health Connect plugin on-device. Health's methods aren't final, so a fake subclass overriding just getHealthDataFromTypes/removeDuplicates exercises everything else headlessly with real HealthDataPoint/HealthValue fixtures.
- lib/timeline/day_event.dart: 29.4% -> 100% (extended test/day_event_disposition_test.dart, +21 tests). label/emoji getters, IgnoreReason.label/annotationKind for all 6 reasons, DayEvent.copyWith, and toAnnotation's suggestedCarbsGrams/endTime-fallback/no-reason paths were all untested.
- lib/pump/probe_event.dart: 6.1% -> 100% (test/probe_event_test.dart, 15 tests). ProbeEvent.fromMap/isTx/time/cargoBytes/toReport and ProbeCatalogFlat.sweepable's parametric-filter + dedup-by-className logic were all untested.
Every new test rigor-checked (temporarily reintroduced the exact bug, confirmed the test fails with the predicted symptom, reverted, confirmed git diff clean) -- caught a real mismatch in the first probe_event_test.dart draft too (cargoBytes off-by-one).

AC#3 (raise the floor): ci.yml's Coverage gate floor 60% -> 65% (leaves ~2.4pt margin below the 67.4% sustained level, matching the existing below-actual-margin convention). CLAUDE.md's verify-pipeline comment updated to match.

AC#4 (UI-only files): confirmed by inspection that every one of the worst-offending 0-3%-covered lib/ui/*_screen.dart files (glucose_report/protocol_explorer/notification_settings/therapy_report/exercise_mode/advanced/insulin_report/correlation_report/basal_recommendations/confirmation_inbox/model_accuracy/glucose_meter/model_report/meals_report/ai_model/system_health/events_journal/weather_settings/reports_hub/medication_mode/db_recovery_screen.dart) IS reached by an existing integration_test/*.dart file (features_settings_test.dart opens every settings sub-screen by its nav label; features_reports_test.dart opens all seven reports; features_protocol_explorer_test.dart; db_recovery_screen_test.dart has its own dedicated file) -- genuinely unexecuted only because of this session's emulator-connectivity limitation, not missing coverage. The one genuine non-UI, non-integration-testable exception is lib/integrations/glucose_meter_transport_fbp.dart (0%, 59 lines) -- a concrete flutter_blue_plus GATT-client wrapper with no fake/injectable seam at that layer, same pattern as the native BLE code: the abstraction (GlucoseMeterTransport, tested via glucose_meter_controller_test.dart) is covered, the third-party-wrapping concrete implementation isn't and can't be without a real meter. Documented here per AC#4's 'or consistently excluded/documented' clause rather than left as silent, unexplained dilution.

Pipeline: build_runner build, flutter analyze clean, flutter test --coverage test/ 1137/1137 green, flutter build apk --debug succeeded. No native Kotlin touched.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test --coverage test/ green
- [x] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [x] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->
