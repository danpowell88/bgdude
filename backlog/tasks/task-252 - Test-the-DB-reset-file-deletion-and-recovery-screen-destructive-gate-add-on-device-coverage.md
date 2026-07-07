---
id: TASK-252
title: >-
  Test the DB reset file deletion and recovery-screen destructive gate, add
  on-device coverage
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 14:28'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 160000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
db_open_diagnosis_test.dart covers only classifyDbOpenFailure and salvageExportJson on a plain in-memory DB. Untested: deleteDatabaseFile removes the main file AND the wal, shm and journal sidecars; the quick_check-not-ok corruptedData branch with a still-open salvage db; the recovery screen double-confirm gate; and that a non-salvageable verdict does NOT expose an export path. No integration test was added for the new DbRecoveryScreen, which the project convention requires for any new user-facing screen.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Unit test: deleteDatabaseFile removes the main DB and all sidecar files
- [ ] #2 Unit test: the corruptedData branch exposes salvage export while the keyOrHeaderCorrupt branch does not
- [ ] #3 Integration test exercises the recovery screen and its destructive double-confirm on a device
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-192)
- Files: lib/data/database.dart deleteDatabaseFile, lib/data/db_open_diagnosis.dart, lib/ui/db_recovery_screen.dart
- Depends on the destructive semantics settled by TASK-249
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
