---
id: TASK-185
title: Set busy_timeout on the encrypted DB connections
status: To Do
assignee: []
created_date: '2026-07-06 09:19'
labels:
  - code-health
  - data-integrity
milestone: m-8
dependencies: []
priority: medium
ordinal: 185000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The WorkManager backstop opens its own DB connection (`lib/insights/background_summary.dart:38-39`) concurrent with the main isolate; `lib/data/database.dart:169-172` sets WAL + foreign_keys but never `busy_timeout`, so a contended write raises SQLITE_BUSY immediately — the job silently delivers nothing (its blanket catch swallows it) or a main-isolate write throws.

**Reason for change.** Two writers on one WAL file without a busy timeout is a known intermittent-failure recipe; one PRAGMA removes it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `PRAGMA busy_timeout` set in the shared open path
- [ ] #2 Concurrent-writer test on a shared file DB passes
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
