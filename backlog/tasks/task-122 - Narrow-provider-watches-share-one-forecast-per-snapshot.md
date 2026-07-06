---
id: TASK-122
title: Narrow provider watches; share one forecast per snapshot
status: To Do
assignee: []
created_date: '2026-07-06 08:36'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - architecture
  - ui
milestone: m-8
dependencies: []
priority: medium
ordinal: 106000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `dailyNarrativeProvider` (`lib/state/providers.dart:548-584`) watches the whole `pumpSnapshotProvider` and re-runs a full `forecaster.forecastState(state)` on every snapshot tick; `livePredictionStateProvider` (`:1142-1166`) watches the full snapshot but uses only cgm/trend/controlIq fields; `dayEventsProvider` (`:1100-1134`) rebuilds `EventBuilder().build(day)` on every dayData change. The codebase already shows the fix (`pendingConfirmationsProvider` at `:835` uses `.select((s)=>s.cgmTime)`).

**Reason for change.** Whole-snapshot watches cause redundant forecasts and rebuilds every few seconds; narrowing watches and computing the forecast once per snapshot removes duplicated work.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Snapshot consumers use `.select(...)` on the fields they read
- [ ] #2 The forecast is computed once per snapshot behind its own provider, shared by narrative/alerts
- [ ] #3 No behaviour change
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Introduce a dedicated forecast provider computed once per snapshot.
- Point `dailyNarrativeProvider` and alert consumers at the shared forecast provider.
- Convert `livePredictionStateProvider` and `dayEventsProvider` to `.select(...)` watches on the fields they read.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/state/providers.dart:548-584, 1100-1166`)
- Effort: M
- Where: `lib/state/providers.dart`
- Related: TASK-116 (orchestrator consumes the shared forecast provider)
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
