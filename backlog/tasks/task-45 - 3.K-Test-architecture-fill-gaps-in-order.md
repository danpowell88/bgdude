---
id: TASK-45
title: 3.K Test architecture (fill gaps in order)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:44'
labels:
  - roadmap
  - §3
  - testing
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
- [ ] #1 Data-layer tests landed (§3.H)
- [ ] #2 Alert decision-core tests landed (§3.C step 1)
- [ ] #3 Provider-module tests added after §3.A
- [ ] #4 architecture_test.dart landed (§3.G)
- [ ] #5 Widget tests only for bolus sheet + quick-log; pumpDemoApp covers the rest
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Order: data-layer tests (§3.H) → alert decision-core tests (§3.C step 1) → provider-module tests (post-§3.A) → architecture_test.dart (§3.G) → widget tests only for bolus sheet + quick-log. The pumpDemoApp integration harness covers the rest.

**Testing.** This IS the testing task — each listed suite lands green; keep the flat test/ layout. Add/extend unit tests under `test/`. `flutter analyze` clean, `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §3.K
- Effort: ongoing
- Roadmap status: open
<!-- SECTION:NOTES:END -->
