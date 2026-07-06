---
id: TASK-45
title: Test architecture (fill gaps in order)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 08:07'
labels:
  - roadmap
  - testing
  - detail-needed
milestone: m-6
dependencies: []
priority: low
ordinal: 45000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The test suite has gaps: no direct tests for the data layer, none for the alert decision logic, thin coverage of app state, and no automated layering guard.

**Reason for change.** Filling those gaps in the right order (data → alerts → state → guard) gives the most safety per unit of effort and unblocks the bigger refactors. This is a tracking task for that sequence.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Data-layer tests landed (TASK-42)
- [ ] #2 Alert decision-core tests landed (TASK-37 step 1)
- [ ] #3 Provider-module tests added after TASK-35
- [ ] #4 architecture_test.dart landed (TASK-41)
- [ ] #5 Widget tests only for bolus sheet + quick-log; pumpDemoApp covers the rest
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
<!-- COMMENTS:END -->
