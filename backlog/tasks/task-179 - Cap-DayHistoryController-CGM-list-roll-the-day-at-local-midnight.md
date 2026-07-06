---
id: TASK-179
title: Cap DayHistoryController CGM list; roll the day at local midnight
status: To Do
assignee: []
created_date: '2026-07-06 09:18'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - data-integrity
milestone: m-8
dependencies: []
priority: high
ordinal: 102800
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `ingestSnapshot` appends CGM without trimming (`lib/state/day_history_controller.dart:154`) while `_basalObs` IS capped at 288 (line 48) — the author capped one list and missed the other; `reload()` (rolling 24 h window) runs only at construction and after manual events. Over a 10-day run the list grows unbounded, every reading recomputes metrics over the whole list, and Today actually means since-app-launch, never rolling at midnight.

**Reason for change.** Unbounded growth degrades performance over multi-day runs and the Today metrics silently stop meaning today.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `state.cgm` trimmed to the rolling window in `ingestSnapshot`
- [ ] #2 Day window rolls at local midnight
- [ ] #3 `reload()` runs on app resume
- [ ] #4 Unit tests cover the cap and the rollover
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Trim `state.cgm` to the rolling window inside `ingestSnapshot` (mirror the `_basalObs` cap).
- Roll the day window at local midnight (timer or check-on-ingest) and call `reload()` on app resume.
- Add unit tests for the cap and the midnight rollover.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (reliability finding 5)
- Effort: M
- Where: `lib/state/day_history_controller.dart`
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
