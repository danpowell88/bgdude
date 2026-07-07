---
id: TASK-185
title: Set busy_timeout on the encrypted DB connections
status: Done
assignee:
  - Claude
created_date: '2026-07-06 09:19'
updated_date: '2026-07-07 10:43'
labels:
  - code-health
  - data-integrity
milestone: m-8
dependencies: []
priority: medium
ordinal: 108500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The WorkManager backstop opens its own DB connection (`lib/insights/background_summary.dart:38-39`) concurrent with the main isolate; `lib/data/database.dart:169-172` sets WAL + foreign_keys but never `busy_timeout`, so a contended write raises SQLITE_BUSY immediately — the job silently delivers nothing (its blanket catch swallows it) or a main-isolate write throws.

**Reason for change.** Two writers on one WAL file without a busy timeout is a known intermittent-failure recipe; one PRAGMA removes it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `PRAGMA busy_timeout` set in the shared open path
- [x] #2 Concurrent-writer test on a shared file DB passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add `PRAGMA busy_timeout` alongside WAL + foreign_keys in the shared open path in `lib/data/database.dart`.
- Add a test with two connections writing to one file DB, asserting no immediate SQLITE_BUSY failure.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (reliability finding 11)
- Effort: S
- Where: `lib/data/database.dart`, `lib/insights/background_summary.dart`
- Related: TASK-42 (single-connection is the eventual fix; this hardens the interim)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 08:27
---
Started: PRAGMA busy_timeout=5000 in beforeOpen alongside WAL/foreign_keys — two writers (main isolate + WorkManager backstop) on one WAL file need it.
---

author: Claude
created: 2026-07-07 10:43
---
Deviation found + fixed during verification: the original db_concurrency_test.dart simulated two connections BOTH writing concurrently. That failed even with busy_timeout=5000 set correctly on both connections (confirmed via direct PRAGMA query) — it took ~126s of cascading lock retries before still throwing SQLITE_BUSY. Root cause: drift itself warns that multiple live AppDatabase instances on one file race and can corrupt data, independent of busy_timeout; two-writer isn't a pattern busy_timeout is meant to fix. Checked actual production usage (background_summary.dart's WorkManager job) — it is READ-ONLY, never writes. Rewrote the test to the real scenario: one writer (main isolate) + one concurrent reader (backstop), which is exactly what WAL + busy_timeout supports, and it now passes reliably (<1s). Updated the code comment in database.dart to match and to flag that a future second WRITER would need a shared-connection design, not just this PRAGMA. Pipeline green: analyze clean, 750 tests passed, apk debug build succeeds.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
