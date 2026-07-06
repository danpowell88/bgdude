---
id: TASK-11
title: P1-4 Native EventChannel sink marshalled to the main looper
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
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
BLE callbacks arrive off-thread; the first real connection kills the event stream. Marshal the EventChannel sink to the main looper. Crashes on first real connection otherwise.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 EventChannel sink posts to the main looper
- [ ] #2 First real pump connection does not kill the stream
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P1-4
Effort: S
Where: PumpBridge.kt:128-155
Flags: 🔌 hardware
Roadmap status: open
<!-- SECTION:NOTES:END -->
