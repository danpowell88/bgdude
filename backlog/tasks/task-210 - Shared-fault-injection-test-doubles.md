---
id: TASK-210
title: Shared fault-injection test doubles
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:12'
updated_date: '2026-07-07 18:27'
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
- [x] #1 `test/support/faults.dart` exists with `FaultInjectingHistoryRepository` (per-method failOn/throwOnce over InMemoryHistoryRepository), `ThrowingNotificationService` (records calls, throws on show), `ErroringPumpSource`, and `ThrowingHealthSyncService` — hand-written, no mocking framework
- [x] #2 Each double is adopted by at least one test
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 18:21
---
Started: build test/support/faults.dart with the 4 hand-written throwing doubles, then adopt each in at least one test.
---

author: Claude
created: 2026-07-07 18:27
---
Done. test/support/faults.dart (new) has the 4 doubles: FaultInjectingHistoryRepository (wraps InMemoryHistoryRepository by default, per-method failOn/clearFailOn/throwOnce over all 17 HistoryRepository methods), ThrowingNotificationService (extends NotificationService, records every category passed to show() in .shown, throws while shouldThrow is true -- never touches the real FlutterLocalNotificationsPlugin since show() returns before the superclass would), ErroringPumpSource (full hand-written PumpSource implementation with broadcast StreamControllers for all 6 streams plus emitConnection/emitSnapshot/emitError/emitPairingRequest/emitTherapyProfile to drive them, and a failOn(method) set that makes exactly the named command throw while everything else behaves like a healthy connection), ThrowingHealthSyncService (extends HealthSyncService, fetch() throws by default via failFetch, requestPermissions() throws only when failPermissions is set).

Adopted each in test/support/faults_test.dart (5 tests, one dedicated group per double) proving: per-method fail isolation + clearFailOn + throwOnce recovery for the repository, category recording + throw for notifications, per-command fail isolation + working streams for the pump source, and the two independent failure toggles for health sync. TASK-211/212/213/214 (which depend on this ticket) build their specific failure scenarios on top of these instead of writing more ad-hoc doubles.

Pipeline: flutter analyze clean, flutter test test/ 1011/1011 (+5 new), flutter build apk --debug succeeded. No native Kotlin, no user-visible change -- no user-guide update.
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
