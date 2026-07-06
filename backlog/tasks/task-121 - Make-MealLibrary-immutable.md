---
id: TASK-121
title: Make MealLibrary immutable
status: To Do
assignee: []
created_date: '2026-07-06 08:36'
labels:
  - code-health
  - meals
milestone: m-8
dependencies: []
priority: medium
ordinal: 121000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `MealLibrary` (`lib/meals/meal_library.dart:297-316`) holds a mutable `_meals` map with in-place mutators, and `MealLibraryNotifier` (`lib/state/providers.dart:1222-1236`) mutates current state then reassigns a reconstructed object — listeners holding the previous reference observe the mutation.

**Reason for change.** Mutable state inside a Riverpod notifier defeats change detection and makes stale-reference bugs possible; immutable updates restore value semantics.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `add`/`update`/`learnFromOutcome` return new instances (copied map)
- [ ] #2 The notifier assigns `state = state.withMeal(...)` style
- [ ] #3 No in-place mutation remains
- [ ] #4 Existing meal tests are green
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Convert `MealLibrary` mutators to return new instances with a copied map.
- Update `MealLibraryNotifier` to assign new state from the returned instances.
- Sweep for any remaining in-place mutation of `_meals`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/meals/meal_library.dart:297-316`)
- Effort: M
- Where: `lib/meals/meal_library.dart`, `lib/state/providers.dart`
- Related: TASK-54 (`learnFromOutcome` lives here)
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
