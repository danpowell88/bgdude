---
id: TASK-236
title: 'Cancel the widget staleness alarm (armed forever, cancel method is dead code)'
status: To Do
assignee: []
created_date: '2026-07-07 07:48'
labels:
  - code-health
  - native
  - ui
milestone: m-8
dependencies: []
priority: medium
ordinal: 113244
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** TASK-177 (95ceaf8) arms a 10-minute inexact repeating broadcast in `PumpService.onCreate` (`WidgetNativePush.scheduleStalenessRenders`, `WidgetNativePush.kt:63`) so the widget greys out when the engine dies — but `cancelStalenessRenders` (:73) is never called from anywhere: no `PumpService.onDestroy`, no `BgWidgetProvider.onDisabled`/`onDeleted`. The alarm outlives the service and keeps waking the receiver every ~10 min until reboot, even after unpair or after the user removes the last widget.

**Reason for change.** An intentionally-written cancel method that is dead code signals omitted cleanup; unbounded periodic wakeups cost battery for nothing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Alarm cancelled from `BgWidgetProvider.onDisabled` and on unpair
- [ ] #2 Alarm armed only when at least one widget instance exists (or documented why always-on is intended)
- [ ] #3 Robolectric test covers arm/cancel
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Wire `onDisabled`/unpair cancellation; gate arming on `getAppWidgetIds` non-empty.
- Add the Robolectric test.
- Verify: `gradlew :app:testDebugUnitTest` green; `flutter build apk --debug` OK.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: hourly quality check 2026-07-07 #3 (finding 2)
- Effort: S
- Where: android/.../widget/WidgetNativePush.kt:63-73, BgWidgetProvider, PumpService.kt:64
- Related: TASK-177 (introduced), TASK-202 (onDestroy scope — extend it)
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
