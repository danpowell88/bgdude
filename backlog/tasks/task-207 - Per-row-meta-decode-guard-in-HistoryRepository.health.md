---
id: TASK-207
title: Per-row meta decode guard in HistoryRepository.health()
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:11'
updated_date: '2026-07-07 17:50'
labels:
  - code-health
  - data-integrity
milestone: m-8
dependencies: []
priority: medium
ordinal: 112100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/history_repository.dart:292` decodes every row with `jsonDecode(r.meta) as Map` inside the row-mapping loop — one row with empty/non-JSON meta throws FormatException and aborts the entire range read.

**Reason for change.** A single bad row silently drops ALL health samples for context building, reports and training features.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Per-row try/catch defaults meta to `{}`, skipping only the bad field
- [x] #2 Test: insert a row with empty meta, assert other rows are still returned
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Wrap the per-row meta decode in `HistoryRepository.health()` with try/catch defaulting to `{}`
- Add a test inserting a row with empty meta and asserting the other rows are still returned
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (dart finding 12)
- Effort: S
- Where: `lib/history_repository.dart:292`
- Related: TASK-193 (corpus), TASK-118 (typed meta)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 17:45
---
Started: wrapping the per-row meta decode in HistoryRepository.health() with a try/catch defaulting to {}.
---

author: Claude
created: 2026-07-07 17:50
---
Rewrote HistoryRepository.health()'s list comprehension as an explicit loop so each row's meta decode can be individually try/caught (a comprehension can't wrap a single iteration in try/catch inline). A bad row now defaults meta to {} and logs via appLog.error rather than throwing FormatException and losing every other row in the range. Added test/history_repository_health_test.dart (2 tests, against a real Drift in-memory DB via DriftHistoryRepository, not the InMemoryHistoryRepository test double which never JSON-round-trips meta and so can't exercise this bug at all): a row inserted directly with meta='not-json{' (bypassing saveHealth's own always-valid jsonEncode) is skipped/defaulted while the other two valid rows in the same range still return correctly; a second test covers an empty-string meta the same way. flutter analyze clean, flutter test test/ green (996 tests), flutter build apk --debug succeeded. No native Kotlin/screen change -- DoD #5/#6/#7 n/a.
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
