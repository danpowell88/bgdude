---
id: TASK-128
title: >-
  Model persistence hardening: in-blob version, structural validation, atomic
  save
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:37'
updated_date: '2026-07-07 02:42'
labels:
  - code-health
  - ml
  - data-integrity
milestone: m-5
dependencies: []
priority: high
ordinal: 102300
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The feature-layout version lives in a separate KvStore key from the model blob (`lib/ml/forecaster_service.dart:54-76`) so they can desync; neither `GbmRegressor.fromJson` (`lib/ml/gbm.dart:78-88,339-348`) nor `ResidualGbmModel.fromJson` (`lib/ml/residual_gbm_model.dart:62-75`) validates structure — out-of-range node indices or a stale feature count decode fine then throw `RangeError` inside `RegressionTree.predict` on the live forecast path; `save()` writes two keys non-atomically and the 100KB+ blob sits in shared_preferences unbounded.

**Reason for change.** A corrupt or desynced persisted model crashes the live forecast path at predict time instead of failing safe at load time.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `featureVersion` + `schemaVersion` are embedded in `ResidualGbmModel.toJson`; mismatch on decode yields `NoResidualModel`
- [x] #2 `GbmRegressor.fromJson` validates child indices in range and `feature < featureCount`, throwing a typed `FormatException` the store catches
- [x] #3 Version and model are serialized as one record under a single key
- [x] #4 Serialized size is logged with a soft cap warning
- [x] #5 Round-trip tests cover a corrupted node index and a wrong-length feature vector
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 21:13
---
Stability rerun 2026-07-07: ensure the structural validation covers the per-horizon map keys — residual_gbm_model.dart:66,72 does int.parse(e.key as String) on decoded keys and throws on schema drift; wrap or int.tryParse as part of this ticket.
---

author: Claude
created: 2026-07-07 02:35
---
Started: embed featureVersion+schemaVersion in the model blob (single-key record), structural validation in GbmRegressor.fromJson (child indices, feature<featureCount) with a typed exception the store catches to NoResidualModel, per-horizon key parse hardening, size logging with soft cap, round-trip corruption tests.
---

author: Claude
created: 2026-07-07 02:42
---
Done (commit 3308fb9).
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
toJson embeds schema(=1) + ForecastFeatures.version; fromJson returns NoResidualModel on any version mismatch and throws typed ModelFormatException (extends FormatException) on structural corruption: out-of-range child indices, split feature >= layout width, non-integer horizon/sigma keys (the stability-rerun int.parse hardening). Store: single residual_model_v3 record with legacy two-key migration (re-saves the incumbent in the new format), catch->NoResidualModel with a loud ml log, size logged on every save with a 200KB soft-cap warning. 6 corruption round-trip tests (versions, child index, feature-out-of-width, bad keys). Verified: analyze clean, 672 tests green, debug APK builds. Commit 3308fb9.
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
