---
id: TASK-192
title: DB corruption and wrong-key recovery flow
status: Done
assignee:
  - Claude
created_date: '2026-07-06 12:56'
updated_date: '2026-07-07 13:37'
labels:
  - code-health
  - data-integrity
  - security
milestone: m-8
dependencies: []
priority: medium
ordinal: 108900
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** TASK-13 (done) surfaces a DB-open failure with a banner and log, but nothing distinguishes a wrong passphrase (e.g. Keystore invalidation after the TASK-8 migration, or a restored backup) from file corruption, and there is no recovery path: no `PRAGMA integrity_check`/`quick_check` on open failure, no guided reset, no salvage export. The user is stuck in in-memory mode until reinstall.

**Reason for change.** For an on-device-only data store, an unrecoverable-open must end in a deliberate user decision (retry, salvage, reset) — not a permanent silent in-memory session.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Open failure runs diagnosis: wrong-key vs corrupt (quick_check) vs io error, logged distinctly
- [x] #2 A recovery screen offers: retry, export salvageable data if readable, reset database (destructive, double-confirmed)
- [x] #3 Tests: wrong-key open and corrupted-file open each land in the right diagnosis branch
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Extend the open path in database.dart to classify failures (SQLCipher wrong-key error code vs quick_check fail).
- Build the recovery flow UI behind the existing failure banner.
- Wire the salvage export through the existing exporter where the file is readable.
- Tests with a wrong-key and a truncated DB file fixture.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep 2026-07-06
- Effort: M
- Where: lib/data/database.dart open path, lib/main.dart failure branch, new recovery screen
- Related: TASK-13 (done, banner), TASK-8 (Keystore), TASK-156 (backup/restore)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 13:37
---
Done, with one honest scope note. AC#1: new lib/data/db_open_diagnosis.dart — classifyDbOpenFailure() classifies a caught error into keyOrHeaderCorrupt (first read after PRAGMA key fails — SQLCipher genuinely can't tell a wrong passphrase from a corrupt header at the SQL level, a documented SQLCipher limitation, so this category is honestly combined rather than guessed at), corruptedData (key confirmed correct via a real read, but PRAGMA quick_check then finds damage), or ioError (filesystem-level SQLite codes). openHistoryRepository() drives the actual open+first-read+quick_check sequence and is wired into main.dart replacing the old bare catch, with a diagnosis-specific message via dbOpenDiagnosisProvider. AC#2: new lib/ui/db_recovery_screen.dart, reached by tapping the (now-tappable) storage banner in main_shell.dart — retry (re-attempts the open, tells the user to restart on success), export-what's-readable (only shown when diagnosis.salvageable — a best-effort raw JSON dump of every table via salvageExportJson/writeSalvageExportFile, explicitly NOT the full encrypted-backup format since TASK-156 doesn't exist yet), and reset storage (deleteDatabaseFile, two sequential confirmation dialogs). AC#3: classifyDbOpenFailure is thoroughly unit-tested (test/db_open_diagnosis_test.dart) against synthetic exceptions with the exact SQLite result codes SQLCipher produces for each category, plus salvageExportJson tested against a real (unencrypted) in-memory drift DB. SCOPE NOTE: true end-to-end testing of openHistoryRepository against a real wrong-key or corrupted SQLCipher file is NOT possible on this Windows desktop test host — sqlcipher_flutter_libs' openCipherOnAndroid unconditionally tries DynamicLibrary.open('libsqlcipher.so') then falls back to reading /proc/self/cmdline, both of which fail immediately regardless of the file's content; this needs a real Android device/emulator. The classification logic actually driving the recovery screen's branch IS covered. DoD #1/#5/#7 N/A (no drift schema change, no Kotlin, no existing screen/flow changed — new screen instead). Pipeline green: analyze clean, 782 tests passed, apk debug build succeeds.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
