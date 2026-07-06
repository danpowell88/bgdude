---
id: TASK-172
title: Automatic KvStore test isolation
status: To Do
assignee: []
created_date: '2026-07-06 09:16'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - testing
milestone: m-8
dependencies: []
priority: medium
ordinal: 107700
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/data/kv_store.dart:17-26` is all-static with a shared memory map; test isolation relies on each file remembering `setUp(KvStore.useMemory)` and only 8 files do — tests touching persisted state via providers can leak order-dependent state within a file.

**Reason for change.** Isolation by convention fails silently; a global test hook removes the whole bug class.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A shared `flutter_test_config.dart` (or the TASK-108 fixtures entrypoint) calls `KvStore.useMemory()` in a global setUp
- [ ] #2 Suite green with no per-file reliance on `setUp(KvStore.useMemory)`
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add `test/flutter_test_config.dart` (or extend the TASK-108 fixtures entrypoint) with a global setUp calling `KvStore.useMemory()`.
- Remove or keep redundant per-file setUps consciously; run the suite to confirm no order-dependent leaks remain.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (test-quality finding 10)
- Effort: S
- Where: `lib/data/kv_store.dart`, `test/flutter_test_config.dart`
- Related: TASK-36 (root cause), TASK-108
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
