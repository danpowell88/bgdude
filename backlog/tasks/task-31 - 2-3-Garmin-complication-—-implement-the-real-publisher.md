---
id: TASK-31
title: 2-3 Garmin complication — implement the real publisher
status: In Progress
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 05:27'
labels:
  - roadmap
  - §2
  - phase-4
  - garmin
  - "\U0001F50C hardware"
dependencies: []
priority: medium
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** A Garmin "complication" is a small element you can place on a watch face (like the little date or steps readouts). bgdude's Garmin apps run in the simulator, but the complication publisher was mis-built and removed, so BG can't yet appear on the watch face itself.

**Reason for change.** A complication puts your glucose on the watch face you already glance at — the highest-value Garmin surface. It needs the real publisher, gated to watches that support complications.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Resource-defined complication + updateComplication
- [ ] #2 Gated on has :Complications
- [ ] #3 Verified on a real watch
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Implement the real publisher: resource-defined complication + `updateComplication`.
- Gate on `has :Complications`.
- On-watch test: complication shows BG and updates; falls back cleanly on devices lacking `:Complications`.
- On-device (hardware): prepare a build + an exact manual test procedure → run on the real device → report → fix.
- Verify: desk tests still green — `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §2 item 2-3
- Effort: M
- Where: garmin/COMPLICATIONS.md
- Flags: 🔌 hardware
- Roadmap status: partial
<!-- SECTION:NOTES:END -->
