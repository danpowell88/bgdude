---
id: TASK-122
title: Narrow provider watches; share one forecast per snapshot
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:36'
updated_date: '2026-07-07 03:46'
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
- [x] #1 Snapshot consumers use `.select(...)` on the fields they read
- [x] #2 The forecast is computed once per snapshot behind its own provider, shared by narrative/alerts
- [x] #3 No behaviour change
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 03:42
---
Started: dedicated calibratedForecastsProvider (one forecast per snapshot) consumed by the narrative and the alert wrapper; livePredictionStateProvider and dailyNarrativeProvider narrowed to .select watches on the fields they read.
---

author: Claude
created: 2026-07-07 03:46
---
Done.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
horizonForecastsProvider computes the forecast once per prediction state; calibratedForecastsProvider layers the recent-error band. Consumers rewired: dailyNarrative (also narrowed to cgmMgdl/cgmTrend selects), rescueCarbAdvice, the AlertService wrapper, and the Predictions screen. livePredictionStateProvider now selects a record of the 7 snapshot fields it reads so unrelated snapshot ticks don't recompute it; _controlIqStateFrom takes the fields explicitly. dayEventsProvider consumes whole DayData legitimately and was left as-is. No behaviour change (702 tests green). Verified: analyze clean, APK builds.
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
