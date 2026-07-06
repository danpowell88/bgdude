---
id: TASK-14
title: P1-7 Alerts survive engine death (staged; see §3.C)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:43'
labels:
  - roadmap
  - §1-P1
  - phase-3
  - architecture
  - "\U0001F512 safety"
dependencies: []
priority: high
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude's alerts (for example an urgent low) are decided by code that runs inside the visible app. If Android kills the app to save memory, the alerting logic dies with it — so an alert can simply not fire.

**Reason for change.** For a glucose companion, silently missing an urgent-low alert because the screen wasn't open is the worst-case failure. This is the biggest structural safety gap; the fix is staged (a testable core, then a native safety-net, then a background engine).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pure alert decision core (no Riverpod/clock/notifications)
- [ ] #2 Native urgent-low backstop
- [ ] #3 Headless Dart evaluation (after §3.H single-connection fix)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Stage 1: extract a pure evaluate(AlertInputs)→List<AlertDecision> core (no Riverpod/clock/notifications). Stage 2: native urgent-low backstop in PumpService (dumb threshold, hysteresis, Flutter-alive heartbeat suppression). Stage 3 (after §3.H single-connection): headless Dart evaluation. Detailed in TASK-37.

**Testing.** Matrix unit tests of the pure core (threshold × trend × quiet-hours × dedup); native backstop verified on-device by killing the Flutter engine and confirming an urgent-low still alerts. Add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able). `flutter analyze` clean and `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §1 P1-7 / §3.C
- Effort: L
- Where: app.dart, native
- Depends on: §3.H (single DB connection) for step 3
- Flags: 🔒 safety
- Roadmap status: open
<!-- SECTION:NOTES:END -->
