---
id: TASK-4
title: P0-4 Advisor/predictor honour configured DIA & insulin peak
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §1-P0
  - phase-0
  - dosing-math
dependencies: []
priority: high
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Care detectors already honour configured DIA/peak; advisor and predictor hardcode 360/75. Read the configured values.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Advisor uses configured DIA & peak
- [ ] #2 Predictor uses configured DIA & peak
- [ ] #3 No hardcoded 360/75 remain in these paths
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P0-4
Effort: S
Where: bolus_advisor.dart:102-103, predictor.dart:177-178
Roadmap status: open
<!-- SECTION:NOTES:END -->
