---
id: TASK-256
title: Add a mid-write interruption scenario to the restart harness
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 14:29'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 530000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
RestartSimulation with InMemoryHistoryRepository and in-memory KvStore writes synchronously and every test awaits the writes or a short delay before crashing, then dispose is a clean teardown. No test kills the process mid-saveCgm, mid-KvStore-write or mid-notification-schedule, so the partial-write or torn-state path a crash-restart ticket implies is never hit.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A scenario simulates a crash during an in-flight write (torn or partial state) and asserts the app recovers to a consistent state
- [ ] #2 Covers at least a mid-DB-write and a mid-notification-schedule interruption
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-194)
- Files: test/support/restart_simulation.dart, test/restart_recovery_test.dart
- Related: TASK-210 (shared fault-injection doubles) may provide the interruption primitive
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
