---
id: TASK-153
title: Learn fat/protein-heavy meals from outcome tails
status: To Do
assignee: []
created_date: '2026-07-06 08:44'
labels:
  - feature
  - meals
  - ml
milestone: m-7
dependencies: []
priority: medium
ordinal: 153000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `MealOutcome` records `bgAt3hMgdl`, `bgAtMealMgdl`, `peakOffsetMinutes`, `timeAbove180Minutes` (`lib/meals/meal_library.dart:42-146`) but `fatProteinHeavy` is a manual bool (`:210`) consumed by the pre-bolus and FPU coaches — the pizza-effect signature (late peak, sustained tail) is collected but never learned.

**Value.** The app already records the data needed to spot fat/protein tails; learning it removes a manual flag the user forgets to set.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 After N outcomes a learned `fatProteinTail` score is derived from median `(bgAt3h - bgAtMeal)` and `peakOffset`
- [ ] #2 The coaches consume the learned score with the manual flag as override
- [ ] #3 The score is damped like the existing curve learning (`learningRate = 0.3`)
- [ ] #4 Tests cover the learning
- [ ] #5 The user guide is updated
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
