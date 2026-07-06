---
id: TASK-9
title: >-
  P1-2 CGM calibration flag + source (schema v3); stop fingersticks overwriting
  sensor rows
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §1-P1
  - phase-2
  - data-integrity
dependencies: []
priority: high
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add isCalibration/source to CGM rows (schema v3). Fingerstick meter readings are currently indistinguishable from sensor rows and can overwrite them. Exclude calibrations from metrics/training.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 CGM rows carry isCalibration + source
- [ ] #2 Fingersticks never overwrite sensor rows
- [ ] #3 Calibrations excluded from metrics & training
- [ ] #4 Drift schema-export + migration test precedes v3
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P1-2 (headline issue #3)
Effort: M
Where: database.dart, history_repository.dart, glucose_meter.dart
Roadmap status: open
<!-- SECTION:NOTES:END -->
