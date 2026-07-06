---
id: TASK-177
title: Widget must re-render (and grey out) when the Flutter engine dies
status: To Do
assignee: []
created_date: '2026-07-06 09:17'
labels:
  - code-health
  - ui
  - native
milestone: m-8
dependencies: []
priority: medium
ordinal: 177000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `bg_widget_info.xml:19` sets `updatePeriodMillis="0"` and re-renders are driven only by a Dart `Timer.periodic` (`lib/widget/home_widget_service.dart:92-95`); native `PumpService.onSnapshotUpdated` (`PumpService.kt:98-102`) forwards to Garmin but never to the widget. If the OS kills the Flutter engine while the service keeps the BLE link, the widget shows the last value in green with a frozen "3m ago" indefinitely — its (correct, tested) staleness logic never runs.

**Reason for change.** A frozen-but-green home-screen glucose value is worse than no widget; staleness must be enforced natively, not from the Dart isolate.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Widget data is pushed from native `PumpService.onSnapshotUpdated`
- [ ] #2 A native periodic re-render (AlarmManager/WorkManager) guarantees grey-out past the staleness threshold even with no new data
- [ ] #3 Robolectric render test asserts grey-out
- [ ] #4 Gradle tests green
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Forward snapshots to the widget from `PumpService.onSnapshotUpdated` alongside the Garmin push.
- Add a native periodic re-render (AlarmManager or WorkManager) so staleness grey-out happens without new data or a live Dart isolate.
- Add a Robolectric render test asserting grey-out past the threshold.
- Verify: `flutter analyze` clean, `flutter test` green, `cd android && ./gradlew :app:testDebugUnitTest` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (reliability finding 3)
- Effort: M
- Where: `android/app/src/main/res/xml/bg_widget_info.xml`, `PumpService.kt`, `lib/widget/home_widget_service.dart`
- Related: TASK-37
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
