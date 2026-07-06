---
id: TASK-12
title: 'P1-5 BootReceiver: gate on BT permission + auto-reconnect'
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:43'
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
**Background.** A background service keeps the pump connected even when the app is closed, and it is supposed to restart after the phone reboots. Today the reboot handler starts that service without first checking it has Bluetooth permission, and there is no auto-reconnect, so a reboot does not actually bring the pump link back.

**Reason for change.** On modern Android, starting that kind of service without Bluetooth permission is rejected outright, and even when it starts it never reconnects — so the "keeps working after a restart" promise is false.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 BootReceiver checks BT permission before starting
- [ ] #2 Auto-reconnect resumes the link after boot
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Gate BootReceiver on BLUETOOTH_CONNECT (BootReceiver.kt); add auto-reconnect in PumpService.kt so a boot start re-scans/reconnects to the known pump.

**Testing.** On-device: reboot with the pump paired and confirm the link resumes without opening the app. `cd android && ./gradlew :app:testDebugUnitTest` green; verify pumpx2 APIs via `javap` on the cached jar before writing native code.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P1-5
Effort: S–M
Where: BootReceiver.kt, PumpService.kt
Flags: 🔌 hardware
Roadmap status: open
<!-- SECTION:NOTES:END -->
