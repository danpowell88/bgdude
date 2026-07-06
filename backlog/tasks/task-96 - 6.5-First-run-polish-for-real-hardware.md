---
id: TASK-96
title: First-run polish for real hardware
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 12:58'
labels:
  - roadmap
  - onboarding
  - "\U0001F50C hardware"
  - detail-needed
milestone: m-7
dependencies: []
priority: low
ordinal: 501100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The very first run on a real phone — pairing the pump, granting Bluetooth/Health permissions, connecting Health Connect, and the "no data yet" screens before data arrives — hasn't been polished.

**Reason for change.** A smooth, guided first run is what makes the app usable by a real person on day one instead of a confusing wall of permission prompts.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pairing UX guided and error-tolerant
- [ ] #2 Permission flows (BT/location/Health Connect) smooth
- [ ] #3 Health Connect setup path
- [ ] #4 "No data yet" states across screens
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Polish pairing UX.
- Polish runtime permission flows (BT/location/notifications).
- Health Connect setup.
- "No data yet" empty states across screens.
- Empty-state widget tests.
- On-device (🔌): prepare a build + an exact manual test procedure → run the first-run walkthrough on a clean install on the real device → report → fix.
- Verify: desk tests still green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 6
- Effort: S–M
- Flags: 🔌 hardware
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:31
---
detail-needed (2026-07-06, goal triage): First-run polish needs an on-device clean-install walkthrough (pairing UX, permission flows, Health Connect) to evaluate and tune.
---
<!-- COMMENTS:END -->
