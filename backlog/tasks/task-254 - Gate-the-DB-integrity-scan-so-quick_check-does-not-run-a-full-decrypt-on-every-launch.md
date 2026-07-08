---
id: TASK-254
title: >-
  Gate the DB integrity scan so quick_check does not run a full decrypt on every
  launch
status: Done
assignee:
  - Claude
created_date: '2026-07-07 14:29'
updated_date: '2026-07-08 04:57'
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
- [x] #1 Full quick_check does not run on every healthy launch (gate to periodic or only after an unclean shutdown)
- [x] #2 A fast cheap open check still detects the failure modes the recovery flow needs
- [x] #3 Salvage export cleans up its temp file and does not load the whole DB into memory unbounded
- [x] #4 Retired .bak-<epoch> DB backups from a reset are pruned (do not accumulate copies of the encrypted DB on repeated resets)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-192)
- Files: lib/data/db_open_diagnosis.dart, lib/ui/db_recovery_screen.dart
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 15:26
---
Adding AC from recent-code review 2026-07-08: TASK-249 fix replaced deleteDatabaseFile with retireDatabaseFile which renames the DB + sidecars to .bak-<epoch>. Confirmed-correct as a no-data-loss fix, but the .bak copies are never cleaned up, so repeated manual resets accumulate full copies of the (large) encrypted DB. Low severity (reset is rare + double-confirmed); folding here rather than a separate ticket since this ticket already owns recovery-flow housekeeping.
---

author: Claude
created: 2026-07-08 04:46
---
Started: reading lib/data/db_open_diagnosis.dart's openHistoryRepository (quick_check-on-every-launch), retireDatabaseFile (unpruned .bak-<epoch>), and salvageExportJson (unbounded in-memory load, no temp cleanup) to design gating + cleanup.
---

author: Claude
created: 2026-07-08 04:57
---
Fixed all 4 ACs.

AC#1/#2: added quickCheckDue/recordQuickCheckPassed/quickCheckMarker to db_open_diagnosis.dart -- a plain sentinel file (not DB-backed, since this runs before KvStore.init) recording when quick_check last completed cleanly. openHistoryRepository now only runs the deep PRAGMA quick_check scan once every 7 days; the existing cheap 'select 1' read (already unconditional) still catches the key/header failure modes on every launch. A corrupted result never updates the marker, so a known-bad DB keeps being re-checked every launch until fixed, not just once per interval.

AC#3: writeSalvageExportFile now streams each table's rows directly to the output file instead of building the full multi-table result as an in-memory Map and then encoding it as one big string (peak memory now bounded to one table's rows at a time, not the sum of every table plus a duplicate encoded copy). Also prunes any previous bgdude_salvage_*.json export in the target directory before writing a new one. salvageExportJson itself (the Map-returning variant) is unchanged -- still used/tested for the lighter in-memory case.

AC#4: retireDatabaseFile now calls _pruneOldBackups after creating a new .bak-<epoch> set, deleting every OLDER backup for the same DB file (main + wal/shm/journal sidecars) -- keeps only the most recent reset's backup instead of accumulating one per reset.

Added 12 new tests (retireDatabaseFile pruning, writeSalvageExportFile streaming + cleanup, quick_check gating x4). Rigor-checked all 4 mechanisms (backup pruning, salvage-export pruning, quick_check interval comparison) by temporarily disabling each -- all 3 corresponding tests correctly failed, reverted, clean diff.

Also caught a real regression from this change by test/support/no_wall_clock_guard_test.dart (TASK-237's extended guard): a DateTime.now() in my new test needed a now-ok justification since quickCheckDue itself reads the real wall clock (TASK-39 hasn't injected a clock yet) -- fixed.

Verified: flutter analyze clean, flutter test --coverage green (1171 tests, 67.58% >= 65% floor), flutter build apk --debug succeeds. No native Kotlin, no user-guide update (internal performance/hygiene fix, no user-visible surface).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
