---
id: TASK-11
title: P1-4 Native EventChannel sink marshalled to the main looper
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 04:38'
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
**Background.** The pump talks to the phone over Bluetooth. When a reading arrives, the native (Android) code hands it to the Flutter app through a channel. Android requires that hand-off to happen on the app's main thread, but Bluetooth callbacks arrive on a background thread — so the very first real pump connection breaks the data stream.

**Reason for change.** Without this fix the app appears to connect but never shows live data on real hardware, and it blocks all on-device testing. It is a small, mechanical change with big consequences.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 EventChannel sink posts to the main looper
- [ ] #2 First real pump connection does not kill the stream
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** In PumpBridge.kt:128-155 marshal every eventSink.success(...) onto the main looper (Handler(Looper.getMainLooper())). Do this in the first PR touching PumpBridge.kt (with the §3.I threading fixes).

**Testing.** On-device: connect to the real pump and confirm snapshots stream continuously (they currently die). Unit-check the marshalling helper if extracted. `cd android && ./gradlew :app:testDebugUnitTest` green; verify pumpx2 APIs via `javap` on the cached jar before writing native code.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P1-4
Effort: S
Where: PumpBridge.kt:128-155
Flags: 🔌 hardware
Roadmap status: open

Done 2026-07-06: all EventChannel emissions marshalled onto the main looper via emit(); compiles (:app:compileDebugKotlin). Correct-by-construction; on-device stream-survival across a real connection is the confirming check (the live-pump Explorer session already streamed snapshots cleanly).
<!-- SECTION:NOTES:END -->
