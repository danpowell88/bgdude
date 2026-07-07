---
id: TASK-119
title: Adopt the Mgdl type across domain models
status: Done
assignee: []
created_date: '2026-07-06 08:35'
updated_date: '2026-07-07 03:30'
labels:
  - code-health
  - architecture
milestone: m-8
dependencies: []
priority: medium
ordinal: 105700
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `Mgdl` (`lib/core/units.dart:25-44`) is used in only ~3 files while raw `double` mg/dL appears in 41 files / 139 sites, including `CgmSample.mgdl` (`lib/core/samples.dart:36`), `StoredPrediction.predicted/lower/upperMgdl` (`lib/data/history_repository.dart:24-37`), `AlertThresholds.lowMgdl/highMgdl/urgentLowMgdl`, `PredictionState.currentMgdl`, and forecast points (`lib/ml/forecaster.dart`). The `Mgdl get glucose` shim on `CgmSample` (`lib/core/samples.dart:56`) shows the intent was never propagated.

**Reason for change.** A units type only pays off when it is pervasive; raw doubles leave unit-confusion bugs (mg/dL vs mmol/L) undetectable by the compiler.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Core value fields are typed `Mgdl`, staged by layer (start: `CgmSample`, `AlertThresholds`, forecast points, `StoredPrediction`)
- [x] #2 DB columns stay `double`; conversion happens only in repository mapping
- [x] #3 Arithmetic helpers (`+`, `-`, `compareTo`) exist on `Mgdl`
- [x] #4 No behaviour change (tests green)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add arithmetic helpers (`+`, `-`, `compareTo`) to `Mgdl`.
- Stage 1: convert `CgmSample` and `AlertThresholds`, fixing consumers.
- Stage 2: convert forecast points in `lib/ml/forecaster.dart`.
- Stage 3: convert `StoredPrediction`, keeping DB columns `double` with conversion in repository mapping.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/core/units.dart:25-44`)
- Effort: L
- Where: `lib/core/units.dart`, `lib/core/samples.dart`, `lib/data/history_repository.dart`, `lib/ml/forecaster.dart`
- Related: do after TASK-104 (landed); distinct from TASK-103
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 03:30
---
Done (commit f7f69a4). The 'implements double' choice trades operator-level distinctness for adoption pragmatism: full wrapper semantics would have required unwrapping at every arithmetic site (139+).
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Mgdl is now an extension type 'implements double': +/-/</compareTo work natively (AC#3, pinned in units_test), Mgdl flows into double slots, but a raw double cannot enter an Mgdl slot without an explicit wrap — the one-way unit safety. Staged fields typed per AC#1: CgmSample.mgdl, AlertThresholds + AlertBand lines (const-able via const Mgdl defaults), HorizonForecast mgdl/lower/upper, StoredPrediction predicted/lower/upper/actual. Constructors keep accepting plain doubles and wrap once (readings arrive raw), so 139 call sites needed almost no churn; DB columns stay double with conversion only in repository mapping (AC#2). No behaviour change: all 701 tests pass unchanged (AC#4). Verified: analyze clean, APK builds. Commit f7f69a4.
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
