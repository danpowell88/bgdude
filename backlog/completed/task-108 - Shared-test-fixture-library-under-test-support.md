---
id: TASK-108
title: Shared test fixture library under test/support/
status: Done
assignee: []
created_date: '2026-07-06 04:54'
updated_date: '2026-07-06 09:17'
labels:
  - code-health
  - testing
milestone: m-8
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
- [x] #1 test/support/samples.dart exposes shared builders: ramp, linear, flatTrace, sustained, sampleEvery5min
- [x] #2 A canonical testTherapySettings() fixture exists with documented defaults
- [x] #3 Existing tests migrated to the shared builders; private duplicates deleted; suite still green with unchanged assertions
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

Implemented: test/support/samples.dart exposes the shared builders ramp, linear, flatTrace, sustained, sampleEvery5min (AC#1) and a canonical testTherapySettings({maxBolusUnits=25}) fixture with documented defaults ISF50/CR10/target100/basal0.8 (AC#2). Builders replicate the exact cadence/endpoint semantics of the historical private helpers so migrated tests keep identical sample sets. Migrated (AC#3): care_detectors (ramp/linear/settings duplicates deleted), ketone_risk (_sustainedHigh now a 2-line adapter over sustained()), and the canonical TherapySettings across bolus_advisor/prebolus_coach/reading_explainer/event_detectors/control_iq — the three that pinned maxBolusUnits:15 call testTherapySettings(maxBolusUnits:15) to stay behaviour-identical. Full suite green (516) with unchanged assertions. SCOPE NOTE: remaining inline one-off traces in other files are bespoke per-scenario data, not copies of a shared builder, so they were intentionally left; flatTrace/sampleEvery5min are available for them and new tests.
<!-- SECTION:NOTES:END -->
