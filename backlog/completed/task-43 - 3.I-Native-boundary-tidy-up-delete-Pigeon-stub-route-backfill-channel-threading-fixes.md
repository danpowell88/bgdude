---
id: TASK-43
title: >-
  Native boundary tidy-up (delete Pigeon stub, route backfill channel, threading
  fixes)
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 14:59'
labels:
  - roadmap
  - native
  - architecture
  - "\U0001F50C hardware"
  - detail-needed
milestone: m-6
dependencies: []
priority: medium
ordinal: 104400
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The bridge between the app and the native pump code carries some leftover scaffolding (an unused code-generation stub), a duplicate private channel for history backfill, and a few threading bugs that can corrupt data on real hardware.

**Reason for change.** Tidying the native boundary removes confusion, lets the simulator intercept history backfill, and fixes snapshot corruption before real-pump testing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Pigeon stub + comments removed
- [x] #2 Backfill channel routed through PumpClient
- [x] #3 MutableSnapshot copied under lock; requestStatusJson returns current snapshot
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Delete `PumpHostApiImpl.kt` + the "until Pigeon is generated" comments.
- Route `history_backfill.dart` MethodChannel through `PumpClient`.
- Apply threading fixes (P1-4 main-looper sink, `MutableSnapshot` copy-under-lock, `requestStatusJson` returning the previous snapshot) in the first PR touching `PumpBridge.kt`.
- Verify pumpx2 APIs via `javap` on the cached jar before writing native code.
- Test: `cd android && ./gradlew :app:testDebugUnitTest` green; on-device confirm snapshots are consistent under load and the simulator can intercept backfill.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 3.I
- Effort: S–M
- Depends on: P1-4
- Flags: 🔌 hardware
- Roadmap status: open

Implemented all three. AC#1: removed the stale Pigeon comments in pump_client.dart and the dead lib/pump/pigeon/pump_api.g.dart exclude from analysis_options.yaml (the file never existed). AC#2: fetchHistory is now on the PumpSource interface (PumpClient real impl + SimulatedPumpClient returns [] since the sim seeds history directly); HistoryBackfillService takes a PumpSource and calls source.fetchHistory instead of its own MethodChannel, so the simulator can intercept the backfill. Provider + the routing test updated (test passes a PumpClient bound to the mocked channel). AC#3: MutableSnapshot is now guarded by a snapshotLock — the four BLE-thread write sites (PumpResponseMapper.apply, discovery pumpName/mac, onPumpModel, onJpakeProgress) and a new handler.snapshotJson() read are synchronized, so requestStatusJson (platform thread) hands out a consistent snapshot instead of racing a concurrent write. Deadlock-free: only field writes / toJson run inside the lock, no callbacks or I/O. flutter analyze clean, 532 tests green, gradlew :app:testDebugUnitTest green, debug APK builds.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:24
---
detail-needed (2026-07-06, goal triage): The threading fixes (snapshot copy-under-lock, requestStatusJson) must be verified under a real pump connection; Pigeon-stub removal is safe but should ride the same real-pump PR.
---
<!-- COMMENTS:END -->
