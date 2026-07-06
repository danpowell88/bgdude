---
id: TASK-128
title: >-
  Model persistence hardening: in-blob version, structural validation, atomic
  save
status: To Do
assignee: []
created_date: '2026-07-06 08:37'
labels:
  - code-health
  - ml
  - data-integrity
milestone: m-5
dependencies: []
priority: high
ordinal: 128000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The feature-layout version lives in a separate KvStore key from the model blob (`lib/ml/forecaster_service.dart:54-76`) so they can desync; neither `GbmRegressor.fromJson` (`lib/ml/gbm.dart:78-88,339-348`) nor `ResidualGbmModel.fromJson` (`lib/ml/residual_gbm_model.dart:62-75`) validates structure — out-of-range node indices or a stale feature count decode fine then throw `RangeError` inside `RegressionTree.predict` on the live forecast path; `save()` writes two keys non-atomically and the 100KB+ blob sits in shared_preferences unbounded.

**Reason for change.** A corrupt or desynced persisted model crashes the live forecast path at predict time instead of failing safe at load time.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `featureVersion` + `schemaVersion` are embedded in `ResidualGbmModel.toJson`; mismatch on decode yields `NoResidualModel`
- [ ] #2 `GbmRegressor.fromJson` validates child indices in range and `feature < featureCount`, throwing a typed `FormatException` the store catches
- [ ] #3 Version and model are serialized as one record under a single key
- [ ] #4 Serialized size is logged with a soft cap warning
- [ ] #5 Round-trip tests cover a corrupted node index and a wrong-length feature vector
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Embed `featureVersion` + `schemaVersion` inside `ResidualGbmModel.toJson`; on decode mismatch return `NoResidualModel`.
- Add structural validation to `GbmRegressor.fromJson` (child indices in range, `feature < featureCount`) throwing a typed `FormatException`.
- Catch the typed exception in the store and fall back safely.
- Merge version + model into a single-key record; log serialized size with a soft cap warning.
- Add round-trip tests with a corrupted node index and a wrong-length feature vector.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ml/forecaster_service.dart:54-76`)
- Effort: M
- Where: `lib/ml/forecaster_service.dart`, `lib/ml/gbm.dart`, `lib/ml/residual_gbm_model.dart`
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
