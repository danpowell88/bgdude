---
id: TASK-287
title: >-
  Speed up the CI test pipeline: shard the unit tests, parallelise jobs, cache
  codegen
status: To Do
assignee:
  - Claude
created_date: '2026-07-08 01:54'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 196000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The CI pipeline runs as a single sequential job (ci.yml): pub get, then build_runner, then analyze, then flutter test --coverage test/ (about 962 test() calls in one unsharded run), then flutter build apk --debug. The two slowest blocks (codegen and the APK build) run serially on the critical path with the test run, and nothing is sharded, so wall-clock is the sum of everything. Three levers: (1) shard flutter test across a matrix so the largest serial block runs in parallel; (2) run analyze, unit tests, and the APK build as parallel jobs rather than one sequential job (the APK build does not depend on the test result); (3) cache the build_runner output keyed on a hash of pubspec.lock plus the drift schema and annotated sources, skipping regeneration when inputs are unchanged. build_runner is called out in CLAUDE.md as both slow and the step most likely to break CI, so caching it (with correct invalidation) is high value -- but codegen MUST still run when inputs change because the generated *.g.dart files are not committed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 flutter test is sharded across a matrix (coverage still merged for the gate) and the suite wall-clock drops materially
- [ ] #2 analyze / unit tests / APK build run as parallel jobs rather than one sequential job
- [ ] #3 build_runner output is cached and skipped when its inputs are unchanged, and correctly regenerated when pubspec.lock or an annotated source changes (verified: a source change still triggers codegen)
- [ ] #4 The coverage gate still runs on the merged coverage and the total pipeline is faster end to end
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: user request 2026-07-08 (make the test pipeline faster)
- File: .github/workflows/ci.yml (single job, timeout-minutes 30)
- Related: TASK-218 (Gradle cache, done) covered only Gradle deps; TASK-159/275 own the coverage gate that sharding must keep intact
- Codegen-cache invalidation is the risky part -- see the CLAUDE.md verify pipeline note that *.g.dart are not committed
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
