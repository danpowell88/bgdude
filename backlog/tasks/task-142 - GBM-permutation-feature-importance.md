---
id: TASK-142
title: GBM permutation feature importance
status: Review
assignee:
  - Claude
created_date: '2026-07-06 08:41'
updated_date: '2026-07-10 10:06'
labels:
  - feature
  - ml
  - developer
milestone: m-5
dependencies: []
priority: medium
ordinal: 701900
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The residual GBM exposes zero interpretability while the ridge sensitivity model already exposes importance (`lib/ml/ridge_regression.dart:39-42`); held-out permutation importance (shuffle one feature column, measure RMSE increase) would show which features drive the correction, help prune dead features (as feature v4 did manually), and act as a drift signal.

**Value.** Makes the residual model inspectable: which features actually earn their place, and when their contribution shifts.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A `permutationImportance(holdout)` method exists in the trainer using the existing held-out rows
- [x] #2 Top features are surfaced in the model report/accuracy screen
- [x] #3 A unit test on a synthetic dataset with one informative feature passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Implement `permutationImportance(holdout)` in the trainer over the existing held-out rows.
- Surface the top features in the model report/accuracy screen.
- Add a unit test with a synthetic dataset where exactly one feature is informative.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ml/ridge_regression.dart:39-42`)
- Effort: M
- Where: `lib/ml/forecaster_training.dart`, model report/accuracy screen
- Related: complements TASK-59
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-10 09:51
---
branch: task-142
---

author: Claude
created: 2026-07-10 09:51
---
Started: reading GbmRegressor/ResidualGbmModel and ridge_regression.dart's existing importance getter to match the established interpretability pattern.
---

author: Claude
created: 2026-07-10 10:06
---
implemented-by: Claude (Sonnet 5, session 5ecb6b72-c69b-4afb-b36c-af3d04f85cad) -- lib/ml/gbm.dart (GbmRegressor.permutationImportance: seeded per-column shuffle, RMSE-increase importance, clamped >=0), lib/ml/residual_gbm_model.dart (ResidualGbmModel.featureImportance(horizon, holdout) wraps it per-horizon), lib/ml/forecaster_training.dart (ForecasterTrainingResult.importanceByHorizon, computed by reusing the ALREADY-BUILT holdoutByHorizon rows -- no separate scoring path), lib/ml/forecaster_service.dart + lib/state/forecast_providers.dart (threaded through TrainingOutcome, same pattern as TASK-140's census), lib/ui/advanced_screen.dart (new 'Top features (Nm)' row per horizon in the existing Forecaster card, labelled via ForecastFeatures.names, top 3 by importance); tests: test/ml/gbm_test.dart (synthetic one-informative-feature-vs-noise dataset, determinism-for-same-seed, empty-holdout safety), test/ml/residual_gbm_test.dart (featureImportance surfaces the informative feature, null for untrained horizon, null for empty holdout); doc/user-guide.html updated. Design: 'the trainer' (AC#1) interpreted as GbmRegressor itself (already owns predict/weightedRmse, permutation importance is fundamentally model-level, not forecaster-specific) with a thin per-horizon wrapper on ResidualGbmModel; 'model report/accuracy screen' (AC#2) interpreted as AdvancedScreen's existing Forecaster card (already the established venue for lastOutcome-derived training info this session, e.g. TASK-140's census) rather than ModelReportScreen/ModelAccuracyScreen, since importance is only computable AT TRAINING TIME (needs model+holdout together) and those other screens are driven by read-time reconciled-prediction queries with no access to that. Rigor-checked the core RMSE-increase computation (temp-bug forcing importance=0 always, confirmed the synthetic-dataset test fails as predicted, reverted cleanly). Full pipeline green: analyze clean, 1372 tests passing, coverage 68.74% (floor 65%), apk build succeeded. No native Kotlin changed; no screen/flow changed (additive row in an existing screen) so no new integration test.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
