---
id: TASK-14
title: P1-7 Alerts survive engine death (staged; see §3.C)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
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
Alert evaluation is bound to the widget tree; engine death kills alerts. Staged: pure decision core → native urgent-low backstop → headless Dart evaluation. See §3.C.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pure alert decision core (no Riverpod/clock/notifications)
- [ ] #2 Native urgent-low backstop
- [ ] #3 Headless Dart evaluation (after §3.H single-connection fix)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P1-7 / §3.C
Effort: L
Where: app.dart, native
Depends on: §3.H (single DB connection) for step 3
Flags: 🔒 safety
Roadmap status: open
<!-- SECTION:NOTES:END -->
