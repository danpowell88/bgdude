---
id: TASK-305
title: Exercise-announcement notification fires even when the plan failed to persist
status: Done
assignee:
  - Claude
created_date: '2026-07-08 11:09'
updated_date: '2026-07-08 11:16'
labels: []
milestone: m-8
dependencies:
  - TASK-304
priority: high
ordinal: 119600
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
announceExercise() (lib/state/providers.dart ~2701) calls exercisePlanProvider.notifier.set(plan) (ExercisePlanNotifier extends PersistedStateNotifier, persist() already returns Future<bool> and correctly reverts state on a failed write) but discards the boolean result, then unconditionally notifies 'Exercise mode on / Low alerts will lead earlier' when plan.type.raisesHypoRisk. On a failed write the state correctly reverts (so alert logic doesn't actually raise the low-alert threshold), but the user is told it did -- the exact same gate-annotation-not-notification bug class as TASK-261/TASK-304, found via the new CLAUDE.md 'sweep the whole surface' sibling-call-site check while closing TASK-304.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 announceExercise only shows the 'Exercise mode on' notification when exercisePlanProvider.notifier.set(plan) actually returns true (persist succeeded)
- [x] #2 A test asserts no notification fires when the persist fails (mirrors the TASK-304 failed-persist tests), and that it still fires normally on success
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test --coverage test/ green
- [x] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [x] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 11:09
---
Started: gate announceExercise's notification on set(plan)'s bool return, mirroring the TASK-304 fix exactly.
---

author: Claude
created: 2026-07-08 11:16
---
Done: found while sweeping sibling call sites per the new CLAUDE.md 'sweep the whole surface' checklist right after closing TASK-304 -- exactly the same gate-annotation-not-notification bug class, one call site over. ExercisePlanNotifier.set() was declared Future<void> despite wrapping persist() (which already returns Future<bool>), so announceExercise() had no way to see a failed write even if it wanted to. Widened set()'s return type to Future<bool> (only call site not already discarding the value was the new one; verified via grep) and gated the 'Exercise mode on' notification on it, mirroring TASK-304's fix exactly. Added test/state/jobs_test.dart group 'announceExercise notification gating (TASK-305)': notifies on a successful persist, does not notify (and exercisePlanProvider stays null) on a failed one via the established unopenable-DB KvStore fault injection. Rigor-checked (temp-bug dropping the persisted&& guard, confirmed the failed-persist test fails with the predicted 'Actual: [NotificationCategory.overnightLowRisk]', reverted cleanly). No other sibling bug found in the remaining .show() call sites in providers.dart (connectionLost/dataStale have no persist step; illnessSuggestion is in-memory-only; checkExerciseHypoRisk already persists its dedup flag AFTER a successful notify, a different and lower-severity ordering; logContext's annotation save isn't wrapped in a swallow-catch so a throw there already skips the notify). Full pipeline green: analyze clean, 1366 tests passing, coverage 68.72% (floor 65%), apk build succeeded. No native Kotlin changed; no user-visible wording changed so no user-guide update.
---
<!-- COMMENTS:END -->
