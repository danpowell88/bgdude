---
id: TASK-200
title: Persist the announced exercise session across restarts
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:09'
updated_date: '2026-07-07 16:31'
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
- [x] #1 The active plan is persisted and restored
- [x] #2 The plan is cleared once `effectiveEnd` passes
- [x] #3 Test: persist, rebuild providers, `affectsAt(now)` still true in-window and cleared after
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 16:25
---
Started. Note: an earlier pass (TASK-194 restart-recovery testing) explicitly flagged exercisePlanProvider's non-persistence as 'by design, not an oversight' and left it as a documented gap needing a product call, reasoning the app 'fails toward more alerting' either way. Re-examined: that's only true for the predicted-high suppression half of exercise mode. The OTHER half -- the RAISED low-alert threshold -- means losing the plan mid-workout makes alerts fire LATER (threshold drops back to normal) during and after exercise, which is precisely the highest hypo-risk window for T1D. That's a safety regression on restart, not a safe-direction default, so TASK-200's fix is correct and supersedes the earlier flag. Will update restart_recovery_test.dart's now-stale 'exercise mode does NOT survive restart' test to match.
---

author: Claude
created: 2026-07-07 16:31
---
Converted exercisePlanProvider from a bare in-memory StateProvider to a StateNotifierProvider<ExercisePlanNotifier, ExercisePlan?> extending PersistedStateNotifier, using ExercisePlan's existing (previously unused) toJson/fromJson. AC#1: set()/clear() persist through KvStore key exercise_plan_v1 (empty string represents 'no plan', since KvStore has no delete method); load() restores it. AC#2: load() itself refuses to resurrect an already-expired plan (checks DateTime.now().isAfter(plan.effectEnd) before restoring), AND a new clearIfExpired(now) method actively clears a plan whose window passes while the container stays alive -- wired into the existing AppJobs.checkModeExpiry() (from TASK-197) and its periodic ModeExpiryWatchdogService, so exercise/illness/medication all now share the same startup+periodic auto-expiry mechanism. AC#3: added 4 tests to restart_recovery_test.dart -- an in-window plan survives a restart (affectsAt still true), an already-expired plan is NOT restored, checkModeExpiry clears an expired plan without a restart, and updated the two call sites (announceExercise/endExercise on AppJobs) to await the new set()/clear() methods instead of the old raw '.notifier.state = ...' StateProvider API. Replaced the now-WRONG 'exercise mode does NOT survive restart (by design)' test from TASK-194 -- re-examined that reasoning and it undercounted the actual risk: losing the RAISED low-alert threshold mid-workout (not just the predicted-high suppression) makes alerts fire LATER exactly during the highest hypo-risk window for T1D, which is a safety regression on restart, not a safe default. flutter analyze clean, flutter test test/ green (967 tests), flutter build apk --debug succeeded. doc/user-guide.html not changed -- this is a reliability fix (no new visible behavior; the screen already said exercise mode auto-expires). No native Kotlin/new screen -- DoD #5/#7 n/a.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
