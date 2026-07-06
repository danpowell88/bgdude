---
id: TASK-83
title: '4-7 Software pump — virtual t:slim X2 BLE peripheral'
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:11'
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
A second app (or build flavour/hidden mode) that ACTS as the pump: stands up a BLE GATT server, advertises the pumpx2 service, runs the pairing handshake, and answers currentStatus reads with realistic cargo — so bgdude/Explorer can pair and read over real Bluetooth without hardware. Shape (Android/Kotlin): TRANSPORT — BluetoothGattServer + advertiser for service 0000fdfb-… with fff6 CURRENT_STATUS (write+notify), fff7 QUALIFYING_EVENTS, fff8 HISTORY_LOG, fff9 AUTHORIZATION; NEVER expose fffc/fffd CONTROL. FRAMING — pump side of [opcode][txId][len][cargo][CRC16] chunked into ≤18-byte packets with [packetsRemaining][txId][chunk]; reassemble requests, emit chunked responses+CRC16. PAIRING — JPAKE server side (Jpake1a/1b/2/3/4) + legacy 16-char; form the LE Secure Connections bond. MESSAGE ENCODING — reuse pumpx2 response classes to serialize cargo, seeded from dev/sim_data.dart SimulatedDay; hand-encode reads pumpx2 only models as responses (HomeScreenMirror, PumpFeatures, PumpSettings, PumpGlobals…) from the §4-5 captures. STREAMS — qualifying events on state change + synthetic HistoryLogStream backfill. UI — scenario picker, live nudges (glucose/IOB/battery), fire alarm, toggle Control-IQ, request log. Ship in a separate module/app id so it never rides in a consumer release.
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §4-7
Effort: L
Depends on: 2-5 (JPAKE+framing known), §4-6.2 (BLE inspector); needs TWO phones (BLE cannot loopback)
Flags: 🔌 hardware
⚠ NEEDS MORE EXPLORATION: The JPAKE SERVER side is the hard, unproven part — port the maths from pumpx2 JpakeAuthBuilder (client) to a server counterpart and cross-check against the captured handshake bytes. Prototype the pairing handshake before committing to the full peripheral. Desktop variant blocked until a BLE-peripheral stack the pump/consumer accepts is found (bleak/WinRT could not bond — see doc/pump-recon-findings.md).
<!-- SECTION:NOTES:END -->
