---
id: TASK-231
title: Feed the composed low-line into the alert cycle (stop re-deriving it)
status: To Do
assignee: []
created_date: '2026-07-07 03:47'
labels:
  - code-health
  - alerts
milestone: m-8
dependencies: []
priority: medium
ordinal: 113220
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The low-line composition math is correctly single-sourced in `EffectiveLowThreshold.compute`, but two sites independently assemble its inputs: `effectiveLowThresholdProvider` (`lib/state/providers.dart:618-633`, feeds rescue + pre-bolus) and `resolveEffectiveThresholds` (`lib/alerts/alert_orchestrator.dart:110-136`, feeds alerts). Both re-derive the post-meal "carbs within the last 2 h" window (the `Duration(hours: 2)` literal appears in both) and re-resolve the band.

**Reason for change.** If the post-meal window changes or a new modifier source is added to the provider, the alert path silently diverges — undercutting the TASK-147 guarantee that coaching can never advise into a situation the app would alert on. No test asserts the two paths agree.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The alert cycle consumes the composed threshold (or its inputs) from the provider wrapper instead of re-deriving; or the shared assembly (incl. the post-meal window) lives in one helper
- [ ] #2 A test asserts the alert path and the coaching path produce the same effective low line for the same state
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Pass the composed `EffectiveLowThreshold` (or mgdl + post-meal flag) into `AlertCycleInput`.
- Collapse `resolveEffectiveThresholds` onto it; extract the post-meal window helper.
- Add the agreement test.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: hourly quality check 2026-07-07 (recent-landings review, finding 2)
- Effort: M
- Where: lib/state/providers.dart:618-633, lib/alerts/alert_orchestrator.dart:110-136
- Related: TASK-147, TASK-116 (both introduced the two sites)
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
