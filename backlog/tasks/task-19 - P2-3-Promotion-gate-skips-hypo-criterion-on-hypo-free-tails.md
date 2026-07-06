---
id: TASK-19
title: P2-3 Promotion gate skips hypo criterion on hypo-free tails
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:43'
labels:
  - roadmap
  - §1-P2
  - ml
dependencies: []
priority: low
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** When bgdude decides whether to adopt a newly-trained forecast model, one of its checks rewards better detection of lows. Previously that check applied even on test windows that happened to contain no lows at all, so a perfectly good model could be blocked for failing an impossible test.

**Reason for change.** DONE (July 2026): the check now skips the low-detection criterion when the test window has no lows to detect.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Implemented in the forecaster promotion gate.

**Testing.** Covered by forecaster-service promotion tests. ML-honesty tests first (coverage + bias, synthetic-data recovery); `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §1 P2-3
- Effort: S
- Roadmap status: done ✅
<!-- SECTION:NOTES:END -->
