---
id: TASK-9
title: >-
  CGM calibration flag + source (schema v3); stop fingersticks overwriting
  sensor rows
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 15:11'
labels:
  - roadmap
  - data-integrity
  - detail-needed
milestone: m-2
dependencies:
  - TASK-42
priority: high
ordinal: 102000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Your continuous glucose monitor (CGM) streams sensor readings; a separate Bluetooth finger-prick meter can also add readings. Right now both land in the same list with no marker for which is which, so a finger-prick value can silently overwrite a sensor reading, and calibration finger-pricks leak into the app's statistics and machine-learning training.

**Reason for change.** A finger-prick overwriting a sensor point corrupts the glucose history that dosing advice and learning depend on — a real data-integrity and safety issue. Readings need a source/calibration flag so they stay distinct.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 CGM rows carry isCalibration + source
- [x] #2 Fingersticks never overwrite sensor rows
- [x] #3 Calibrations excluded from metrics & training
- [x] #4 Drift schema-export + migration test precedes v3
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Schema v3: add `isCalibration` + `source` to CGM rows (`database.dart`, `history_repository.dart`).
- Stop fingersticks upserting over sensor rows (`glucose_meter.dart`).
- Exclude calibration rows from metrics/training queries.
- Drift schema-export + step-migration test BEFORE v3 (repository tests on `NativeDatabase.memory()`; add drift schema-export + step-migration tests BEFORE any schema change, TASK-42).
- Repo test that a fingerstick never overwrites a sensor row and that calibrations are excluded from metrics/training.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1, P1-2 (headline issue #3)
- Effort: M
- Where: `database.dart`, `history_repository.dart`, `glucose_meter.dart`
- Roadmap status: open

Implemented. AC#1: CgmReadings gains isCalibration (bool) + source ('sensor'|'meter') columns; CgmSample gains a GlucoseSource enum + source field (isCalibration already existed). AC#2: saveCgm now branches on source — a sensor reading DoUpdates its time slot (stream dedup preserved), a meter/finger-prick reading uses DoNothing so it can never overwrite an existing sensor row on a same-time collision. AC#3: added s.isCalibration to the 7 metrics/training exclusion predicates (metrics.dart x2, autotune, event_detectors x2, forecaster_training, time_of_day_sensitivity), so calibrations never count toward stats or model training. AC#4: schemaVersion 2→3 with an addColumn migration; test/cgm_calibration_test.dart builds a real v2 DB (old schema + user_version=2), opens AppDatabase to run the migration, and asserts the columns are added and existing rows preserved (source defaults 'sensor'), plus the no-overwrite and metrics-exclusion behaviours. build_runner regen, analyze clean, 536 tests green, APK builds.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:25
---
detail-needed (2026-07-06, goal triage): Schema v3 (isCalibration/source). Per the ROADMAP, the drift schema-export + step-migration tests (§3.H / TASK-42) must exist BEFORE this; also a migration design decision. Sequence after §3.H.
---
<!-- COMMENTS:END -->
