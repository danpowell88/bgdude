---
id: TASK-194
title: Crash-restart recovery simulation tests
status: To Do
assignee: []
created_date: '2026-07-06 12:56'
updated_date: '2026-07-06 12:58'
labels:
  - code-health
  - testing
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
- [ ] #1 A reusable restart-simulation harness (fresh ProviderContainer over persistent fakes) in test/support/
- [ ] #2 Pinned invariants: an urgent-low active across restart re-fires exactly once; pending confirmations survive; active modes (exercise/illness) survive; day history rebuilds from the repo
- [ ] #3 The chosen _lastFired persistence decision is documented on the task and implemented
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
