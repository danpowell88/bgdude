---
id: TASK-260
title: >-
  Illness/medication persist failure leaves in-memory dosing state diverged from
  the UI
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 16:26'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 525000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
In providers.dart the IllnessMode activate/deactivate/updateBoost mutate _controller.mode BEFORE _persist(), and state = _controller.mode is only set on a successful write. Dosing math (effectiveSensitivityProvider then illness.overlay(ctx) then _controller.overlay) reads _controller.mode, NOT state. So on a failed write: _controller.mode is active (illness resistance boost applied to dosing), state is inactive (UI shows off), and disk has nothing (boost silently vanishes on next restart). The two diverge from each other, unlike the therapy path which reverts to a consistent state. MedicationMode and MealLibrary are the same class but milder: they set state before the await, so state and dosing stay mutually consistent and only diverge from disk (log-only, reverts on restart). TASK-198 explicitly scoped these hand-rolled paths to the logging half, so this is an acknowledged partial.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 On a failed illness-mode write, the dosing controller (_controller.mode) and the UI state are reconciled to the same value (both revert, or both stay with a surfaced error)
- [ ] #2 Medication mode and meal library apply the same reconcile-on-failure semantics
- [ ] #3 Test: a failed write leaves dosing math and UI state agreeing, not diverged
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-198)
- File: lib/state/providers.dart IllnessMode _persist ~1000, overlay ~1044, consumer ~1072; MedicationMode ~1094; MealLibrary ~1397
- Distinct from TASK-259 (base-notifier latch): these are the hand-rolled mode notifiers
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
