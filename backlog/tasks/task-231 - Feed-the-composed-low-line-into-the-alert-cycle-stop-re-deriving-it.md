---
id: TASK-231
title: Feed the composed low-line into the alert cycle (stop re-deriving it)
status: Done
assignee:
  - Claude
created_date: '2026-07-07 03:47'
updated_date: '2026-07-07 23:15'
labels:
  - code-health
  - alerts
milestone: m-8
dependencies: []
priority: medium
ordinal: 113220
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The low-line composition math is correctly single-sourced in `EffectiveLowThreshold.compute`, but two sites independently assemble its inputs: `effectiveLowThresholdProvider` (`lib/state/providers.dart:618-633`, feeds rescue + pre-bolus) and `resolveEffectiveThresholds` (`lib/alerts/alert_orchestrator.dart:110-136`, feeds alerts). Both re-derive the post-meal "carbs within the last 2 h" window (the `Duration(hours: 2)` literal appears in both) and re-resolve the band.

**Reason for change.** If the post-meal window changes or a new modifier source is added to the provider, the alert path silently diverges — undercutting the TASK-147 guarantee that coaching can never advise into a situation the app would alert on. No test asserts the two paths agree.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The alert cycle consumes the composed threshold (or its inputs) from the provider wrapper instead of re-deriving; or the shared assembly (incl. the post-meal window) lives in one helper
- [x] #2 A test asserts the alert path and the coaching path produce the same effective low line for the same state
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Pass the composed `EffectiveLowThreshold` (or mgdl + post-meal flag) into `AlertCycleInput`.
- Collapse `resolveEffectiveThresholds` onto it; extract the post-meal window helper.
- Add the agreement test.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: hourly quality check 2026-07-07 (recent-landings review, finding 2)
- Effort: M
- Where: lib/state/providers.dart:618-633, lib/alerts/alert_orchestrator.dart:110-136
- Related: TASK-147, TASK-116 (both introduced the two sites)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 23:15
---
Both ACs done, combining both of AC#1's options (shared assembly for the postMeal window AND consuming the composed threshold from the provider wrapper for the low line):

AC#1: 
- Extracted isPostMealWindow(carbs, now) into lib/insights/alert_thresholds.dart (single source for the Duration(hours: 2) check both sites used to duplicate) -- effectiveLowThresholdProvider and resolveEffectiveThresholds both call it now.
- resolveEffectiveThresholds no longer independently recomputes EffectiveLowThreshold.compute from its own profile/annotations/exercise/tempC bundle -- it now takes the already-composed EffectiveLowThreshold (effectiveLow) as a parameter and only still owns the high/urgent-low band lookup (which needs its own postMeal check via isPostMealWindow, now shared).
- AlertCycleInput carries effectiveLow (replacing the recentAnnotations/ambientTempC fields resolveEffectiveThresholds used to consume); providers.dart's onSnapshot() populates it via _ref.read(effectiveLowThresholdProvider) -- the exact same provider the coaching path (pre-bolus guard, rescue-carb advice) already reads.
- Side effect worth flagging: the alert path used to fetch annotations via a FRESH historyRepositoryProvider.annotations() call every cycle; it now goes through effectiveLowThresholdProvider -> recentAnnotationsProvider's cache (invalidated when dayHistoryControllerProvider changes). This trades per-cycle DB freshness for guaranteed agreement with the coaching path -- the right tradeoff for a slow-changing signal like annotations, and exactly what 'consumes from the provider wrapper' means.

AC#2: test/alert_effective_low_wiring_test.dart -- an end-to-end ProviderContainer test (not just resolveEffectiveThresholds's pure pass-through, which would prove nothing about the wiring) proving a profile-driven low-line modifier changes whether a real onSnapshot() cycle fires predicted-low, using the exact same effectiveLowThresholdProvider value the coaching path reads. Rigor-checked: temporarily hardcoded onSnapshot's effectiveLow back to a fixed default (simulating exactly the silent-divergence bug this ticket is about) -- the new test failed with the predicted 'expected true, got false'; reverted, green again.

Also updated/simplified the pre-existing resolveEffectiveThresholds test group in alert_orchestrator_test.dart: the 5 tests asserting the low-line MODIFIER composition (impaired-awareness/alcohol/exercise/weather/compose-via-max) were testing logic that moved to EffectiveLowThreshold.compute -- already thoroughly pinned in effective_low_threshold_test.dart, so keeping them here would just assert pass-through, not real behaviour. Replaced with one 'flows straight through' test; kept the postMeal-band-selection test (still resolveEffectiveThresholds's own job).

Fixed a real regression this surfaced: onSnapshot() now unconditionally reads effectiveLowThresholdProvider (-> recentAnnotationsProvider -> dayHistoryControllerProvider) whenever state != null, which broke 2 pre-existing ProviderContainer-based test files (alert_service_failure_injection_test.dart, app_root_snapshot_chain_test.dart) that didn't override recentAnnotationsProvider and hit 'DayHistoryController used after dispose' -- the exact pre-existing pitfall their own comments already warned about for rescueCarbAdviceProvider. Added the same override to both.

Pipeline: build_runner build, flutter analyze clean, flutter test --coverage test/ 1135/1135 green, coverage 67.6% (unchanged/floor-compliant), flutter build apk --debug succeeded. No native Kotlin, no user-visible change.
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
