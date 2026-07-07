---
id: TASK-211
title: Failure-injection tests for the alert loop
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:12'
updated_date: '2026-07-07 18:36'
labels:
  - code-health
  - testing
  - "\U0001F512 safety"
milestone: m-8
dependencies:
  - TASK-210
priority: medium
ordinal: 112500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The alert loop is CORRECTLY coded for notifier failures — `try { await show(); _markFired } catch { log }` (`lib/providers.dart:1481-1490`) means a failed urgent-low does not advance dedup and retries next cycle — but zero tests pin this; no test constructs AlertService at all.

**Reason for change.** A refactor (e.g. TASK-116) could silently invert the show/markFired order and kill the retry behaviour without any test failing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ProviderContainer test with ThrowingNotificationService plus a forced urgent-low: onSnapshot never throws; the second call retries (show count 2)
- [x] #2 A throw in one category still lets later categories evaluate
- [x] #3 savePrediction throwing (faulty repo) does not abort the loop
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Build a ProviderContainer test constructing AlertService with `ThrowingNotificationService` from `test/support/faults.dart`
- Force an urgent-low and assert onSnapshot never throws and the second cycle retries (show count 2, dedup not advanced)
- Assert a throw in one alert category still lets later categories evaluate
- Assert savePrediction throwing (FaultInjectingHistoryRepository) does not abort the loop
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (injection finding 16)
- Effort: M
- Where: `lib/providers.dart:1481-1490`, new test alongside the alert tests
- Related: TASK-15 (the behaviour), TASK-116 (refactor this pins)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 18:27
---
Started: locate AlertService.onSnapshot in lib/state/providers.dart, build a ProviderContainer test using ThrowingNotificationService + FaultInjectingHistoryRepository from test/support/faults.dart.
---

author: Claude
created: 2026-07-07 18:36
---
Done. test/alert_service_failure_injection_test.dart (new, 5 tests) constructs a real AlertService via ProviderContainer for the first time in the suite, overriding notificationServiceProvider (ThrowingNotificationService), historyRepositoryProvider (FaultInjectingHistoryRepository), pumpSnapshotProvider/dayDataProvider/livePredictionStateProvider/calibratedForecastsProvider with controlled values, and rescueCarbAdviceProvider -> null (it otherwise pulls in the real DayHistoryController, which outlives a single onSnapshot() call and trips container.dispose()).

AC1: onSnapshot never throws with every send failing; a second cycle re-attempts the urgent low (fired twice) because AlertUrgency.critical only marks fired AFTER a successful show(); a successful send is NOT re-fired on an immediately-following cycle (cooldown holds). AC2: an active pump alarm + a low reservoir in the same snapshot both get attempted even though every show() throws -- proves the decisions for-loop doesn't abort on the first exception. AC3: failOn('savePrediction') on the repo still lets onSnapshot complete and the unrelated urgent-low alert still fires.

Verified rigor: temporarily inverted the show()/_markFired() order in lib/state/providers.dart (the exact regression this ticket exists to catch) and reran -- the retry test failed as expected (1 attempt instead of 2), confirming the test is load-bearing, not tautological. Reverted immediately after (git diff clean).

Pipeline: flutter analyze clean, flutter test test/ 1016/1016, flutter build apk --debug succeeded. No native Kotlin, no user-visible change -- no user-guide update.
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
