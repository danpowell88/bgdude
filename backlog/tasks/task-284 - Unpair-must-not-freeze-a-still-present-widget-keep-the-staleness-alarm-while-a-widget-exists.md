---
id: TASK-284
title: >-
  Unpair must not freeze a still-present widget -- keep the staleness alarm
  while a widget exists
status: To Do
assignee:
  - Claude
created_date: '2026-07-08 00:24'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 117000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-236 made PumpService.unpair() call WidgetNativePush.cancelStalenessRenders(applicationContext) unconditionally. But unpair() (via PumpCommHandler.unpair) only tears down BLE -- it does not stop the foreground service or remove the widget. If the user has a widget placed on the home screen and taps Unpair in Settings, the staleness re-render alarm is cancelled while the widget is still there and no new pump data will ever arrive. Grey-out/staleness is computed only at render time and is driven solely by this periodic alarm, so the widget never re-renders and stays frozen at its last BG value and colour (e.g. green 3m ago) indefinitely -- until a reboot, service recreate, or the widget is removed and re-added. This reintroduces the TASK-177 frozen-green-widget bug for the unpair path, exactly when grey-out matters most (data has stopped). The asymmetry is the bug: the arm path is gated (scheduleStalenessRendersIfWidgetsExist checks hasWidgetInstances) but the unpair cancel is not.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 After unpair with a widget still placed, the widget greys out / shows stale rather than freezing at a stale live-looking value
- [ ] #2 The staleness alarm is cancelled on unpair only when no widget instance exists (mirror the arm gate, e.g. cancelStalenessRendersIfNoWidgets), or not cancelled on unpair at all -- letting onDisabled own removal
- [ ] #3 onDisabled (last widget removed) still cancels the alarm (no leak)
- [ ] #4 Test: unpair with a widget present leaves the alarm armed (or otherwise guarantees a grey-out render)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-236)
- File: android/app/src/main/kotlin/com/bgdude/app/pump/PumpService.kt:149-155 unconditional cancelStalenessRenders; contrast WidgetNativePush.scheduleStalenessRendersIfWidgetsExist:90 which is gated
- Regression against TASK-177 (widget must re-render and grey out when data stops)
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test --coverage test/ green
- [ ] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [ ] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->
