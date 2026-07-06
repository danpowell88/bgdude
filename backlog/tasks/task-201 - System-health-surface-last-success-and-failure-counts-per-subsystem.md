---
id: TASK-201
title: 'System-health surface: last-success and failure counts per subsystem'
status: To Do
assignee: []
created_date: '2026-07-06 21:10'
labels:
  - code-health
  - insights
  - logging
milestone: m-8
dependencies: []
priority: medium
ordinal: 111500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Recurring background failures have no user-visible signal — startup jobs (`lib/providers.dart:1770`), health sync, nightly training, prediction reconciliation, weather (`lib/providers.dart:1040-1044`), Garmin delivery (`android/app/src/main/kotlin/com/bgdude/app/garmin/GarminSender.kt:44-91`), and model download (`lib/panel_model_manager.dart:44-46`) all funnel to appLog only; grep confirms no aggregate status screen exists. The app keeps showing forecasts built on stale health context or an untrained model with nothing amiss.

- Pump disconnect IS surfaced (ConnectionAlertService) and stale-while-connected is TASK-176 — this ticket is the other subsystems

**Value.** The user can see at a glance which background subsystems are healthy, and notice silent recurring failures before they degrade forecasts.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A lightweight status surface (Advanced or Settings) shows last-success timestamp and failure count per subsystem: health sync, training, reconciliation, Garmin, weather, model download
- [ ] #2 Subsystems report through a small shared recorder (feeds from TASK-123 outcomes where available)
- [ ] #3 Test: force one subsystem to fail, the surface reflects it
- [ ] #4 User guide updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a small shared health recorder (per-subsystem last-success timestamp + failure count), persisted
- Wire the six subsystems (health sync, training, reconciliation, Garmin, weather, model download) to report outcomes, reusing TASK-123 outcome plumbing where available
- Add a lightweight status surface under Advanced or Settings rendering the recorder state
- Add a test forcing one subsystem to fail and asserting the surface reflects it
- Update `doc/user-guide.html` (and `doc/index.html` if needed) for the new surface
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (dart finding 6)
- Effort: M
- Where: `lib/providers.dart`, `lib/panel_model_manager.dart`, new status surface under Settings/Advanced
- Related: TASK-123, TASK-81 (raw dev log), TASK-140 (data census — different)
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
