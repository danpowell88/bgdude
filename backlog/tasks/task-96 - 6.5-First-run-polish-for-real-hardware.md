---
id: TASK-96
title: 6.5 First-run polish for real hardware
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:47'
labels:
  - roadmap
  - §6
  - onboarding
  - "\U0001F50C hardware"
dependencies: []
priority: low
ordinal: 96000
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
**Technical notes.** Pairing UX, runtime permission flows (BT/location/notifications), Health Connect setup, and "no data yet" empty states across screens.

**Testing.** On-device first-run walkthrough on a clean install; empty-state widget tests. On-device (🔌): prepare a build + an exact manual test procedure → run on the real device → report → fix. Desk tests still green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §6
- Effort: S–M
- Flags: 🔌 hardware
- Roadmap status: open
<!-- SECTION:NOTES:END -->
