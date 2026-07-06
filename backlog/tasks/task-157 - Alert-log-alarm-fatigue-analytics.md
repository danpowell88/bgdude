---
id: TASK-157
title: Alert log + alarm-fatigue analytics
status: To Do
assignee: []
created_date: '2026-07-06 08:45'
updated_date: '2026-07-06 12:58'
labels:
  - feature
  - alerts
  - insights
milestone: m-7
dependencies:
  - TASK-42
priority: medium
ordinal: 702700
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `AlertService._lastFired` is in-memory only (`lib/state/providers.dart:1375`) — nothing persists which alerts fired, so the app cannot report "34 predicted-low alerts this week, 60% overnight" or support data-driven threshold tuning. Requires a NEW data source (small `alert_events` table: category, firedAt, optional acknowledged).

**Value.** Alarm fatigue is the top reason users abandon alerting; measuring it enables tuning instead of guessing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 An `alert_events` table is written from the firing path
- [ ] #2 A weekly rollup shows counts per category, overnight share, week-over-week delta
- [ ] #3 A suggestion is raised when one category dominates
- [ ] #4 Migration and repo tests pass
- [ ] #5 The user guide is updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add the `alert_events` table (category, firedAt, optional acknowledged) with a drift migration.
- Write events from the alert firing path.
- Build the weekly rollup (counts per category, overnight share, week-over-week delta).
- Add a dominant-category suggestion.
- Add migration + repo tests.
- Update `doc/user-guide.html`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/state/providers.dart:1375`)
- Effort: M
- Where: drift schema, `lib/data/history_repository.dart`, alert firing path, insights/report surface, `doc/user-guide.html`
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
