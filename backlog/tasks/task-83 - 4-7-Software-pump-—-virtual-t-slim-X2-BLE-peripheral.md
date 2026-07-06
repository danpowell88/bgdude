---
id: TASK-83
title: '4-7 Software pump — virtual t:slim X2 BLE peripheral'
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:47'
labels:
  - roadmap
  - §4-7
  - pump
  - testing
  - native
  - "\U0001F50C hardware"
  - needs-exploration
dependencies: []
priority: medium
ordinal: 83000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Testing bgdude against a real pump means having the spare pump on hand, in pairing mode, at the right moment — slow and fragile. A "software pump" is a second phone app that pretends to be a t:slim X2: it advertises the same Bluetooth service, runs the same pairing handshake, and answers the same read requests with realistic data. The July 2026 exploration captured the exact message formats needed to build it convincingly.

**Reason for change.** This is the biggest testing unlock for the whole device effort: pairing, reconnection, decoding and alerts all become reproducible on the desk instead of gated on the physical pump. It also lets you script scenarios (a low, a rapid rise, an alarm, a site change) to drive bgdude end-to-end. It must never expose the pump's insulin-control channels — read-serving only.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 GATT server advertises pumpx2 service + fff6–fff9 (never CONTROL)
- [ ] #2 Framing + chunking + CRC16 match a real pump byte-for-byte
- [ ] #3 JPAKE server pairs a real consumer with a 6-digit code
- [ ] #4 Reads answered from SimulatedDay + §4-5 captures
- [ ] #5 Scenario control-panel UI
- [ ] #6 Shipped as a separate module/app id
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Android/Kotlin, separate module/app id. TRANSPORT: BluetoothGattServer + advertiser for service 0000fdfb-… exposing fff6 CURRENT_STATUS (write+notify), fff7 QUALIFYING_EVENTS, fff8 HISTORY_LOG, fff9 AUTHORIZATION; NEVER expose fffc/fffd CONTROL. FRAMING: pump side of [opcode][txId][len][cargo][CRC16] chunked into ≤18-byte packets with [packetsRemaining][txId][chunk]; reassemble requests, emit chunked responses+CRC16. PAIRING: JPAKE server side (Jpake1a/1b/2/3/4) — port the maths from pumpx2 JpakeAuthBuilder (client) to a server counterpart and cross-check against the captured handshake bytes; plus legacy 16-char; form the LE Secure Connections bond. ENCODING: reuse pumpx2 response classes to serialize cargo seeded from dev/sim_data.dart SimulatedDay; hand-encode reads pumpx2 only models as responses (HomeScreenMirror, PumpFeatures, PumpSettings, PumpGlobals…) from the §4-5 captures. STREAMS: qualifying events on state change + synthetic HistoryLogStream backfill. UI: scenario picker, live nudges, fire alarm, toggle Control-IQ, request log.

**Testing.** Prototype and unit-test the JPAKE server handshake FIRST against the captured client bytes. Then two-phone integration: bgdude pairs with the software pump (6-digit code) and the Protocol Explorer sweep decodes every read. Assert CONTROL characteristics are never exposed. `cd android && ./gradlew :app:testDebugUnitTest` green; verify pumpx2 APIs via `javap` on the cached jar before writing native code.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §4-7
- Effort: L
- Depends on: 2-5 (JPAKE+framing known), §4-6.2 (BLE inspector); needs TWO phones (BLE cannot loopback)
- Flags: 🔌 hardware
- ⚠ NEEDS MORE EXPLORATION: The JPAKE SERVER side is the hard, unproven part — port the maths from pumpx2 JpakeAuthBuilder (client) to a server counterpart and cross-check against the captured handshake bytes. Prototype the pairing handshake before committing to the full peripheral. Desktop variant blocked until a BLE-peripheral stack the pump/consumer accepts is found (bleak/WinRT could not bond — see doc/pump-recon-findings.md).
<!-- SECTION:NOTES:END -->
