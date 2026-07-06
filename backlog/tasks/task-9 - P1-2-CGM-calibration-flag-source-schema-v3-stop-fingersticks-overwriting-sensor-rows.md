---
id: TASK-9
title: >-
  P1-2 CGM calibration flag + source (schema v3); stop fingersticks overwriting
  sensor rows
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:43'
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
**Background.** Your continuous glucose monitor (CGM) streams sensor readings; a separate Bluetooth finger-prick meter can also add readings. Right now both land in the same list with no marker for which is which, so a finger-prick value can silently overwrite a sensor reading, and calibration finger-pricks leak into the app's statistics and machine-learning training.

**Reason for change.** A finger-prick overwriting a sensor point corrupts the glucose history that dosing advice and learning depend on — a real data-integrity and safety issue. Readings need a source/calibration flag so they stay distinct.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 CGM rows carry isCalibration + source
- [ ] #2 Fingersticks never overwrite sensor rows
- [ ] #3 Calibrations excluded from metrics & training
- [ ] #4 Drift schema-export + migration test precedes v3
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Schema v3: add isCalibration + source to CGM rows (database.dart, history_repository.dart). Stop fingersticks upserting over sensor rows (glucose_meter.dart). Exclude calibration rows from metrics/training queries.

**Testing.** Drift schema-export + step-migration test BEFORE v3; repo test that a fingerstick never overwrites a sensor row and that calibrations are excluded from metrics/training. Repository tests on `NativeDatabase.memory()`; add drift schema-export + step-migration tests BEFORE any schema change (§3.H).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P1-2 (headline issue #3)
Effort: M
Where: database.dart, history_repository.dart, glucose_meter.dart
Roadmap status: open
<!-- SECTION:NOTES:END -->
