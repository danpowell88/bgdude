---
id: TASK-33
title: Pump pairing robustness (pumpx2) — reliability pass
status: Blocked
assignee:
  - Claude
created_date: '2026-07-06 03:10'
updated_date: '2026-07-07 22:40'
labels:
  - roadmap
  - pump
  - "\U0001F50C hardware"
  - detail-needed
milestone: m-4
dependencies:
  - TASK-12
priority: high
ordinal: 500000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude connects to the Tandem t:slim X2 pump over Bluetooth to read (never write) data. Pairing was proven end-to-end on a real pump in July 2026 after fixing two bugs in the pairing handshake ("JPAKE", the pump's 6-digit-code exchange). It works, but the connection is still fragile.

**Reason for change.** The pump drops the link if it isn't sitting on its pairing screen at just the right moment, and long-run stability plus the "only one app can pair at a time" rule with Tandem's official app are unproven. Two prerequisite crash fixes (P1-4/P1-5) must land first.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pairing retries + reconnect robust on hardware
- [x] #2 Error surfacing to UI
- [ ] #3 t:connect mutual-exclusion handled
- [ ] #4 Long-run stability verified
- [x] #5 Reconnect/pairing-window loop tightened
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add pairing retries and reconnect after drop.
- Surface errors to the UI.
- Handle t:connect mutual-exclusion.
- Verify long-run stability.
- Tighten the reconnect/pairing-window loop.
- Consider gating the derived-secret reuse path.
- On-device test: repeated pair/unpair, reconnect after sleep/range-loss, multi-hour stability; confirm the read-only guarantee (only `currentStatus` sent) holds throughout.
- On-device (hardware): prepare a build + an exact manual test procedure → run on the real device → report → fix.
- Verify: desk tests still green — `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 2 item 2-5
- Effort: M
- Depends on: TASK-12 (P1-5), P1-4
- Flags: 🔌 hardware
- Roadmap status: partial (JPAKE pairing verified)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 12:58
---
detail-needed (2026-07-07, hardware gate): every remaining AC (#1 pairing retries/reconnect, #2 error surfacing, #3 t:connect mutual-exclusion, #4 long-run stability, #5 reconnect-window tightening) explicitly requires 'on-device (hardware): prepare a build + run on the real device' per the ticket's own plan — none of it is a desk-verifiable software gap. No physical Tandem t:slim X2 pump is available in this environment. Left In Progress (roadmap status already 'partial — JPAKE pairing verified' from a prior real-hardware session) rather than Done, since the actual reliability work hasn't happened yet, or detail-needed-and-abandoned, since it's real, scoped, ready-to-run work waiting on hardware access.
---

author: Claude
created: 2026-07-07 22:22
---
Progress: AC#2 and AC#5 are now genuinely code-complete (previously the whole task was blanket-labeled hardware-blocked, which overstated the blockage -- see the investigation this comment follows from).

AC#5 (reconnect/pairing-window loop tightened): added PairingWindowPolicy (SCAN_TIMEOUT_MS=2min, PAIRING_CODE_TIMEOUT_MS=5min) and wired a Handler(Looper.getMainLooper())-based timeout into PumpCommHandler -- a scan that never discovers a pump, or a pairing-code prompt the user never completes, now gives up and emits ConnectionStage.ERROR with a clear message instead of running forever. Every terminal-state transition (onPumpConnected, onInvalidPairingCode, onPumpCriticalError, submitPairingCode, stopBluetooth) cancels the pending timeout so it can never fire spuriously after success/teardown. New test: android/app/src/test/kotlin/.../PairingWindowTimeoutTest.kt (Robolectric, fake-time via shadowOf(Looper.getMainLooper()).idleFor(...)) -- 3 tests, rigor-checked (reverted the wiring, confirmed 2 of 3 fail with the exact predicted AssertionError, restored, green again).

AC#2 (error surfacing to UI): the existing SnackBar (pairing_dialog.dart) is transient -- a user who dismisses it or isn't looking at the screen when e.g. the new AC#5 timeout fires has no persistent indication anything is wrong. Added a MaterialBanner to pump_screen.dart, independent of the snackbar, driven by pumpConnectionProvider's stage (error/disconnected), with a Retry button wired to the same startScan() the existing re-pair tile uses. New test: test/pump_screen_connection_banner_test.dart -- 5 widget tests (shows for error/disconnected, hidden for healthy stages, clears on recovery, Retry re-invokes startScan), rigor-checked (reverted, confirmed 4 of 5 fail as predicted, restored, green again).

AC#1 (retries + reconnect 'robust on hardware'), AC#3 (t:connect mutual-exclusion) and AC#4 (long-run stability) remain genuinely hardware/empirical -- their underlying mechanisms already exist (pumpx2 auto-reconnect on disconnect, unit-tested via PumpCommHandlerReconnectTest) but the ACs' own wording ('on hardware', 'verified') requires an actual device to confirm. Left unchecked, detail-needed label kept for these three specifically.

Pipeline: pub get, build_runner build, flutter analyze clean, flutter test --coverage test/ (1082/1082 green, coverage 65.8% vs 65.5% floor -- did not drop), flutter build apk --debug succeeded, gradlew :app:testDebugUnitTest green (native Kotlin changed).

Files: android/app/src/main/kotlin/com/bgdude/app/pump/PairingWindowPolicy.kt (new), PumpCommHandler.kt, android/app/src/test/.../PairingWindowTimeoutTest.kt (new), lib/ui/pump_screen.dart, test/pump_screen_connection_banner_test.dart (new).
---

author: Claude
created: 2026-07-07 22:40
---
Blocked: AC#1 ('robust on hardware'), AC#3 (t:connect mutual-exclusion) and AC#4 (long-run stability) require an actual t:slim X2 pump to verify -- no emulator/simulator can exercise real BLE pairing/bonding or multi-hour signal behaviour. AC#2 and AC#5 are done (see prior comment). Unblocked by: a session with the real pump available (per decision-2, hardware is on hand for collaborative device runs).
---
<!-- COMMENTS:END -->
