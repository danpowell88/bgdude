---
id: TASK-171
title: 'MealDetector negative case: rise explained by IOB'
status: Done
assignee:
  - Claude
created_date: '2026-07-06 09:16'
updated_date: '2026-07-07 07:25'
labels:
  - code-health
  - testing
  - ml
milestone: m-8
dependencies: []
priority: medium
ordinal: 107600
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `test/event_detectors_test.dart:26-51` tests a clean unexplained rise and a flat trace, but not the key false-positive case — a rise WITH insulin on board (normal post-bolus excursion) must NOT flag an unannounced meal.

**Reason for change.** That false positive drives alarm fatigue and bad training annotations; the detector needs a pinned negative case.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Test: the same rise shape with a recent bolus present → no detection (or below the confidence threshold)
- [x] #2 The same negative case covers the confirmation-inbox scan path
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a test reusing the existing rise trace but with a recent bolus/IOB present, asserting no meal detection (or confidence below threshold).
- Add the equivalent negative through the confirmation-inbox scan path.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (test-quality finding 9)
- Effort: S
- Where: `test/event_detectors_test.dart`
- Related: TASK-109 (base coverage, done), TASK-48 (wiring)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 07:21
---
Started: pinned negative — the same rise with sufficient IOB must not flag an unannounced meal (detector + confirmation-scan path).
---

author: Claude
created: 2026-07-07 07:25
---
Done. Note the ticket's 'rise explained by IOB' framing is physiologically inverted (insulin only lowers glucose); the actual false positive is the pump-bolused-but-unlogged meal, which is what the fix + tests pin.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Behavior fix + pins: ConfirmationService.scan's 'announced' check now includes a manual (non-automatic, units>0) bolus within carbLogWindow of the rise. Tests: detector-level (rise + bolus still yields a candidate — documented physiology: insulin never explains a rise, so suppression belongs to consumers), scan-level negative (bolused rise -> no unannounced-meal confirmation), and the auto-microbolus case still surfaces. Verified: analyze clean, 737 tests green, APK builds.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [x] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
