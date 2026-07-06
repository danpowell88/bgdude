---
id: TASK-43
title: >-
  3.I Native boundary tidy-up (delete Pigeon stub, route backfill channel,
  threading fixes)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:44'
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
**Background.** The bridge between the app and the native pump code carries some leftover scaffolding (an unused code-generation stub), a duplicate private channel for history backfill, and a few threading bugs that can corrupt data on real hardware.

**Reason for change.** Tidying the native boundary removes confusion, lets the simulator intercept history backfill, and fixes snapshot corruption before real-pump testing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pigeon stub + comments removed
- [ ] #2 Backfill channel routed through PumpClient
- [ ] #3 MutableSnapshot copied under lock; requestStatusJson returns current snapshot
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Delete PumpHostApiImpl.kt + the "until Pigeon is generated" comments. Route history_backfill.dart's MethodChannel through PumpClient. Threading fixes (P1-4 main-looper sink, MutableSnapshot copy-under-lock, requestStatusJson returning the previous snapshot) in the first PR touching PumpBridge.kt.

**Testing.** `./gradlew :app:testDebugUnitTest` green; on-device confirm snapshots are consistent under load; simulator can intercept backfill. `cd android && ./gradlew :app:testDebugUnitTest` green; verify pumpx2 APIs via `javap` on the cached jar before writing native code.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §3.I
- Effort: S–M
- Depends on: P1-4
- Flags: 🔌 hardware
- Roadmap status: open
<!-- SECTION:NOTES:END -->
