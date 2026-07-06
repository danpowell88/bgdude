---
id: TASK-22
title: P2-6 Dead constant sensitivity feature removed
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 05:24'
labels:
  - roadmap
  - §1-P2
  - ml
dependencies: []
priority: low
ordinal: 22000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The forecast model is fed a list of input "features". One of them was a constant that never changed, so it carried no information.

**Reason for change.** DONE (July 2026): the dead feature was removed (feature set v4) — it was just noise/weight in the model.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Remove the dead constant sensitivity feature from the forecast feature set.
- Bump the feature version to v4 so stale models are discarded.
- Covered by the feature-version tests; ML-honesty tests first (coverage + bias, synthetic-data recovery).
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §1 P2-6
- Effort: S
- Roadmap status: done ✅
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Dropped the dead constant-1.0 sensitivity feature (both trainer and server always passed neutral) and bumped the feature version to 4 so stale models discard (commit d3eceda). Verified by feature-version tests, `flutter analyze` clean and `flutter test` green.
<!-- SECTION:FINAL_SUMMARY:END -->
