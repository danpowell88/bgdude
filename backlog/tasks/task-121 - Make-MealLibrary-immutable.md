---
id: TASK-121
title: Make MealLibrary immutable
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:36'
updated_date: '2026-07-07 03:41'
labels:
  - code-health
  - meals
milestone: m-8
dependencies: []
priority: medium
ordinal: 105900
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `MealLibrary` (`lib/meals/meal_library.dart:297-316`) holds a mutable `_meals` map with in-place mutators, and `MealLibraryNotifier` (`lib/state/providers.dart:1222-1236`) mutates current state then reassigns a reconstructed object — listeners holding the previous reference observe the mutation.

**Reason for change.** Mutable state inside a Riverpod notifier defeats change detection and makes stale-reference bugs possible; immutable updates restore value semantics.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `add`/`update`/`learnFromOutcome` return new instances (copied map)
- [x] #2 The notifier assigns `state = state.withMeal(...)` style
- [x] #3 No in-place mutation remains
- [x] #4 Existing meal tests are green
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 03:35
---
Started: MealLibrary mutators return new instances (copied map); notifier assigns returned state; sweep in-place mutation.
---

author: Claude
created: 2026-07-07 03:41
---
Done. @useResult was tried but meta isn't a direct dependency and flutter/foundation doesn't re-export it — dropped as non-essential.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
MealLibrary is immutable: private map-carrying ctor, add/update return new instances ({...map, id: meal}), learnFromOutcome returns ({library, meal}) — no in-place mutation remains (the only mutators were these three). MealLibraryNotifier assigns state = state.add(...) / .learnFromOutcome(...).library. Meal tests adapted to the value API with identical assertions; all 702 tests green, analyze clean, APK builds. Commit follows in message.
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
