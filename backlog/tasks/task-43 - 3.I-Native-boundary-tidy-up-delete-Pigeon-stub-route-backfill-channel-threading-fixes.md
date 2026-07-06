---
id: TASK-43
title: >-
  3.I Native boundary tidy-up (delete Pigeon stub, route backfill channel,
  threading fixes)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §3
  - native
  - architecture
  - "\U0001F50C hardware"
dependencies: []
priority: medium
ordinal: 43000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Delete the Pigeon stub PumpHostApiImpl.kt and "until Pigeon is generated" comments (two channels + stable JSON don't justify it). Route history_backfill.dart private MethodChannel through PumpClient so the channel name lives once and the simulator can intercept. Threading fixes (P1-4 main-looper sink, MutableSnapshot copy-under-lock, requestStatusJson returning the previous snapshot) slot into the first PR touching PumpBridge.kt before real-pump testing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pigeon stub + comments removed
- [ ] #2 Backfill channel routed through PumpClient
- [ ] #3 MutableSnapshot copied under lock; requestStatusJson returns current snapshot
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §3.I
Effort: S–M
Depends on: P1-4
Flags: 🔌 hardware
Roadmap status: open
<!-- SECTION:NOTES:END -->
