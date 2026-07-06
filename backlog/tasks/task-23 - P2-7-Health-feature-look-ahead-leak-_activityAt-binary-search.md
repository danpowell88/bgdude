---
id: TASK-23
title: P2-7 Health-feature look-ahead leak + _activityAt binary search
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:43'
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
**Background.** bgdude blends in health data (sleep, heart rate, activity) to sharpen forecasts. Two bugs exist in how it builds those inputs: the "resting heart rate" baseline is computed using future readings the model wouldn't have at prediction time (a "look-ahead leak"), and finding the active workout uses a slow linear scan.

**Reason for change.** A look-ahead leak makes the model look more accurate in testing than it can ever be in real use, which is misleading and unsafe to rely on. It should only use past readings.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Resting-HR baseline uses trailing samples only (no look-ahead)
- [ ] #2 _activityAt uses binary search over sorted samples
- [ ] #3 Feature values unchanged except for the removed leak
- [ ] #4 Test asserts no future sample influences a feature
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** In health_features.dart / HealthFeatureSampler use a TRAILING resting-HR baseline only; replace the _activityAt linear scan with a binary search over the sorted sample list.

**Testing.** Test asserts no future sample influences a feature; feature values otherwise unchanged; binary-search correctness test. ML-honesty tests first (coverage + bias, synthetic-data recovery); `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P2-7
Effort: S–M
Roadmap status: open
<!-- SECTION:NOTES:END -->
