---
id: TASK-256
title: Add a mid-write interruption scenario to the restart harness
status: Done
assignee:
  - Claude
created_date: '2026-07-07 14:29'
updated_date: '2026-07-08 09:08'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 530000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
RestartSimulation with InMemoryHistoryRepository and in-memory KvStore writes synchronously and every test awaits the writes or a short delay before crashing, then dispose is a clean teardown. No test kills the process mid-saveCgm, mid-KvStore-write or mid-notification-schedule, so the partial-write or torn-state path a crash-restart ticket implies is never hit.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A scenario simulates a crash during an in-flight write (torn or partial state) and asserts the app recovers to a consistent state
- [x] #2 Covers at least a mid-DB-write and a mid-notification-schedule interruption
<!-- AC:END -->



## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-194)
- Files: test/support/restart_simulation.dart, test/restart_recovery_test.dart
- Related: TASK-210 (shared fault-injection doubles) may provide the interruption primitive
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 09:08
---
Started+done. Every existing restart-simulation scenario awaited its write (or a settle delay) before crashing, so none ever hit the app mid-write -- added two that genuinely interrupt an in-flight multi-step write. AC number 1/2: loosened RestartSimulation.repo from InMemoryHistoryRepository to the plain HistoryRepository interface (one line, verified only annotations() -- part of the interface -- was ever called on sim.repo elsewhere) so a FaultInjectingHistoryRepository wrapper can stand in for it; throwOnce self-clears after firing, so the SAME sim instance models "restart over the same now-fault-free delegate" with no extra reset step. Scenario 1 (mid-DB-write): illness-mode deactivation -- IllnessModeNotifier._persist (TASK-258) saves the KvStore mode change FIRST, then the annotation separately; faulty.throwOnce(saveAnnotation) interrupts just the annotation write, and after restart the mode change is durable (KvStore write already landed) while the annotation is cleanly absent, never a torn/partial entry. Scenario 2 (mid-notification-schedule): AppJobs.checkExerciseHypoRisk fires a notification THEN persists a dedup flag (exercise_hypo_warned_<date>) -- ThrowingNotificationService interrupts right at the notification call, so the flag write never runs; after restart the flag is unset, proving the crash lands on the side of re-checking (a redundant warning at worst) rather than silently skipping a real one forever -- same bias as the alert loops own TASK-38 mark-fired-after-send pattern. Rigor-checked both: for scenario 1, removed the throwOnce and confirmed the annotation legitimately saves (proving the assertion isnt vacuous); for scenario 2, made the notification succeed instead of throw and confirmed the dedup flag legitimately gets set. Both reverted cleanly. Pipeline green: analyze clean, 1323/1323 tests pass (2 new), coverage 68.10% (floor 65%), apk debug build succeeds. No native Kotlin touched, no user-visible change.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [x] #8 backlog item updated with comments
<!-- DOD:END -->
