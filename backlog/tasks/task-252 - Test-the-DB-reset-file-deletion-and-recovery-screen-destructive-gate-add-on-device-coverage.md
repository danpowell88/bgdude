---
id: TASK-252
title: >-
  Test the DB reset file deletion and recovery-screen destructive gate, add
  on-device coverage
status: In Progress
assignee:
  - Claude
created_date: '2026-07-07 14:28'
updated_date: '2026-07-07 20:52'
labels:
  - detail-needed
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
- [x] #1 Unit test: deleteDatabaseFile removes the main DB and all sidecar files
- [x] #2 Unit test: the corruptedData branch exposes salvage export while the keyOrHeaderCorrupt branch does not
- [ ] #3 Integration test exercises the recovery screen and its destructive double-confirm on a device
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-192)
- Files: lib/data/database.dart deleteDatabaseFile, lib/data/db_open_diagnosis.dart, lib/ui/db_recovery_screen.dart
- Depends on the destructive semantics settled by TASK-249
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 20:43
---
Started: checking current state of database.dart (TASK-249 already replaced deleteDatabaseFile with a non-destructive retireDatabaseFile) and db_open_diagnosis.dart, then adding real unit-test coverage for AC#1/#2; AC#3's on-device integration test is written but can't be executed here (documented emulator-connectivity limitation).
---

author: Claude
created: 2026-07-07 20:52
---
AC#1/#2 done, AC#3 written but genuinely unexecuted here (detail-needed for the emulator run, matching TASK-127/226/228/220's convention).

AC#1: test/db_open_diagnosis_test.dart's retireDatabaseFile group extended to cover all 3 sidecars (wal/shm/journal, not just wal/shm) plus a 'no sidecars present' case (missing sidecar is a no-op, not an error). Note: the ticket's literal title references 'deleteDatabaseFile', which TASK-249 already replaced with the non-destructive retireDatabaseFile (rename to .bak-<epoch>, never delete) -- adapted the AC to the current function/semantics.

AC#2: new test/db_recovery_screen_test.dart (9 tests) drives DbRecoveryScreen directly via ProviderScope overrides of dbOpenDiagnosisProvider/dbOpenSalvageDbProvider (the screen's actual seam), bypassing openHistoryRepository() entirely -- confirmed via db_open_diagnosis_test.dart's own existing note that function can't run end-to-end on this desktop host at all (needs sqlcipher_flutter_libs' native lib, Android-only). Covers: corruptedData+open-db exposes the export button; keyOrHeaderCorrupt does NOT even when a db is passed (salvageable gates on BOTH diagnosis AND db); corruptedData with no db doesn't either; schemaNewerThanApp offers neither export nor reset. Also added full double-confirm-gate coverage: tapping reset shows dialog 1 (not an immediate reset); cancelling dialog 1 blocks dialog 2; confirming dialog 1 shows dialog 2; cancelling dialog 2 blocks the action; confirming BOTH reaches _resetStorage() (observed via the busy spinner appearing, since path_provider/secure_storage aren't mocked here so the async chain itself can't resolve headlessly). Verified rigor: temporarily loosened the export gate to salvageDb != null (dropping the diagnosis.salvageable check) and reran -- the keyOrHeaderCorrupt test correctly failed. Reverted.

AC#3: integration_test/db_recovery_screen_test.dart (new) -- boots the real app with dbOpenErrorProvider/dbOpenDiagnosisProvider overridden, taps the storage banner, confirms it reaches DbRecoveryScreen, and exercises through the first reset confirmation dialog. Cannot be executed in this session (no working emulator connectivity here, the same pre-existing limitation documented for TASK-127/226/228/220) -- flagging rather than claiming it passed.

Pipeline: flutter analyze clean, flutter test test/ 1050/1050, flutter build apk --debug succeeded. No native Kotlin, no user-visible change (test-only).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [x] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
