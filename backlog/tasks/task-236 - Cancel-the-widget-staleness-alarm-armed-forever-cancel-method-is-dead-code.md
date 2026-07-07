---
id: TASK-236
title: 'Cancel the widget staleness alarm (armed forever, cancel method is dead code)'
status: Done
assignee:
  - Claude
created_date: '2026-07-07 07:48'
updated_date: '2026-07-07 23:41'
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
- [x] #1 Alarm cancelled from `BgWidgetProvider.onDisabled` and on unpair
- [x] #2 Alarm armed only when at least one widget instance exists (or documented why always-on is intended)
- [x] #3 Robolectric test covers arm/cancel
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 23:32
---
Started: cancel the widget staleness alarm from BgWidgetProvider.onDisabled and on unpair; gate arming on at least one widget instance existing; add a Robolectric arm/cancel test.
---

author: Claude
created: 2026-07-07 23:41
---
All 3 ACs done.

AC#1 (cancel on onDisabled and on unpair): BgWidgetProvider now overrides onEnabled/onDisabled (both SafeCallbacks-guarded, matching the file's existing throw-containment convention since BgWidgetProvider shares PumpService's process). onDisabled calls WidgetNativePush.cancelStalenessRenders. PumpService.unpair() also cancels it directly -- no more pump data means the periodic re-render has nothing to do until a future re-pair.

AC#2 (armed only when a widget exists): added WidgetNativePush.hasWidgetInstances() + scheduleStalenessRendersIfWidgetsExist(), which PumpService.onCreate now calls instead of the old unconditional scheduleStalenessRenders. Kept the arm call IN onCreate (not moved solely to onEnabled) deliberately: onEnabled only fires once per widget ADD, not on every boot, and the alarm type (ELAPSED_REALTIME, non-wakeup) does not survive reboot -- moving arming out of onCreate entirely would have silently broken the TASK-177 reboot-survival guarantee this whole feature exists for. BgWidgetProvider.onEnabled ALSO arms directly, covering a widget added while the service is already running.

AC#3: android/app/src/test/kotlin/.../WidgetNativePushAlarmTest.kt (Robolectric, 5 tests) using shadowOf(alarmManager).scheduledAlarms to assert arm/cancel state directly, plus shadowOf(AppWidgetManager).createWidget(...) (the existing BgWidgetProviderTest.kt convention) for the widget-exists gating.

Rigor check: temporarily removed the cancel call from onDisabled -- exactly the 'onDisabled cancels...' test failed (AssertionError), the other 4 stayed green; reverted, git diff clean. (Also confirmed removing the two new WidgetNativePush methods entirely is a compile error, since the new test references them directly.)

Pipeline: gradlew :app:testDebugUnitTest green (both the new widget tests and the full native suite), flutter analyze clean, build_runner build, flutter test --coverage test/ 1150/1150 green (native-only change, Dart coverage unaffected), flutter build apk --debug succeeded.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
