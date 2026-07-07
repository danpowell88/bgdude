---
id: TASK-179
title: Cap DayHistoryController CGM list; roll the day at local midnight
status: Done
assignee:
  - Claude
created_date: '2026-07-06 09:18'
updated_date: '2026-07-07 03:08'
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
- [x] #1 `state.cgm` trimmed to the rolling window in `ingestSnapshot`
- [x] #2 Day window rolls at local midnight
- [x] #3 `reload()` runs on app resume
- [x] #4 Unit tests cover the cap and the rollover
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 03:04
---
Started: trim state.cgm to the rolling window in ingestSnapshot; roll the window past local midnight via a check-on-ingest; reload() on app resume via a lifecycle observer; cap + rollover unit tests.
---

author: Claude
created: 2026-07-07 03:08
---
Done (commit 07a5b87).
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
ingestSnapshot now trims state.cgm to the rolling 24 h window (and anchors state.start to it) — mirrors the _basalObs cap; the persisted repository keeps full history. Crossing local midnight since the last reading triggers reload() (check-on-ingest), re-anchoring the window and refreshing boluses/carbs/basal. MainShell gained a WidgetsBindingObserver that calls reload() on AppLifecycleState.resumed. 3 tests: 26-hour ingest run stays <= 289 samples/24 h, midnight roll re-anchors with both readings intact, same-day gap doesn't roll. Verified: analyze clean, 692 tests green, debug APK builds. Commit 07a5b87.
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
