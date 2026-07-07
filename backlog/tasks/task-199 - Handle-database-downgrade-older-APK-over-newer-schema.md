---
id: TASK-199
title: Handle database downgrade (older APK over newer schema)
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:09'
updated_date: '2026-07-07 16:23'
labels:
  - code-health
  - data-integrity
milestone: m-8
dependencies: []
priority: medium
ordinal: 111300
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/database.dart:169` is at `schemaVersion 4` with a `MigrationStrategy` (`lib/database.dart:190-223`) defining only onUpgrade/beforeOpen — no `onDowngrade`. Installing an older build over a v4 database (sideload rollback) opens a schema newer than the generated code and throws at first query, degrading to the silent in-memory fallback: all writes lost while the data sits intact on disk.

- Upgrade atomicity is verified safe (drift 2.20 wraps onUpgrade in a transaction; DDL is inside it)

**Reason for change.** A rollback install must land in a defined, non-destructive state instead of silently discarding all writes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A downgrade lands in a defined state — fail loudly with a clear this-build-is-older-than-your-data message (no in-memory masquerade)
- [x] #2 Test: open a DB stamped user_version=5 under schemaVersion 4, assert the defined outcome and no corruption
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Detect a stored schema version newer than `schemaVersion` at open (beforeOpen or onDowngrade path)
- Fail loudly with a clear this-build-is-older-than-your-data message instead of falling back to in-memory
- Add a test opening a DB stamped user_version=5 under schemaVersion 4 asserting the defined outcome and no corruption
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (dart finding 4)
- Effort: M
- Where: `lib/database.dart:169-223`
- Related: TASK-192 (corruption/wrong-key — distinct), TASK-13
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 16:10
---
Started: reviewing database.dart's schemaVersion/MigrationStrategy and db_open_diagnosis.dart to add a defined, loud downgrade path instead of the current silent in-memory fallback.
---

author: Claude
created: 2026-07-07 16:23
---
Root cause: this drift version (2.28.2) has NO separate onDowngrade callback -- its own doc comment says onUpgrade runs for BOTH directions ('Schema version upgrades and downgrades will both be run here'). Without a guard, a downgrade (from=5 > to=4) fell through every 'if (from < N)' step doing nothing, and drift would silently stamp user_version down to 4 anyway against a schema it never actually understood. Added DatabaseDowngradeException (database.dart) + a from>to check as the FIRST statement in onUpgrade, before any migration step. Added DbOpenDiagnosis.schemaNewerThanApp (not salvageable) + a new resetIsSensible getter (false only for this diagnosis, since the data isn't corrupt -- resetting would destroy genuinely intact newer data for no reason); classifyDbOpenFailure recognizes the new exception first. db_recovery_screen.dart: new title/explain text steering the user to install the newer app build instead, and the destructive reset button is hidden entirely for this diagnosis (gated on resetIsSensible). main.dart's error banner text updated too. AC#2 test: writes a plain (unencrypted, since SQLCipher can't open on this desktop host) sqlite3 file stamped user_version=5 via a raw sqlite3 connection BEFORE drift ever touches it, opens it through AppDatabase (schemaVersion 4), asserts DatabaseDowngradeException(from:5, to:4) throws, then re-opens the raw file afterward and confirms user_version is STILL 5 (not stomped) and zero tables were created (proving the guard fired before any DDL). Also added classifyDbOpenFailure/salvageable/resetIsSensible unit tests for the new category. flutter analyze clean, build_runner succeeded, flutter test test/ green (965 tests), flutter build apk --debug succeeded. doc/user-guide.html's storage-recovery paragraph updated for the new scenario and the conditional reset button. No native Kotlin changed -- DoD #5 n/a; no new screen/flow (existing recovery screen gains a new diagnosis branch) -- DoD #7 n/a.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
