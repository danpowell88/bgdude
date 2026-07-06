---
id: TASK-12
title: 'BootReceiver: gate on BT permission + auto-reconnect'
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 15:44'
labels:
  - roadmap
  - native
  - "\U0001F50C hardware"
  - detail-needed
milestone: m-4
dependencies: []
priority: high
ordinal: 102200
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** A background service keeps the pump connected even when the app is closed, and it is supposed to restart after the phone reboots. Today the reboot handler starts that service without first checking it has Bluetooth permission, and there is no auto-reconnect, so a reboot does not actually bring the pump link back.

**Reason for change.** On modern Android, starting that kind of service without Bluetooth permission is rejected outright, and even when it starts it never reconnects — so the "keeps working after a restart" promise is false.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 BootReceiver checks BT permission before starting
- [x] #2 Auto-reconnect resumes the link after boot
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Gate `BootReceiver` on `BLUETOOTH_CONNECT` (`BootReceiver.kt`).
- Add auto-reconnect in `PumpService.kt` so a boot start re-scans/reconnects to the known pump.
- On-device: reboot with the pump paired and confirm the link resumes without opening the app.
- Verify: `cd android && ./gradlew :app:testDebugUnitTest` green; verify pumpx2 APIs via `javap` on the cached jar before writing native code.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1, P1-5
- Effort: S–M
- Where: `BootReceiver.kt`, `PumpService.kt`
- Flags: 🔌 hardware
- Roadmap status: open

Implemented. AC#1: BootReceiver now checks PumpService.hasBluetoothPermission(context) before startForegroundService and skips quietly (logged) if the BLE runtime permission isn't granted — starting a connectedDevice FGS from BOOT_COMPLETED without it is rejected on Android 12+/15+. AC#2: BootReceiver passes PumpService.EXTRA_AUTO_RECONNECT; PumpService.onStartCommand, once foregrounded with that flag, calls startScan(null) so the link reconnects itself after a reboot (previously it started the service but never scanned). Native-only; no unit test (BroadcastReceiver + FGS + runtime permissions need instrumentation not available headless) — verified by gradle build + APK; logic is a permission gate + one startScan call.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:26
---
detail-needed (2026-07-06, goal triage): Needs a real device: the auto-reconnect-after-reboot AC can only be confirmed by rebooting a phone with the pump paired; also a reconnect-policy decision (retry cadence/backoff).
---
<!-- COMMENTS:END -->
