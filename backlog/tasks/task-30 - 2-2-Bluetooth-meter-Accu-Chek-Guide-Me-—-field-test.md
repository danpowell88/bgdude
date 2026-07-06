---
id: TASK-30
title: Bluetooth meter (Accu-Chek Guide Me) — field test
status: In Progress
assignee:
  - Claude
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 12:58'
labels:
  - roadmap
  - meter
  - "\U0001F50C hardware"
milestone: m-4
dependencies:
  - TASK-9
priority: medium
ordinal: 500200
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
- Field-test pairing + sync against the physical meter.
- Handle bonding/re-discovery edge cases.
- Dedupe/merge fingersticks with CGM (depends on P1-2 schema).
- Add background sync.
- On-device test: pair, take readings, sync, re-sync (no duplicates via sequence numbers); verify a fingerstick never overwrites a sensor row.
- On-device (hardware): prepare a build + an exact manual test procedure → run on the real device → report → fix.
- Verify: desk tests still green — `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 2 item 2-2
- Effort: M
- Depends on: TASK-9 (P1-2)
- Flags: 🔌 hardware
- Roadmap status: partial
<!-- SECTION:NOTES:END -->
