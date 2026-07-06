---
id: TASK-108
title: Shared test fixture library under test/support/
status: To Do
assignee: []
created_date: '2026-07-06 04:54'
labels:
  - code-health
  - testing
dependencies: []
priority: medium
ordinal: 108000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The flat `test/` tree (67 files) has no shared fixture module; 21 files hand-roll their own CGM traces and therapy settings (76 occurrences found). Examples:

- `test/care_detectors_test.dart:22-60` defines `_rampThenFlat(...)` and `_linear(...)`
- `test/ketone_risk_test.dart:5-8` defines `_sustainedHigh(...)`
- the same ISF 50 / CR 10 / target 100 `TherapySettings` is rebuilt privately in care_detectors, autotune, residual_gbm, confirmation_inbox, nightscout and metrics tests

**Reason for change.** Each builder subtly differs (cadence, warmup flags) so tests cannot be compared; a change to the CgmSample shape means editing 21 files; and the boilerplate cost discourages new tests.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 test/support/samples.dart exposes shared builders: ramp, linear, flatTrace, sustained, sampleEvery5min
- [ ] #2 A canonical testTherapySettings() fixture exists with documented defaults
- [ ] #3 Existing tests migrated to the shared builders; private duplicates deleted; suite still green with unchanged assertions
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Design the builder signatures from the union of what the 21 files need (start time, cadence, warmup flag).
- Add test/support/samples.dart + therapy fixture.
- Migrate file-by-file, keeping assertions untouched.
- `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: code-health survey 2026-07-06 (test finding 1)
- Effort: M
- Where: test/ (21 files)
<!-- SECTION:NOTES:END -->
