---
id: TASK-45
title: Test architecture (fill gaps in order)
status: To Do
assignee:
  - Claude
created_date: '2026-07-06 03:10'
updated_date: '2026-07-07 14:35'
labels:
  - roadmap
  - testing
  - detail-needed
milestone: m-6
dependencies: []
priority: low
ordinal: 109500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The test suite has gaps: no direct tests for the data layer, none for the alert decision logic, thin coverage of app state, and no automated layering guard.

**Reason for change.** Filling those gaps in the right order (data → alerts → state → guard) gives the most safety per unit of effort and unblocks the bigger refactors. This is a tracking task for that sequence.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Data-layer tests landed (TASK-42)
- [x] #2 Alert decision-core tests landed (TASK-37 step 1)
- [ ] #3 Provider-module tests added after TASK-35
- [x] #4 architecture_test.dart landed (TASK-41)
- [x] #5 Widget tests only for bolus sheet + quick-log; pumpDemoApp covers the rest
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Land data-layer tests (TASK-42).
- Land alert decision-core tests (TASK-37 step 1).
- Add provider-module tests (post-TASK-35).
- Land `architecture_test.dart` (TASK-41).
- Add widget tests only for bolus sheet + quick-log; the `pumpDemoApp` integration harness covers the rest.
- This IS the testing task — each listed suite lands green; keep the flat `test/` layout.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 3.K
- Effort: ongoing
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:25
---
detail-needed (2026-07-06, goal triage): Tracking task: it completes as its constituent test suites (§3.H/§3.C/§3.A/§3.G) land — depends on those.
---

author: Claude
created: 2026-07-07 14:35
---
Re-checked this tracking task's ACs against current state rather than assuming stale: AC#1 (data-layer tests) landed via TASK-42 (repo tests on in-memory drift DB, migration tests, batched reconciliation — 3/4 of TASK-42's own ACs; the remaining one, single cross-isolate DB connection, is an architecture item not a testing gap). AC#2 (alert decision-core tests) landed via TASK-37 (test/alert_monitor_test.dart matrix tests). AC#4 (architecture_test.dart) landed this session (TASK-41). AC#5 (widget tests for bolus sheet + quick-log) already existed and still pass: integration_test/app_test.dart has 'bolus advisor computes a suggestion from simulated glucose', integration_test/features_flows_test.dart has 'quick-log alcohol closes the sheet'. AC#3 (provider-module tests after TASK-35) remains genuinely blocked — TASK-35 (the providers.dart split) is itself unstarted, flagged detail-needed pending a scope/sequencing sign-off on that invasive refactor. Leaving open on AC#3 alone.
---
<!-- COMMENTS:END -->
