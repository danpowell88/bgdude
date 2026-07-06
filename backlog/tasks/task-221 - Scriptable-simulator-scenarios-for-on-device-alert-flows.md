---
id: TASK-221
title: Scriptable simulator scenarios for on-device alert flows
status: To Do
assignee: []
created_date: '2026-07-06 22:13'
labels:
  - testing
  - feature
  - alerts
milestone: m-8
dependencies: []
priority: medium
ordinal: 113500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `SimulatedPumpClient` streams one fixed physiological day; there is no way to script a forced urgent low, rapid rise, pump alarm, sensor warm-up or stubborn high on an emulator. This is the emulator-able alternative to the two-device software pump (TASK-83).

- `PumpSnapshot` already carries `activeAlarms`/`activeAlerts`.
- The demo day (`dev/sim_data.dart`) already seeds teachable events.

**Value.** Scripted scenarios let every alert-driven UI state (banner, chip, alert row) be exercised deterministically on an emulator, without hardware or waiting for the fixed demo day to reach the right moment.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A `SimulatedScenario` config on `SimulatedPumpClient`/`SimulatedDay` covers forcedUrgentLow, rapidRise, pumpAlarm(name), sensorWarmup and stubbornHigh
- [ ] #2 `pumpDemoApp(scenario:)` override is available in the harness
- [ ] #3 An on-device test per scenario asserts the UI state responds (banner/chip/alert row)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Design a `SimulatedScenario` config type covering forcedUrgentLow, rapidRise, pumpAlarm(name), sensorWarmup, stubbornHigh.
- Wire the scenario into `SimulatedPumpClient`/`SimulatedDay` so it overrides the fixed day and populates `activeAlarms`/`activeAlerts` as needed.
- Add a `scenario:` parameter to `pumpDemoApp` in `integration_test/harness.dart`.
- Add one on-device test per scenario asserting the responding UI state.
- Verify: `flutter analyze` clean, `flutter test` green.
- Verify: run the new scenario tests on an emulator (`flutter test integration_test/<file>.dart -d emulator-5554`).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: device-testing sweep 2026-07-07 (emulator audit)
- Effort: M-L
- Where: `lib/dev/sim_data.dart`, simulated pump client, `integration_test/harness.dart`
- Related: TASK-83 (hardware path), TASK-93, TASK-116, TASK-176
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
