---
id: TASK-220
title: Deterministic demo seam + integration-test isolation
status: To Do
assignee: []
created_date: '2026-07-06 22:13'
labels:
  - testing
  - code-health
milestone: m-8
dependencies: []
priority: high
ordinal: 113400
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** On-device value assertions are unsafe today because the demo seam moves with wall-clock time: `SimulatedPumpClient` regenerates `SimulatedDay.generate(now: _clock())` every 30 s, and `DemoHistory.build(now: DateTime.now())` plus `demoHistoryRepositoryProvider` (`providers.dart:1009`) read real time, so the current reading and which teachable events are near-now vary by run time; noise is seeded but time-of-day dependent.

- `harness.dart` never resets the static `KvStore` (`kv_store.dart` process-global `_mem`) between `testWidgets`, so app flags/prefs leak across tests.
- The sim ticker is only cancelled on provider dispose.

**Reason for change.** Deterministic time/seed injection and per-test isolation are prerequisites for asserting displayed values on-device; today such assertions flake depending on when the suite runs.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `pumpDemoApp` accepts a fixed `now`/seed threaded into the simulator and demo repository
- [ ] #2 Harness setUp/tearDown resets `KvStore` and disposes the sim ticker
- [ ] #3 A canonical run-list script under `tools/` names the deterministic functional files for local + CI
- [ ] #4 One displayed-value assertion proves stability across two runs
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add optional `now`/seed parameters to `pumpDemoApp` in `integration_test/harness.dart`.
- Thread the fixed clock/seed into `SimulatedPumpClient`, `SimulatedDay.generate`, `DemoHistory.build` and `demoHistoryRepositoryProvider`.
- Add harness setUp/tearDown that resets the static `KvStore` and cancels/disposes the sim ticker between tests.
- Add a run-list script under `tools/` naming the deterministic functional test files.
- Add one displayed-value assertion and run the file twice to prove stability.
- Verify: `flutter analyze` clean, `flutter test` green.
- Verify: run the touched functional files on an emulator (`flutter test integration_test/<file>.dart -d emulator-5554`).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: device-testing sweep 2026-07-07 (emulator audit)
- Effort: M
- Where: `integration_test/harness.dart`, `lib/dev/sim_data.dart`, `lib/providers.dart`, `kv_store.dart`, `tools/`
- Related: TASK-39, TASK-167 (unblocks), TASK-170, TASK-172
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
