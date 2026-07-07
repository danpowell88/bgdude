---
id: TASK-275
title: Restore dropped line coverage and lock it in by raising the CI floor
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 21:42'
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
- [ ] #1 Identify the files/commits that diluted coverage since the last known-good level and add unit or widget tests for the testable code among them
- [ ] #2 Line coverage is restored to at least its prior sustained level (target: raise above the current 65.5%)
- [ ] #3 The ci.yml coverage floor is raised from 60% toward the current level so erosion is caught by CI, with the threshold comment updated
- [ ] #4 Genuinely UI-only files with no unit-testable logic are covered by an integration_test or consistently excluded from the metric (documented), not left as silent 0% dilution
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: user report 2026-07-08 (line coverage dropped)
- CI gate: .github/workflows/ci.yml Coverage gate step (floor 60%, LH/LF over coverage/lcov.info excluding database.g.dart)
- Related: TASK-159 (the coverage gate), TASK-274 (generated-file exclusion)
- Process change shipped alongside: DoD item 4 (coverage did not drop) + CLAUDE.md verify step 4 now require a per-ticket coverage check
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test --coverage test/ green
- [ ] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [ ] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->
