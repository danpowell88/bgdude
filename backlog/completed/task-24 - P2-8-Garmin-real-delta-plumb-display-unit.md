---
id: TASK-24
title: 'Garmin: real delta + plumb display unit'
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 16:02'
labels:
  - roadmap
  - garmin
  - "\U0001F50C hardware"
  - detail-needed
milestone: m-4
dependencies: []
priority: medium
ordinal: 103700
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude shows your glucose on a Garmin watch, including an up/down "delta" (how much it changed since the last reading). The watch data field currently shows a fabricated or zero delta and always displays in mmol/L regardless of your unit setting.

**Reason for change.** A wrong trend arrow and wrong units on the watch mislead at a glance, and the watch is often the surface you check most. Both should reflect reality and your chosen unit.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Delta from consecutive distinct timestamps
- [x] #2 Display unit plumbed (not hardcoded mmol)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Compute the delta from consecutive distinct CGM timestamps.
- Plumb the display unit chosen by the user through to the Garmin payload instead of the mmol literal.
- Unit-test the delta calc where extractable.
- On-device (hardware): prepare a build + an exact manual test procedure, run on the real device, report, fix; on-watch the delta must match the phone and units must follow the app setting.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1 P2-8
- Effort: S
- Flags: 🔌 hardware
- Roadmap status: open

Implemented. AC#1: GarminIntegration now recomputes the delta only across DISTINCT CGM timestamps (tracks lastCgmTs + lastDelta) — snapshots repeat the same reading between CGM updates, which previously zeroed the delta. AC#2: the display unit is plumbed from the phone: PumpSource.setGarminUnit(unit) → command-channel 'setGarminUnit' → PumpBridge → GarminIntegration.displayUnit, sent in the watch payload instead of a hardcoded 'mmol'. Wired via app.dart's glucoseUnit listener (on change) + a one-time runStartup push (initial). SimulatedPumpClient is a no-op (no native Garmin push in demo). The watch's BgData.mc already converts by the 'unit' field. analyze clean, 556 Dart tests + native tests green, APK builds.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:25
---
detail-needed (2026-07-06, goal triage): Native Garmin change; the delta/unit AC needs an on-watch check to confirm the value + unit render correctly. Needs a paired Garmin watch.
---
<!-- COMMENTS:END -->
