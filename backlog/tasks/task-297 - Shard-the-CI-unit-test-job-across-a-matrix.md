---
id: TASK-297
title: Shard the CI unit-test job across a matrix
status: To Do
assignee: []
created_date: '2026-07-08 04:18'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 196500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Split off from TASK-287 (AC#1, deliberately deferred as its own careful pass). flutter test --coverage test/ (1161+ tests, one process) is the test job's dominant cost. Shard across a matrix (e.g. by directory or a partition file), merge per-shard lcov.info files before the coverage gate runs, and keep the gate's floor check working on the merged total.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 flutter test runs sharded across a matrix strategy
- [ ] #2 Coverage is merged across shards before the gate check runs, and the gate still correctly fails a real coverage regression
- [ ] #3 Wall-clock for the test job drops materially vs the unsharded baseline
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: split from TASK-287 2026-07-08
- File: .github/workflows/ci.yml test job
- Related: TASK-159/275 own the coverage gate this must keep intact
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
