---
id: TASK-14
title: Alerts survive engine death (staged; see TASK-37)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 15:51'
labels:
  - roadmap
  - architecture
  - "\U0001F512 safety"
  - detail-needed
milestone: m-3
dependencies:
  - TASK-42
priority: high
ordinal: 100000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude's alerts (for example an urgent low) are decided by code that runs inside the visible app. If Android kills the app to save memory, the alerting logic dies with it — so an alert can simply not fire.

**Reason for change.** For a glucose companion, silently missing an urgent-low alert because the screen wasn't open is the worst-case failure. This is the biggest structural safety gap; the fix is staged (a testable core, then a native safety-net, then a background engine).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Pure alert decision core (no Riverpod/clock/notifications)
- [x] #2 Native urgent-low backstop
- [ ] #3 Headless Dart evaluation (after TASK-42 single-connection fix)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Stage 1: extract a pure `evaluate(AlertInputs)` → `List<AlertDecision>` core (no Riverpod/clock/notifications).
- Stage 2: native urgent-low backstop in `PumpService` (dumb threshold, hysteresis, Flutter-alive heartbeat suppression).
- Stage 3 (after TASK-42 single-connection): headless Dart evaluation. Detailed in TASK-37.
- Matrix unit tests of the pure core (threshold × trend × quiet-hours × dedup); add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able).
- Native backstop verified on-device by killing the Flutter engine and confirming an urgent-low still alerts.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1, P1-7 / TASK-37 (section 3.C)
- Effort: L
- Where: `app.dart`, native
- Depends on: TASK-37 (staged alert plan); TASK-42 (single DB connection) for stage 3
- Flags: 🔒 safety
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:27
---
detail-needed (2026-07-06, goal triage): L, safety-critical, native + Dart, staged; depends on §3.H single-DB-connection (TASK-42). Want the staging/approach confirmed before building the alert backstop. (= §3.C / TASK-37.)
---

author: Claude
created: 2026-07-06 15:51
---
AC#1 (pure AlertMonitor decision core, no Riverpod/clock/notifications) and AC#2 (native urgent-low backstop in PumpService) are delivered by the shared TASK-37 work — commit cf87219 (test/alert_monitor_test.dart matrix tests + PumpService ≤55 mg/dL backstop). AC#3 (headless Dart evaluation) is the same final stage as TASK-37 AC#4 and is explicitly gated on TASK-42's single-connection/DI fix — blocked until that lands.
---
<!-- COMMENTS:END -->
