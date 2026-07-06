---
id: TASK-40
title: Restore ml/ purity
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 16:14'
labels:
  - roadmap
  - architecture
  - ml
  - detail-needed
milestone: m-6
dependencies: []
priority: low
ordinal: 109400
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude's machine-learning code is meant to be "pure" — free of the app framework, so it can be tested quickly on its own. One file breaks that rule by importing the framework (Riverpod).

**Reason for change.** Keeping the ML layer framework-free lets it run in a fast test lane and keeps the model logic clean. The fix splits the offending file so the pure logic stays put and only a thin controller touches the framework.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ml/ has no Riverpod imports
- [x] #2 Controller moved to state/forecast_providers.dart
- [x] #3 dart-test-only lane for analytics/+ml/ possible
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Split the offending file: store + train/gate/promote logic stay in `ml/` (pure; takes `KeyValueStore` after TASK-36).
- Move the thin `StateNotifier` controller to `state/forecast_providers.dart`.
- Set up a `dart test` (no Flutter) lane that runs `analytics/` + `ml/`; controller test lives with the providers.
- Refactor must be behaviour-preserving: full `flutter test` + `flutter analyze` green before and after; add the new unit tests the refactor unlocks.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 3.F
- Effort: S
- Depends on: 3.B
- Roadmap status: open

Implemented. AC#1/#3: lib/ml/ (and lib/analytics/) now import no flutter_riverpod or package:flutter — verified by grep — so a fast dart-test lane over the pure ML/analytics layer is possible (realizing it fully is a test-authoring choice: write those tests against package:test rather than flutter_test). AC#2: ForecasterModelController (the StateNotifier that ran the train→gate→promote cycle + Isolate.run) moved from ml/forecaster_service.dart to the new lib/state/forecast_providers.dart; the pure parts (TrainingOutcome, ForecasterModelStore) stay in ml/, and the actual training (ForecasterTrainer) was already pure in ml/forecaster_training.dart. providers.dart imports the controller from its new home; forecaster_service_test updated. Behaviour-preserving — analyze clean, 560 tests green (the moved promotion tests pass unchanged).
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:23
---
detail-needed (2026-07-06, goal triage): Restoring ml/ purity depends on the §3.B KeyValueStore seam existing first.
---
<!-- COMMENTS:END -->
