---
id: TASK-220
title: Deterministic demo seam + integration-test isolation
status: In Progress
assignee:
  - Claude
created_date: '2026-07-06 22:13'
updated_date: '2026-07-07 20:02'
labels:
  - testing
  - code-health
  - detail-needed
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
- [x] #1 `pumpDemoApp` accepts a fixed `now`/seed threaded into the simulator and demo repository
- [ ] #2 Harness setUp/tearDown resets `KvStore` and disposes the sim ticker
- [x] #3 A canonical run-list script under `tools/` names the deterministic functional files for local + CI
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 19:55
---
Started: thread a fixed now/seed into the demo seam (SimulatedPumpClient, DemoHistory, demoHistoryRepositoryProvider), add harness KvStore reset + sim-ticker disposal, add a tools/ run-list script. AC#4 (on-device stability proof) and the emulator verify step are blocked by the documented emulator-connectivity limitation in this session -- will implement/verify everything else and flag that honestly.
---

author: Claude
created: 2026-07-07 20:02
---
detail-needed: AC#2's and AC#4's on-device half, plus the DoD's own 'run the touched functional files on an emulator' verify step, cannot be exercised in this session -- same pre-existing emulator-connectivity limitation as TASK-127/226/228/31/33.

What's done and verified here (no emulator needed):
- AC#1: added demoClockProvider (lib/state/providers.dart) -- a Provider<DateTime Function()> defaulting to DateTime.now, watched by pumpClientProvider (passed into SimulatedPumpClient's existing clock param) and demoHistoryRepositoryProvider (replacing the direct DateTime.now() call). integration_test/harness.dart's pumpDemoApp gained a fixedNow param that overrides demoClockProvider when given.
- AC#3: tools/run_functional_integration_tests.sh + .ps1 (new) -- the canonical file list (app_test, chaos_navigation, features_flows/protocol_explorer/reports/settings, nutrition_ocr_accuracy; excludes harness.dart and the flutter-drive-only screenshots/walkthrough files per CLAUDE.md), matching the existing tools/gen_docs.sh|ps1 pair's style.
- AC#4 (partial -- the provable-here half): test/demo_determinism_test.dart (new, 3 tests, all passing) proves SimulatedDay.generate(now: fixed) and DemoHistory.build(now: fixed) are byte-for-byte identical across two independent calls with the same now -- this is the actual root-cause claim (a fixed now removes ALL wall-clock variance), verified at the pure-Dart level since I can't drive a real widget tree on-device here. The on-device half (pumpDemoApp(fixedNow:) + an actual displayed-CGM-value assertion, run twice on a device) is written as the intended usage but genuinely unexecuted -- flagging rather than claiming it passed.

AC#2 (harness setUp/tearDown): added setUpDemoHarness() (KvStore.useMemory()) and tearDownDemoHarness(tester) (explicit pumpWidget(SizedBox.shrink()) so a SimulatedPumpClient's 30s ticker is reliably cancelled before the next testWidgets block, rather than relying on the next test's pumpWidget to trigger disposal). Neither is yet ADOPTED by the existing integration_test/*.dart files' own setUp/tearDown -- that adoption plus confirming it actually fixes cross-test leakage needs a session with working emulator connectivity.

Also noted for whoever picks this up: integration_test/app_test.dart has its own private _pumpApp duplicating harness.dart's pumpDemoApp almost exactly (pre-existing, not introduced here) -- worth migrating to the shared helper (with fixedNow) as part of finishing this out, but that's beyond this ticket's stated scope.

Pipeline: flutter analyze clean, flutter test test/ 1037/1037 (+3 new), flutter build apk --debug succeeded. No native Kotlin, no user-visible change.
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
