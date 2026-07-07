---
id: TASK-248
title: Add a negative-case test for the predictor NaN/Infinite forecast clamp
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 13:32'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 155000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-190 added predictor.dart line 356 if (bg.isNaN || bg.isInfinite) bg = s.currentMgdl; but there is no predictor_test.dart and reconcile_predictions_test.dart does not exercise it. The bolus, carb and therapy-settings guards from the same task all received negative tests; this clamp did not, so a regression that removes or breaks it would go uncaught.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A test drives the predictor with an input that would yield a NaN/Infinite forecast and asserts it clamps to currentMgdl
- [ ] #2 Test lives in a predictor-focused test file and runs under flutter test test/
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-07 (follow-up to TASK-190)
- File: lib/analytics/predictor.dart:356
- No predictor_test.dart currently exists
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
