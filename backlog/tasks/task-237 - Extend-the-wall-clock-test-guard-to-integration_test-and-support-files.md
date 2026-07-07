---
id: TASK-237
title: Extend the wall-clock test guard to integration_test/ and support files
status: To Do
assignee: []
created_date: '2026-07-07 07:48'
labels:
  - code-health
  - testing
milestone: m-8
dependencies: []
priority: low
ordinal: 113246
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The new guard (`test/support/no_wall_clock_guard_test.dart:19-27`, d8e49f3) scans only `test/**/*_test.dart` — it skips `integration_test/` entirely (where wall-clock coupling is worst: demo mode advances on real time) and skips non-`_test` support/fixture files, where one `DateTime.now()` would couple every consumer.

**Reason for change.** The guard exists to stop new relative-time tests landing silently; its blind spots are exactly the highest-risk locations.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Guard walks both roots and all .dart files, keeping the `now-ok` escape hatch
- [ ] #2 Existing legitimate uses annotated or fixed
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Extend the directory walk; triage any new hits.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: hourly quality check 2026-07-07 #3 (finding 3)
- Effort: S
- Where: test/support/no_wall_clock_guard_test.dart
- Related: TASK-170 (introduced), TASK-220
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
