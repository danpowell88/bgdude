---
id: TASK-207
title: Per-row meta decode guard in HistoryRepository.health()
status: To Do
assignee: []
created_date: '2026-07-06 21:11'
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
- [ ] #1 Per-row try/catch defaults meta to `{}`, skipping only the bad field
- [ ] #2 Test: insert a row with empty meta, assert other rows are still returned
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
