---
id: TASK-213
title: runStartup per-dependency failure tests
status: To Do
assignee: []
created_date: '2026-07-06 21:12'
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
- [ ] #1 Throwing health/repo/pump doubles: runStartup completes AND downstream jobs (e.g. forecaster training) still executed, observed via state
- [ ] #2 Health-permission-denied yields the zero-features assertion at the provider level
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
