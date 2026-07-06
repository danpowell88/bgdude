---
id: TASK-12
title: 'P1-5 BootReceiver: gate on BT permission + auto-reconnect'
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §1-P1
  - phase-4
  - native
  - "\U0001F50C hardware"
dependencies: []
priority: high
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Gate BootReceiver on BT permission and add auto-reconnect so a boot restart actually resumes the pump link.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 BootReceiver checks BT permission before starting
- [ ] #2 Auto-reconnect resumes the link after boot
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P1-5
Effort: S–M
Where: BootReceiver.kt, PumpService.kt
Flags: 🔌 hardware
Roadmap status: open
<!-- SECTION:NOTES:END -->
