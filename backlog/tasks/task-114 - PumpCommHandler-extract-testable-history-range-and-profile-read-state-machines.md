---
id: TASK-114
title: >-
  PumpCommHandler: extract testable history-range and profile-read state
  machines
status: To Do
assignee: []
created_date: '2026-07-06 04:56'
updated_date: '2026-07-06 08:08'
labels:
  - code-health
  - native
  - pump
  - testing
milestone: m-8
dependencies: []
priority: medium
ordinal: 114000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `PumpCommHandler.kt` (378 lines) is a single TandemPump subclass that owns BLE scan/handler lifecycle, the pairing + JPAKE state machine, full-status request fan-out (118-138), the IDP profile-read driver (226-242), the ranged history-backfill logic (244-257) and probe capture. It has no test and cannot get one because it needs a live TandemBluetoothHandler.

**Reason for change.** The two embedded state machines contain pure, off-by-one-prone arithmetic — e.g. the history range start `lastSeq - count + 1` coerced to `firstSeq` (248-249) — that is currently untestable. (PumpService at 177 lines and PumpBridge at 196 are fine; this is the only oversized Kotlin class.)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 History-range computation extracted as a plain object with unit tests incl. boundary cases (count exceeds available, empty log, single entry)
- [ ] #2 Profile-read progression (segment assembly, completion detection) extracted and unit-tested
- [ ] #3 PumpCommHandler reduced to thin BLE glue delegating to the extracted objects; behaviour unchanged
- [ ] #4 gradlew :app:testDebugUnitTest green
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Extract HistoryRangePlanner (inputs firstSeq/lastSeq/count, output ranged requests) and ProfileReadTracker as plain Kotlin classes, no BLE deps.
- Wire PumpCommHandler through them; keep the public surface identical.
- Unit-test the boundary arithmetic; verify pumpx2 types via javap before writing.
- Regression: pair + backfill against the simulator/demo path on the emulator.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: code-health survey 2026-07-06 (test finding 7)
- Effort: M
- Where: android/app/src/main/kotlin/com/bgdude/app/pump/PumpCommHandler.kt
<!-- SECTION:NOTES:END -->
