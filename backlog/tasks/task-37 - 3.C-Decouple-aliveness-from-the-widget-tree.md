---
id: TASK-37
title: 3.C Decouple aliveness from the widget tree
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:44'
labels:
  - roadmap
  - §3
  - phase-3
  - architecture
  - "\U0001F512 safety"
dependencies: []
priority: high
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude decides its alerts (like an urgent low) inside the visible app. If Android kills the app to reclaim memory, that alerting logic dies with it and an alert may simply never fire. (This is the same work as P1-7.)

**Reason for change.** Silently missing an urgent-low because the screen wasn't open is the worst-case failure for a glucose companion. The fix is staged: a small pure "decision core" that's easy to test, then a dumb always-on safety-net in the native pump service, then a full background engine.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pure decision core with matrix tests
- [ ] #2 Native urgent-low backstop
- [ ] #3 Headless Dart evaluation (post-§3.H)
- [ ] #4 Guide documents the limitation until done
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Stage 1: pure evaluate(AlertInputs)→List<AlertDecision> (no Riverpod/clock/notifications). Stage 2: native urgent-low backstop in PumpService (dumb threshold, hysteresis, Flutter-alive heartbeat suppression). Stage 3 (after §3.H single connection): headless Dart evaluation via WorkManager/isolate. Stage 4: document the limitation in the guide until done.

**Testing.** Matrix tests of the pure core (thresholds × trend × quiet hours × dedup); on-device test that killing the Flutter engine still fires an urgent-low via the native backstop. Add/extend unit tests under `test/`. `flutter analyze` clean, `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §3.C (P1-7)
Effort: L
Depends on: §3.H for step 3
Flags: 🔒 safety
Roadmap status: open
<!-- SECTION:NOTES:END -->
