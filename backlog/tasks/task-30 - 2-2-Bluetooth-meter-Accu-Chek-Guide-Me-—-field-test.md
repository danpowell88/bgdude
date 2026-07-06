---
id: TASK-30
title: 2-2 Bluetooth meter (Accu-Chek Guide Me) — field test
status: In Progress
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:44'
labels:
  - roadmap
  - §2
  - phase-4
  - meter
  - "\U0001F50C hardware"
dependencies: []
priority: medium
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude can import finger-prick readings from a Bluetooth blood-glucose meter (the Accu-Chek Guide Me). The decoder, sync protocol and pairing screen are built and unit-tested, but none of it has been tried against the physical meter.

**Reason for change.** Real Bluetooth pairing and re-connection is exactly where meter integrations tend to break, and imported finger-pricks must merge with the CGM data without corrupting it (which needs the calibration-flag work, P1-2).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pairing + sync field-tested
- [ ] #2 Bonding/re-discovery edges handled
- [ ] #3 Fingerstick↔CGM dedupe/merge
- [ ] #4 Background sync
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Field-test pairing + sync; handle bonding/re-discovery edge cases; dedupe/merge fingersticks with CGM (depends on P1-2 schema); add background sync.

**Testing.** On-device: pair, take readings, sync, re-sync (no duplicates via sequence numbers); verify a fingerstick never overwrites a sensor row. On-device (🔌): prepare a build + an exact manual test procedure → run on the real device → report → fix. Desk tests still green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §2 item 2-2
Effort: M
Depends on: P1-2
Flags: 🔌 hardware
Roadmap status: partial
<!-- SECTION:NOTES:END -->
