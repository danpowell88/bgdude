---
id: TASK-200
title: Persist the announced exercise session across restarts
status: To Do
assignee: []
created_date: '2026-07-06 21:09'
labels:
  - code-health
  - insights
milestone: m-8
dependencies: []
priority: medium
ordinal: 111400
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `exercisePlanProvider` is an in-memory `StateProvider<ExercisePlan?>` (`lib/providers.dart:283-285`) consumed by the alert path to raise the low line (`lib/providers.dart:1451-1455`) and suppress predicted-high noise (`lib/providers.dart:1474`). `ExercisePlan` already has toJson/fromJson (`lib/insights/exercise_mode.dart:37-47`) that are unused.

**Reason for change.** Process death mid-workout silently drops the raised low threshold and the suppression the user set up. It fails toward more alerting, but the protection the user configured vanishes with no indication.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The active plan is persisted and restored
- [ ] #2 The plan is cleared once `effectiveEnd` passes
- [ ] #3 Test: persist, rebuild providers, `affectsAt(now)` still true in-window and cleared after
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Replace/back the in-memory `exercisePlanProvider` with a persisted store using the existing `ExercisePlan` toJson/fromJson
- Restore the plan at startup; clear it when `effectiveEnd` has passed
- Add a test: persist, rebuild the ProviderContainer, assert `affectsAt(now)` still true in-window and cleared after the window
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (dart finding 5)
- Effort: S
- Where: `lib/providers.dart:283-285,1451-1474`, `lib/insights/exercise_mode.dart:37-47`
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
