---
id: TASK-192
title: DB corruption and wrong-key recovery flow
status: To Do
assignee: []
created_date: '2026-07-06 12:56'
labels:
  - code-health
  - data-integrity
  - security
milestone: m-8
dependencies: []
priority: medium
ordinal: 192000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** TASK-13 (done) surfaces a DB-open failure with a banner and log, but nothing distinguishes a wrong passphrase (e.g. Keystore invalidation after the TASK-8 migration, or a restored backup) from file corruption, and there is no recovery path: no `PRAGMA integrity_check`/`quick_check` on open failure, no guided reset, no salvage export. The user is stuck in in-memory mode until reinstall.

**Reason for change.** For an on-device-only data store, an unrecoverable-open must end in a deliberate user decision (retry, salvage, reset) — not a permanent silent in-memory session.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Open failure runs diagnosis: wrong-key vs corrupt (quick_check) vs io error, logged distinctly
- [ ] #2 A recovery screen offers: retry, export salvageable data if readable, reset database (destructive, double-confirmed)
- [ ] #3 Tests: wrong-key open and corrupted-file open each land in the right diagnosis branch
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

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
