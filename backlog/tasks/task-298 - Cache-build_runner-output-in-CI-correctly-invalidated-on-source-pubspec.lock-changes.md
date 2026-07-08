---
id: TASK-298
title: >-
  Cache build_runner output in CI, correctly invalidated on source/pubspec.lock
  changes
status: To Do
assignee: []
created_date: '2026-07-08 04:18'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 196600
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Split off from TASK-287 (AC#3, deliberately deferred -- explicitly the riskiest of the three original levers). Every one of the 4 parallel CI jobs currently reruns dart run build_runner build independently (duplicated cost). Cache the generated output keyed on a hash of pubspec.lock plus all annotated Dart sources, skipping regeneration when unchanged -- but codegen MUST still run correctly when those inputs change, since generated *.g.dart files are not committed. Getting the invalidation wrong would let stale generated code silently pass a run undetected, which is a correctness risk, not just a speed one -- verify explicitly (a real source change still triggers regeneration) before landing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 build_runner output is cached and skipped when pubspec.lock and all annotated sources are unchanged
- [ ] #2 A change to an annotated source file (or pubspec.lock) is verified to still trigger full regeneration, not a stale cache hit
- [ ] #3 All 4 parallel jobs benefit from the shared cache rather than each running build_runner independently
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: split from TASK-287 2026-07-08
- File: .github/workflows/ci.yml (all 4 jobs currently duplicate build_runner)
- CLAUDE.md: build_runner is called out as both slow and the step most likely to break CI -- this is the riskiest lever of the original 3, take it carefully
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
