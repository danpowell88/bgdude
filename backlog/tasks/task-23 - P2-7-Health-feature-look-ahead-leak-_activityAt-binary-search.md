---
id: TASK-23
title: P2-7 Health-feature look-ahead leak + _activityAt binary search
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:27'
labels:
  - roadmap
  - §1-P2
  - ml
  - data-integrity
dependencies: []
priority: medium
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two fixes in health_features.dart / HealthFeatureSampler: (1) the resting-HR baseline currently peeks at future samples — use a TRAILING baseline only (this is P2-7's look-ahead leak); (2) replace the linear _activityAt scan with a binary search over the sorted sample list.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P2-7
Effort: S–M
Roadmap status: open
<!-- SECTION:NOTES:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Resting-HR baseline uses trailing samples only (no look-ahead)
- [ ] #2 _activityAt uses binary search over sorted samples
- [ ] #3 Feature values unchanged except for the removed leak
- [ ] #4 Test asserts no future sample influences a feature
<!-- AC:END -->
