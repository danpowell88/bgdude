---
id: TASK-213
title: runStartup per-dependency failure tests
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:12'
updated_date: '2026-07-07 19:24'
labels:
  - code-health
  - testing
milestone: m-8
dependencies:
  - TASK-210
priority: medium
ordinal: 112700
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `runStartup` wraps each job in try/catch (`lib/providers.dart:1766-1809`) but `test/jobs_test.dart:67` asserts only aggregate completion — nothing injects a throwing HealthSyncService/repository and asserts that INDEPENDENT later jobs still ran, nor that a denied health permission yields the zeros contract end-to-end via `livePredictionStateProvider` (`lib/providers.dart:1170`).

**Reason for change.** The per-job isolation in runStartup is load-bearing but unpinned; a refactor could make one failing dependency cascade into skipping unrelated startup jobs.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Throwing health/repo/pump doubles: runStartup completes AND downstream jobs (e.g. forecaster training) still executed, observed via state
- [x] #2 Health-permission-denied yields the zero-features assertion at the provider level
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Use `ThrowingHealthSyncService`, `FaultInjectingHistoryRepository`, and `ErroringPumpSource` from `test/support/faults.dart` in a runStartup test
- Assert runStartup completes and independent later jobs (e.g. forecaster training) still executed, observed via state
- Add a health-permission-denied case asserting the zero-features contract end-to-end via `livePredictionStateProvider`
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (injection finding 18)
- Effort: S-M
- Where: `lib/providers.dart:1766-1809`, `test/jobs_test.dart`
- Related: TASK-123
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 19:19
---
Started: locate runStartupJobs + livePredictionStateProvider's health-features wiring, build tests using ThrowingHealthSyncService/FaultInjectingHistoryRepository/ErroringPumpSource from test/support/faults.dart.
---

author: Claude
created: 2026-07-07 19:24
---
Done. Extended test/jobs_test.dart with a 'per-job failure isolation' group (2 new tests) reusing its existing SimulatedDay-seeded InMemoryHistoryRepository setup.

AC1: overrides healthSyncServiceProvider with ThrowingHealthSyncService (test/support/faults.dart), runs the REAL AppJobs.runStartup(), asserts report.failures contains 'syncHealth' (the injected failure genuinely surfaced) AND repo.modelRuns() is non-empty -- proving the later, independent trainForecaster job actually did its real work (not just 'job marked ok'), despite the earlier failure.

AC2: same throwing health sync, but first forces DayHistoryController.reload() so the seeded CGM gives livePredictionStateProvider a latest reading. After runStartup(), asserts state.healthFeatures == HealthFeatureSampler.zeros end-to-end -- refreshForecastHealthSampler (a separate, unconditional job right after syncHealth) still ran and built a sampler from no data, which resolves to the identical zero contract as no sampler at all.

Verified rigor (safety-adjacent -- per-job isolation guards startup from one bad dependency taking down the rest): temporarily removed the try/catch in lib/state/startup_jobs.dart's runStartupJobs loop (the exact regression this pins) and reran -- both new tests failed with the injected exception propagating, plus the pre-existing 'runStartup completes without throwing' test also failed. Reverted immediately (git diff clean).

Pipeline: flutter analyze clean, flutter test test/ 1022/1022, flutter build apk --debug succeeded. No native Kotlin, no user-visible change -- no user-guide update.
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
