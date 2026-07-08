---
id: TASK-260
title: >-
  Illness/medication persist failure leaves in-memory dosing state diverged from
  the UI
status: Done
assignee:
  - Claude
created_date: '2026-07-07 16:26'
updated_date: '2026-07-08 05:13'
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
- [x] #1 On a failed illness-mode write, the dosing controller (_controller.mode) and the UI state are reconciled to the same value (both revert, or both stay with a surfaced error)
- [x] #2 Medication mode and meal library apply the same reconcile-on-failure semantics
- [x] #3 Test: a failed write leaves dosing math and UI state agreeing, not diverged
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-198)
- File: lib/state/providers.dart IllnessMode _persist ~1000, overlay ~1044, consumer ~1072; MedicationMode ~1094; MealLibrary ~1397
- Distinct from TASK-259 (base-notifier latch): these are the hand-rolled mode notifiers
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 04:59
---
Started: reading lib/state/providers.dart's IllnessMode/MedicationMode/MealLibrary notifiers to design reconcile-on-persist-failure semantics so _controller.mode (what dosing math reads) and state (what the UI reads) never diverge.
---

author: Claude
created: 2026-07-08 05:13
---
Fixed all 3 ACs across all three notifiers.

AC#1 (IllnessMode): _persist()'s catch block now reverts _controller.mode (what dosing math reads via overlay()) to match state (what the UI reads, unchanged on failure since it's only assigned on the successful write). Previously activate/deactivate/updateBoost mutated _controller.mode BEFORE calling _persist, so a failed write left it diverged from both the UI and disk.

AC#2 (MedicationMode + MealLibrary, same semantics): unlike illness mode these don't have a separate controller -- dosing math and the UI both already read the same  field, so the only gap was state silently drifting from disk within the same session. Both notifiers' mutating methods now capture  before mutating, and _persist(previous) reverts state to it on a failed write.

AC#3: added 4 new tests in test/persisted_state_corruption_test.dart (IllnessMode activate + deactivate failure, MedicationMode start failure, MealLibrary add failure). Fault injection needed 2 attempts -- a CLOSED in-memory AppDatabase does NOT throw on write (drift/sqlite3 silently accepts it), discovered via a throwaway probe test; switched to pointing KvStore at a database file with a 300-character filename, which reliably fails to open on both Windows/NTFS and Linux/ext4's ~255-byte filename limits (portable for CI).

Rigor check: temporarily removed each of the 4 revert lines -- all 4 corresponding tests correctly failed. Reverted; git diff clean.

Verified: flutter analyze clean, flutter test --coverage green (1175 tests, 67.77% >= 65% floor, up from 67.58%), flutter build apk --debug succeeds. No native Kotlin, no user-guide update (internal state-consistency fix, no new user-visible surface).
---

author: Claude
created: 2026-07-08 05:13
---
Correction to comment #2: two backtick-quoted spans were eaten by bash. AC#2 in full: unlike illness mode these dont have a separate controller -- dosing math and the UI both already read the same "state" field, so the only gap was state silently drifting from disk within the same session. Both notifiers mutating methods now capture "previous = state" before mutating, and _persist(previous) reverts state to it on a failed write.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
