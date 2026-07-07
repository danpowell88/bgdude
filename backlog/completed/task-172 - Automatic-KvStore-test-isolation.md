---
id: TASK-172
title: Automatic KvStore test isolation
status: Done
assignee:
  - Claude
created_date: '2026-07-06 09:16'
updated_date: '2026-07-07 07:27'
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
- [x] #1 A shared `flutter_test_config.dart` (or the TASK-108 fixtures entrypoint) calls `KvStore.useMemory()` in a global setUp
- [x] #2 Suite green with no per-file reliance on `setUp(KvStore.useMemory)`
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 07:25
---
Started: global flutter_test_config.dart with setUp(KvStore.useMemory); redundant per-file setUps left in place (harmless, self-documenting).
---

author: Claude
created: 2026-07-07 07:27
---
Done.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
test/flutter_test_config.dart added: flutter_test auto-discovers it and testExecutable installs a global setUp(KvStore.useMemory) before every test. Suite green (737) with no reliance on per-file setUps (the existing 8 remain as harmless documentation). Verified: analyze clean, APK builds.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [x] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
