---
id: TASK-248
title: Add a negative-case test for the predictor NaN/Infinite forecast clamp
status: Done
assignee:
  - Claude
created_date: '2026-07-07 13:32'
updated_date: '2026-07-08 02:51'
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
- [x] #1 A test drives the predictor with an input that would yield a NaN/Infinite forecast and asserts it clamps to currentMgdl
- [x] #2 Test lives in a predictor-focused test file and runs under flutter test test/
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-07 (follow-up to TASK-190)
- File: lib/analytics/predictor.dart:356
- No predictor_test.dart currently exists
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 02:48
---
Started: reading predictor.dart to find an input that drives the NaN/Infinite clamp at line 356, then writing a new predictor-focused test.
---

author: Claude
created: 2026-07-08 02:51
---
Added test/predictor_test.dart (new file, matches AC#2's 'predictor-focused test file'). Drives GlucosePredictor.predict() with an otherwise-normal PredictionState (testTherapySettings() fixture) but recentRocMgdlPerMin: double.infinity / double.nan -- this blows the momentum term up to Infinity/NaN on the very first simulated step, exercising predictor.dart:356's clamp directly. Asserts every point.mgdl.isFinite and that the early points (still inside the 30-min momentum-decay window) equal currentMgdl exactly. A third test with a finite ROC=1.0 guards against the assertion passing vacuously if the clamp fired unconditionally instead of only on NaN/Infinite.

Rigor check: commented out the clamp line, reran -- both new tests failed as predicted (Infinity case: leaked through as 400.0 via the ceiling clamp, since Infinity > 400 alone still catches it; NaN case: leaked through as literal NaN, since NaN fails every comparison including the ceiling/floor clamps -- matching the existing code comment's exact reasoning). Reverted; git diff on predictor.dart is clean.

Verified: flutter analyze clean, flutter test --coverage green (1156 tests, 67.54% >= 65% floor), flutter build apk --debug succeeds. No native Kotlin or user-guide changes (pure Dart test addition).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
