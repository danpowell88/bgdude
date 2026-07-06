---
id: TASK-37
title: Decouple aliveness from the widget tree
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 15:50'
labels:
  - roadmap
  - architecture
  - "\U0001F512 safety"
  - detail-needed
milestone: m-3
dependencies:
  - TASK-42
priority: high
ordinal: 100100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude decides its alerts (like an urgent low) inside the visible app. If Android kills the app to reclaim memory, that alerting logic dies with it and an alert may simply never fire. (This is the same work as P1-7.)

**Reason for change.** Silently missing an urgent-low because the screen wasn't open is the worst-case failure for a glucose companion. The fix is staged: a small pure "decision core" that's easy to test, then a dumb always-on safety-net in the native pump service, then a full background engine.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Pure decision core with matrix tests
- [x] #2 Native urgent-low backstop
- [x] #3 Guide documents the limitation until done
- [ ] #4 Headless Dart evaluation (post-TASK-42 / 3.H)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Stage 1: pure `evaluate(AlertInputs)` → `List<AlertDecision>` (no Riverpod/clock/notifications).
- Stage 2: native urgent-low backstop in `PumpService` (dumb threshold, hysteresis, Flutter-alive heartbeat suppression).
- Stage 3 (after TASK-42 (3.H) single connection): headless Dart evaluation via WorkManager/isolate.
- Stage 4: document the limitation in the guide until done.
- Test: matrix tests of the pure core (thresholds × trend × quiet hours × dedup); on-device test that killing the Flutter engine still fires an urgent-low via the native backstop; add/extend unit tests under `test/`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 3.C (P1-7)
- Effort: L
- Depends on: TASK-42 (3.H) for step 3
- Flags: 🔒 safety
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:29
---
detail-needed (2026-07-06, goal triage): L, safety-critical alert re-architecture across widget/native/isolate; depends on §3.H. Want the staged approach signed off before an invasive change to the alert path.
---

author: Claude
created: 2026-07-06 15:50
---
Stages AC#1-3 landed (commit cf87219): AC#1 pure AlertMonitor decision core + matrix tests (test/alert_monitor_test.dart); AC#2 native urgent-low backstop in PumpService (≤55 mg/dL, own high-importance channel, 15-min cooldown, fires even if the Flutter app is killed); AC#3 user guide documents the limitation + backstop. AC#4 (headless Dart evaluation) is explicitly 'post-TASK-42/3.H' in the ticket — blocked until the data-layer hardening / DI seam from TASK-42 lands, which is what makes a headless isolate able to run the evaluation. Left In Progress with the AC#4 dependency; not Done until TASK-42 unblocks the final stage.
---
<!-- COMMENTS:END -->
