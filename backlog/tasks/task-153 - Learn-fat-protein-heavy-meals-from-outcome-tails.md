---
id: TASK-153
title: Learn fat/protein-heavy meals from outcome tails
status: Review
assignee:
  - Claude
created_date: '2026-07-06 08:44'
updated_date: '2026-07-10 11:00'
labels:
  - feature
  - meals
  - ml
milestone: m-7
dependencies: []
priority: medium
ordinal: 702300
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `MealOutcome` records `bgAt3hMgdl`, `bgAtMealMgdl`, `peakOffsetMinutes`, `timeAbove180Minutes` (`lib/meals/meal_library.dart:42-146`) but `fatProteinHeavy` is a manual bool (`:210`) consumed by the pre-bolus and FPU coaches — the pizza-effect signature (late peak, sustained tail) is collected but never learned.

**Value.** The app already records the data needed to spot fat/protein tails; learning it removes a manual flag the user forgets to set.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 After N outcomes a learned `fatProteinTail` score is derived from median `(bgAt3h - bgAtMeal)` and `peakOffset`
- [x] #2 The coaches consume the learned score with the manual flag as override
- [x] #3 The score is damped like the existing curve learning (`learningRate = 0.3`)
- [x] #4 Tests cover the learning
- [x] #5 The user guide is updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Derive a `fatProteinTail` score after N outcomes from median `(bgAt3h - bgAtMeal)` and `peakOffset`.
- Damp updates with the existing `learningRate = 0.3` pattern.
- Have the pre-bolus and FPU coaches consume the score with the manual flag as override.
- Add tests.
- Update `doc/user-guide.html`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/meals/meal_library.dart:42-210`)
- Effort: M
- Where: `lib/meals/meal_library.dart`, pre-bolus and FPU coaches, `doc/user-guide.html`
- Related: distinct from TASK-54 (timing, not FPU)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-10 10:46
---
branch: task-153
---

author: Claude
created: 2026-07-10 10:48
---
Started: found the exact damped-learning pattern in MealLibrary.learnFromOutcome (peakOffsetMinutes/absorptionMinutes via current + learningRate*(observed-current), clamped). Designing fatProteinTailScore the same way: once a meal has >= minOutcomesForFatProteinLearning (3, matching the existing outcomes>=3 confidence threshold in prebolus_coach) outcomes, compute median(bgAt3h-bgAtMeal) and median(peakOffsetMinutes) across the outcome history, map to an observed [0,1] signal (late-peak + sustained-tail), and damped-blend that into the persisted score the same way. effectiveFatProteinHeavy = manual flag OR (learned score >= threshold) -- manual always wins when set true, learned score decides once trusted.
---

author: Claude
created: 2026-07-10 11:00
---
implemented-by: Claude (Sonnet 5, session 5ecb6b72-c69b-4afb-b36c-af3d04f85cad) -- lib/meals/meal_library.dart: SavedMeal gained fatProteinTailScore ([0,1], persisted+hardened like other TASK-250 fields) and effectiveFatProteinHeavy (manual flag OR learned score >= fatProteinHeavyThreshold(0.5)). MealLibrary.learnFromOutcome: once a meal has >= minOutcomesForFatProteinLearning(3, matches prebolus_coach's existing confidence threshold) outcomes, re-derives an observed [0,1] signal from median(bgAt3h-bgAtMeal) (0 at resolved, 1.0 at 60+ mg/dL still elevated) and median(peakOffsetMinutes) (0 at ~60min carb-only peak, 1.0 at 120+ min), averages them, and damped-blends into the persisted score via the SAME learningRate=0.3 formula already used for absorptionMinutes/peakOffsetMinutes. Consumers updated: prebolus_coach.dart and meal_detail_screen.dart's FPU-split check now read effectiveFatProteinHeavy instead of the raw manual flag; the meal-detail 'Learned curve' card's Fat/protein-heavy row shows the source (manual vs learned, with the %signal). Tests: test/meals/meal_library_test.dart -- below-threshold-outcomes stays at 0, a consistent fat/protein pattern climbs 0->0.3->0.51 across two learning passes (hand-verified against the damping formula, crossing effectiveFatProteinHeavy on the second), a normal resolved meal stays at 0, effectiveFatProteinHeavy's manual-override and learned-threshold cases, JSON round-trip, and the hostile-decode clamp (NaN/negative/>1 all clamp into [0,1]). Rigor-checked both the damping (temp-bug: full jump instead of damped blend, confirmed 1.0 instead of predicted 0.3) and the manual-flag override (temp-bug: dropped it from the OR, confirmed false instead of predicted true) -- both reverted cleanly. Full pipeline green: analyze clean, 1372 tests passing, coverage 68.84% (floor 65%), apk build succeeded. No native Kotlin changed. doc/user-guide.html updated (Meals section, Fat/protein card bullet). No screen/flow changed (additive field + row in existing screens) so no new integration test.
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
