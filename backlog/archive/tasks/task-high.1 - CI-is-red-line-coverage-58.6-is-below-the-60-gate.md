---
id: TASK-HIGH.1
title: 'CI is red: line coverage 58.6% is below the 60% gate'
status: To Do
assignee: []
created_date: '2026-07-07 21:29'
labels: []
milestone: m-8
dependencies: []
parent_task_id: TASK-HIGH
ordinal: 721000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
CI has failed the Coverage gate step on every run since commit 3683c10 (2026-07-07 18:06), ~19 consecutive runs over ~3 hours (last green run: TASK-207, 17:50). Root cause: lib/data/database.g.dart (drift-generated, 2515 lines, currently only 26.9% hit) is included in the lcov.info line-coverage sum alongside hand-written code. It has grown substantially with this session's schema additions (annotations, health tables etc.), and most of its lines are unused-by-the-app boilerplate (alternate constructors, unused column accessors) that will never be exercised by app-level tests. Confirmed locally: excluding just this one generated file from the awk sum in .github/workflows/ci.yml's Coverage gate step raises the score from 58.6% (8222/14030) to 65.5% (7546/11515) -- comfortably above the 60% floor, with zero change to real hand-written-code coverage.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The Coverage gate step in .github/workflows/ci.yml excludes generated files (lib/data/database.g.dart) from the line-coverage sum
- [ ] #2 A CI run on main goes green again
<!-- AC:END -->

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
