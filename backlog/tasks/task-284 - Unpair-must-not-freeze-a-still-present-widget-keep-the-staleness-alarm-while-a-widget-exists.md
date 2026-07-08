---
id: TASK-284
title: >-
  Unpair must not freeze a still-present widget -- keep the staleness alarm
  while a widget exists
status: Done
assignee:
  - Claude
created_date: '2026-07-08 00:24'
updated_date: '2026-07-08 01:00'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 113253
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-236 made PumpService.unpair() call WidgetNativePush.cancelStalenessRenders(applicationContext) unconditionally. But unpair() (via PumpCommHandler.unpair) only tears down BLE -- it does not stop the foreground service or remove the widget. If the user has a widget placed on the home screen and taps Unpair in Settings, the staleness re-render alarm is cancelled while the widget is still there and no new pump data will ever arrive. Grey-out/staleness is computed only at render time and is driven solely by this periodic alarm, so the widget never re-renders and stays frozen at its last BG value and colour (e.g. green 3m ago) indefinitely -- until a reboot, service recreate, or the widget is removed and re-added. This reintroduces the TASK-177 frozen-green-widget bug for the unpair path, exactly when grey-out matters most (data has stopped). The asymmetry is the bug: the arm path is gated (scheduleStalenessRendersIfWidgetsExist checks hasWidgetInstances) but the unpair cancel is not.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 After unpair with a widget still placed, the widget greys out / shows stale rather than freezing at a stale live-looking value
- [x] #2 The staleness alarm is cancelled on unpair only when no widget instance exists (mirror the arm gate, e.g. cancelStalenessRendersIfNoWidgets), or not cancelled on unpair at all -- letting onDisabled own removal
- [x] #3 onDisabled (last widget removed) still cancels the alarm (no leak)
- [x] #4 Test: unpair with a widget present leaves the alarm armed (or otherwise guarantees a grey-out render)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-236)
- File: android/app/src/main/kotlin/com/bgdude/app/pump/PumpService.kt:149-155 unconditional cancelStalenessRenders; contrast WidgetNativePush.scheduleStalenessRendersIfWidgetsExist:90 which is gated
- Regression against TASK-177 (widget must re-render and grey out when data stops)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 00:54
---
Started+fixed: wrapped _AddMealSheet's Column in a SingleChildScrollView, same pattern as TASK-281's quick_log_sheet.dart fix. isScrollControlled: true was already set on the showModalBottomSheet call (lets the sheet itself grow tall), but the CONTENT still needed its own scrollable for when it doesn't fit.
---

author: Claude
created: 2026-07-08 00:55
---
Correction: the previous comment (about _AddMealSheet/SingleChildScrollView) was posted here by mistake -- meant for TASK-285, a different task that happened to land on the same ordinal after a mis-typed backlog edit command. That work has nothing to do with this ticket. This IS now genuinely being picked up, though (see next comment) -- it's a real, valid finding about my own TASK-236 work.
---

author: Claude
created: 2026-07-08 01:00
---
All 4 ACs done. Chose AC#2's second option: unpair() no longer cancels the alarm AT ALL (rather than mirroring the arm gate with a new cancelStalenessRendersIfNoWidgets) -- onDisabled is now the sole cancellation trigger, which is simpler and correctly matches the actual invariant (the alarm's job is purely 'does a widget exist', not 'is there live data'; unpair changes the latter, never the former).

AC#3 (onDisabled still cancels) was never touched, still true -- verified by the pre-existing WidgetNativePushAlarmTest.kt 'onDisabled cancels the alarm armed by onEnabled' test, still green.

AC#4: android/app/src/test/kotlin/.../PumpServiceUnpairAlarmTest.kt (Robolectric) -- installs a widget, boots a real PumpService (which arms the alarm via onCreate's gated scheduleStalenessRendersIfWidgetsExist), calls unpair(), asserts the alarm is still armed. Rigor-checked: reintroduced the unconditional cancel call, reran -- failed with the exact predicted AssertionError; reverted, git diff clean.

Note for the record since this ticket got tangled with TASK-285 by an editing mistake: an earlier comment on this task (now itself corrected) was posted here by accident and belongs to a different ticket -- see the correction comment above it.

Pipeline: gradlew :app:testDebugUnitTest green (full native suite), flutter analyze clean, build_runner build, flutter test --coverage test/ 1150/1150 green, flutter build apk --debug succeeded.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test --coverage test/ green
- [ ] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [x] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->
