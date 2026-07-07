---
id: TASK-249
title: >-
  DB recovery reset must not delete an intact file on a key-mismatch verdict
  (data-loss)
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 14:28'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 105000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The keyOrHeaderCorrupt bucket in the TASK-192 recovery flow covers BOTH a genuinely corrupt header AND a plain key mismatch where the encrypted file is perfectly intact. db_recovery_screen.dart tells the user no data can be salvaged either way, a reset is the only path forward, and deleteDatabaseFile() then erases the file plus WAL/shm/journal. This is a real data-loss path for irreplaceable glucose/insulin history, and it is reachable from a RECOVERABLE transient: secure_key.dart open() regenerates and overwrites the passphrase whenever FlutterSecureStorage.read() returns null (a transient Keystore read failure, common after OS updates, device restores or biometric changes) and no legacy key exists. A transient null read then yields a new key, the intact DB fails to open with SQLITE_NOTADB, and the only offered action erases everything.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 On a key-mismatch or unidentifiable-header verdict the reset preserves the encrypted file (rename or backup) or offers to export the raw db, rather than deleting it
- [ ] #2 secure_key.dart does not silently regenerate the passphrase on a transient null read without distinguishing not-yet-set from read-failure
- [ ] #3 Recovery copy no longer asserts the data is unsalvageable when the cause may be a recoverable key mismatch
- [ ] #4 Test: a wrong-key open against an intact file never results in file deletion
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-192)
- Files: lib/ui/db_recovery_screen.dart keyOrHeaderCorrupt branch, lib/data/database.dart deleteDatabaseFile, lib/data/secure_key.dart open()
- Safety: destroying logged glucose/insulin history on a false-positive corruption verdict is the most serious failure mode of this feature
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
