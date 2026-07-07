---
id: TASK-194
title: Crash-restart recovery simulation tests
status: To Do
assignee:
  - Claude
created_date: '2026-07-06 12:56'
updated_date: '2026-07-07 14:02'
labels:
  - code-health
  - testing
  - detail-needed
milestone: m-8
dependencies: []
priority: medium
ordinal: 109100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Nothing in test/ simulates a process death and restart over the same persistence: construct a provider container, ingest data and fire alerts, tear it down (no dispose niceties), then build a fresh container over the same in-memory KV/DB and assert recovery invariants. In-memory state like `AlertService._lastFired` is lost on restart today — behaviour after a crash (double-alert vs suppressed) is unspecified and untested.

**Reason for change.** Crash-recovery behaviour is currently whatever the code happens to do; for an alerting app the post-restart contract should be chosen and pinned.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A reusable restart-simulation harness (fresh ProviderContainer over persistent fakes) in test/support/
- [ ] #2 Pinned invariants: an urgent-low active across restart re-fires exactly once; pending confirmations survive; active modes (exercise/illness) survive; day history rebuilds from the repo
- [x] #3 The chosen _lastFired persistence decision is documented on the task and implemented
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Build the harness (shares TASK-108 fixtures and the persistent MemoryKvStore).
- Decide + implement the _lastFired contract (persist recent fires vs accept one re-fire).
- Write the four invariant tests.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep 2026-07-06
- Effort: M
- Where: test/support/, lib/state/providers.dart (_lastFired persistence)
- Related: TASK-108, TASK-172, TASK-176
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 14:02
---
AC#1 done: test/support/restart_simulation.dart (RestartSimulation — shares KvStore's static in-memory backing and one InMemoryHistoryRepository instance across fresh ProviderContainers, modelling a crash+relaunch with no graceful shutdown). AC#3 done: the _lastFired persistence decision is do-NOT-persist (documented in test/restart_recovery_test.dart) — a crash mid-cooldown means the next launch's fresh CooldownGate has no memory of the earlier fire, so a still-active urgent-low re-fires once more; the alternative (persisting last-fired timestamps) risks an incorrectly SUPPRESSED alert from a stale value, which is the wrong failure direction for a hypoglycemia alert. No code change needed — already the only code path (CooldownGate is a plain in-memory field, nothing in AlertService/alert_orchestrator.dart ever touches KvStore/the repo for it). AC#2: 3 of 4 invariants verified true and tested — pending-confirmation DECISIONS survive (ConfirmationDecisionStore, key confirmation_decisions_v1; the candidate LIST itself is derived fresh from the repo every read by design, nothing to restore there), illness mode survives (KvStore key illness_mode_v1), day history rebuilds via an explicit reload(). detail-needed flag: exercise mode does NOT survive a restart, and this is an EXISTING, DOCUMENTED design decision (providers.dart:287-289: 'In-memory/transient — exercise is a short-lived state'), not an oversight I introduced — it conflicts with this ticket's own AC#2 wording ('active modes (exercise/illness) survive'). Need a call: leave exercise mode transient (a rare crash drops a short workout announcement — low stakes) or add KvStore persistence matching illness mode's pattern (ExercisePlan already has toJson/fromJson, so the change is small if wanted) — flagging rather than guessing since it reverses a prior deliberate choice. Found via a debugging detour worth noting: Riverpod provider values are built LAZILY on first read, not when the container is constructed — a naive 'await a delay after building the container' before reading a persisted-state provider races nothing, since the notifier (and its unawaited restore-from-KvStore call) doesn't exist until that first read; the test harness reads .notifier first to force construction, then waits. Pipeline green: analyze clean, 923 tests passed, apk debug build succeeds.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
