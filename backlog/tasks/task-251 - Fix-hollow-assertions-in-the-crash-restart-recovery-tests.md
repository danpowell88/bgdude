---
id: TASK-251
title: Fix hollow assertions in the crash-restart recovery tests
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 14:28'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 154000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two restart_recovery_test.dart invariants pass regardless of correctness. First, the exercise-mode test sets exercisePlanProvider state to null as baseline then asserts the post-restart value isNull, so it only proves null stays null and would pass even if exercise mode did persist; it should set a real ExercisePlan pre-crash and assert the intended behaviour. Second, the urgent-low re-fire invariant is pinned on a bare inline CooldownGate rather than through the RestartSimulation and alertServiceProvider path, so it only proves a freshly constructed object has no state; if cooldown persistence were later added to AlertService the test would stay green while the real invariant broke.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Exercise-mode restart test sets a real ExercisePlan before the simulated crash and asserts the intended survive or drop behaviour
- [ ] #2 Cooldown re-fire invariant is exercised through the rebuilt containers AlertService, not a bare CooldownGate
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-194)
- File: test/restart_recovery_test.dart exercise plan and CooldownGate group
- Related: TASK-200 (persist announced exercise session) may change the expected direction of the exercise assertion
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
