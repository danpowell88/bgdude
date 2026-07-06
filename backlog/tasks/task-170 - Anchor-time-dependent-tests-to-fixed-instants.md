---
id: TASK-170
title: Anchor time-dependent tests to fixed instants
status: To Do
assignee: []
created_date: '2026-07-06 09:16'
labels:
  - code-health
  - testing
milestone: m-8
dependencies: []
priority: medium
ordinal: 170000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `test/jobs_test.dart:23` seeds `SimulatedDay.generate(now: DateTime.now(), ...)` so behaviour depends on the wall-clock time the suite runs (and DST/local-midnight edges); `test/glucose_hero_test.dart:16` also pumps a widget with `DateTime.now()`.

**Reason for change.** Flaky-by-time-of-day tests erode trust and get muted; tests must be deterministic regardless of when they run.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Both tests are anchored to fixed instants (passing `asOf`/fixed now)
- [ ] #2 A grep-based guard (or convention note in `test/support`) exists against new `DateTime.now()` in tests
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Replace `DateTime.now()` in `test/jobs_test.dart:23` and `test/glucose_hero_test.dart:16` with fixed instants.
- Add a grep-based guard test (or a convention note in `test/support`) flagging new `DateTime.now()` usages under `test/`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (test-quality finding 8)
- Effort: S
- Where: `test/jobs_test.dart`, `test/glucose_hero_test.dart`, `test/support/`
- Related: TASK-39
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
