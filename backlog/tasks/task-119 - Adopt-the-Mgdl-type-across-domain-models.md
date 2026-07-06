---
id: TASK-119
title: Adopt the Mgdl type across domain models
status: To Do
assignee: []
created_date: '2026-07-06 08:35'
updated_date: '2026-07-06 12:57'
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
- [ ] #1 Core value fields are typed `Mgdl`, staged by layer (start: `CgmSample`, `AlertThresholds`, forecast points, `StoredPrediction`)
- [ ] #2 DB columns stay `double`; conversion happens only in repository mapping
- [ ] #3 Arithmetic helpers (`+`, `-`, `compareTo`) exist on `Mgdl`
- [ ] #4 No behaviour change (tests green)
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
