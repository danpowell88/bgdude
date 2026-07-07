---
id: TASK-254
title: >-
  Gate the DB integrity scan so quick_check does not run a full decrypt on every
  launch
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 14:29'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 510000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
openHistoryRepository runs select 1 then a full PRAGMA quick_check synchronously in the startup path on every cold start, including the healthy path. quick_check is a page-by-page scan and every page is SQLCipher-decrypted; before TASK-192 open did no read at all. For a tool that accumulates years of CGM data (about 288 rows per day) this is a multi-second launch cost that only grows. Separately, writeSalvageExportFile writes to the temp dir and never cleans up, and loads every row of every table into memory before encoding.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Full quick_check does not run on every healthy launch (gate to periodic or only after an unclean shutdown)
- [ ] #2 A fast cheap open check still detects the failure modes the recovery flow needs
- [ ] #3 Salvage export cleans up its temp file and does not load the whole DB into memory unbounded
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-192)
- Files: lib/data/db_open_diagnosis.dart, lib/ui/db_recovery_screen.dart
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
