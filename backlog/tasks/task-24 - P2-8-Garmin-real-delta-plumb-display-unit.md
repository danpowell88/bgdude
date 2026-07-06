---
id: TASK-24
title: 'P2-8 Garmin: real delta + plumb display unit'
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 05:25'
labels:
  - roadmap
  - §1-P2
  - garmin
  - "\U0001F50C hardware"
  - detail-needed
dependencies: []
priority: medium
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude shows your glucose on a Garmin watch, including an up/down "delta" (how much it changed since the last reading). The watch data field currently shows a fabricated or zero delta and always displays in mmol/L regardless of your unit setting.

**Reason for change.** A wrong trend arrow and wrong units on the watch mislead at a glance, and the watch is often the surface you check most. Both should reflect reality and your chosen unit.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Delta from consecutive distinct timestamps
- [ ] #2 Display unit plumbed (not hardcoded mmol)
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
- Source: ROADMAP §1 P2-8
- Effort: S
- Flags: 🔌 hardware
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:25
---
detail-needed (2026-07-06, goal triage): Native Garmin change; the delta/unit AC needs an on-watch check to confirm the value + unit render correctly. Needs a paired Garmin watch.
---
<!-- COMMENTS:END -->
