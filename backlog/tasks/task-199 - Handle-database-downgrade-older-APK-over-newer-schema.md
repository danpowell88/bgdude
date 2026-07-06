---
id: TASK-199
title: Handle database downgrade (older APK over newer schema)
status: To Do
assignee: []
created_date: '2026-07-06 21:09'
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
- [ ] #1 A downgrade lands in a defined state — fail loudly with a clear this-build-is-older-than-your-data message (no in-memory masquerade)
- [ ] #2 Test: open a DB stamped user_version=5 under schemaVersion 4, assert the defined outcome and no corruption
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
