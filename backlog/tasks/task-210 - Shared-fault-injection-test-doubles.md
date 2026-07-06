---
id: TASK-210
title: Shared fault-injection test doubles
status: To Do
assignee: []
created_date: '2026-07-06 21:12'
labels:
  - code-health
  - testing
milestone: m-8
dependencies: []
priority: medium
ordinal: 112400
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Every key dependency is injectable today (HistoryRepository interface + provider override, NotificationService non-final + override, PumpSource interface, HealthSyncService ctor seam, PanelOcr/PanelLlm interfaces, NightscoutClient http.Client ctor param) but the only throwing double in the whole suite is the food-DB one (`test/food_database_test.dart:104`) — no faulty repository/notifier/pump-source/health double exists, so none of the critical failure paths can be exercised.

**Value.** A shared faults module unlocks the failure-injection test tickets (alert loop, snapshot chain, runStartup) without ad-hoc doubles per test.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `test/support/faults.dart` exists with `FaultInjectingHistoryRepository` (per-method failOn/throwOnce over InMemoryHistoryRepository), `ThrowingNotificationService` (records calls, throws on show), `ErroringPumpSource`, and `ThrowingHealthSyncService` — hand-written, no mocking framework
- [ ] #2 Each double is adopted by at least one test
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Create `test/support/faults.dart` with the four doubles: `FaultInjectingHistoryRepository` (per-method failOn/throwOnce over InMemoryHistoryRepository), `ThrowingNotificationService` (records calls, throws on show), `ErroringPumpSource`, `ThrowingHealthSyncService`
- Keep them hand-written; no mocking framework
- Adopt each double in at least one existing or new test
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (injection finding 15)
- Effort: M
- Where: `test/support/faults.dart` (new)
- Related: TASK-108, TASK-194
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
