---
id: TASK-211
title: Failure-injection tests for the alert loop
status: To Do
assignee: []
created_date: '2026-07-06 21:12'
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
- [ ] #1 ProviderContainer test with ThrowingNotificationService plus a forced urgent-low: onSnapshot never throws; the second call retries (show count 2)
- [ ] #2 A throw in one category still lets later categories evaluate
- [ ] #3 savePrediction throwing (faulty repo) does not abort the loop
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
