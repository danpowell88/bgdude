---
id: TASK-116
title: Extract a pure AlertOrchestrator from AlertService
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:34'
updated_date: '2026-07-06 21:51'
labels:
  - code-health
  - architecture
  - alerts
  - "\U0001F512 safety"
milestone: m-6
dependencies: []
priority: high
ordinal: 100400
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `AlertService.onSnapshot()` (`lib/state/providers.dart:1398-1622`, ~220 lines) inlines ~10 independent alert decisions plus threshold assembly from 8 providers (`lib/state/providers.dart:1417-1437`) plus throttled prediction logging (`:1604-1621`); `_checkPumpStatus` is `:1629-1699`. It only runs with a live Riverpod `Ref` and is untestable.

- Decisions inlined: predicted low/high, post-meal-walk nudge, rescue carb, missed bolus, stubborn high, ketone, anomaly, pump alarm, reservoir, battery

**Reason for change.** The alert brain is the highest-safety code in the app and currently cannot be unit tested; extracting a pure orchestrator makes every decision path testable in isolation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A pure `AlertOrchestrator` takes a value input (prediction state, calibrated forecasts, snapshot, thresholds, day data, device ages, active modes) and returns `List<AlertDecision>` (category+title+body+urgency)
- [x] #2 Firing/dedup (`_shouldFire`) and `NotificationService.show` stay in a thin provider wrapper
- [x] #3 Threshold assembly is extracted to a pure `resolveEffectiveThresholds(...)`
- [x] #4 Each decision path has its own unit test
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Define the input value type capturing everything `onSnapshot` reads from providers.
- Move each decision block verbatim into the orchestrator, returning `AlertDecision`s instead of firing.
- Extract threshold assembly into `resolveEffectiveThresholds(...)`.
- Wire the thin provider wrapper (fire/dedup + `NotificationService.show`).
- Add per-decision unit tests.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/state/providers.dart:1398-1699`)
- Effort: L
- Where: `lib/state/providers.dart`, new `lib/alerts/alert_orchestrator.dart`
- Related: coordinate with TASK-35 (moves AlertService to `lib/services/`), TASK-37 (aliveness), TASK-38/TASK-15 (extracted paths must log, not swallow), TASK-103/TASK-58 (threshold work)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 21:37
---
Started: extract pure AlertOrchestrator (value-input -> List<AlertDecision>) + resolveEffectiveThresholds from AlertService.onSnapshot; thin provider wrapper keeps _shouldFire + NotificationService.show; per-decision unit tests.
---

author: Claude
created: 2026-07-06 21:51
---
Done: pure orchestrator + thin wrapper landed (commit 3e58326). Behavior preserved verbatim, including: a NEW pump-alarm signature bypasses the cooldown WITHOUT marking it; the changed-signature path also bypasses the category enabled check (pre-existing behavior, kept); critical (urgent/predicted glucose) decisions record the fire only after a successful send per TASK-38. DoD 5-7 are vacuously met (no native Kotlin change, not user-visible, no screen/flow change).
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Extracted the pure alert brain to lib/alerts/alert_orchestrator.dart: AlertCycleInput (values only) -> AlertOrchestrator.evaluate -> AlertCycleResult (List<AlertDecision> + alarm signature), with resolveEffectiveThresholds() as the extracted threshold policy. AlertService in lib/state/providers.dart is now a thin wrapper: gathers inputs, applies cooldown/dedup (_coolPassed/_shouldFire, critical decisions record the fire only after a successful send), calls NotificationService.show, and keeps battery-history I/O + throttled prediction logging. 33 unit tests in test/alert_orchestrator_test.dart cover every decision path. Verified: build_runner, analyze clean, 609 tests green, debug APK builds. Commit 3e58326.
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
