---
id: TASK-158
title: Predicted-low glance on the home widget and Garmin
status: To Do
assignee: []
created_date: '2026-07-06 08:45'
labels:
  - feature
  - ui
  - garmin
milestone: m-7
dependencies:
  - TASK-24
  - TASK-31
priority: medium
ordinal: 158000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The forecast + calibrated band are computed every snapshot (`lib/state/providers.dart:1405-1408`), yet the glanceable surfaces show only current BG/trend/IOB (`lib/widget/bg_widget_format.dart:91-108`; `android/.../garmin/GarminSender.kt`) — the app differentiator never reaches the widget/watch.

**Value.** A predicted-low glance on the widget and watch delivers the core value of the app without opening it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A forecast field (e.g. `nextLowMinutes` or a band-risk token) is added to the widget payload and Kotlin renderer
- [ ] #2 The same token is plumbed to the Garmin complication
- [ ] #3 Contract keys are added to the centralized constants (TASK-111)
- [ ] #4 Tests pass, including gradle
- [ ] #5 The user guide is updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add the forecast field (`nextLowMinutes` or a band-risk token) to the widget payload.
- Render it in the Kotlin widget renderer.
- Plumb the same token to the Garmin complication via `GarminSender.kt`.
- Add the contract keys to the centralized constants (TASK-111).
- Add tests on both sides.
- Update `doc/user-guide.html`.
- Verify: `flutter analyze` clean, `flutter test` green, `cd android && ./gradlew :app:testDebugUnitTest` green, spot-check the widget on the emulator.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/widget/bg_widget_format.dart:91-108`, `android/.../garmin/GarminSender.kt`)
- Effort: M
- Where: `lib/widget/bg_widget_format.dart`, Kotlin widget renderer, `android/.../garmin/GarminSender.kt`, `doc/user-guide.html`
- Related: TASK-111 (contract keys)
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
