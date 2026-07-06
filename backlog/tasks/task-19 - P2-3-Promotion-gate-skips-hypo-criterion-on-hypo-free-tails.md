---
id: TASK-19
title: Promotion gate skips hypo criterion on hypo-free tails
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 08:10'
labels:
  - roadmap
  - ml
milestone: m-5
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
- Implemented in the forecaster promotion gate.
- Covered by forecaster-service promotion tests. ML-honesty tests first (coverage + bias, synthetic-data recovery).
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1, P2-3
- Effort: S
- Roadmap status: done ✅
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The forecaster promotion gate now skips the hypo-detection criterion when the evaluation window contains no lows, so a good model is no longer blocked by an impossible test. Done July 2026 as part of the ML train/promote loop integrity work; covered by forecaster-service promotion tests, `flutter analyze` clean and `flutter test` green.
<!-- SECTION:FINAL_SUMMARY:END -->
