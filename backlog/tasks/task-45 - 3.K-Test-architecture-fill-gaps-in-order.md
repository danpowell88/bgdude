---
id: TASK-45
title: 3.K Test architecture (fill gaps in order)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:27'
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
Keep the flat test/ layout. Fill gaps in order: data-layer tests (§3.H) → alert decision-core tests (§3.C-1) → provider-module tests (post-§3.A) → architecture_test.dart (§3.G) → widget tests only for the 3–4 screens with real widget-layer logic (bolus sheet, quick-log); the pumpDemoApp harness covers the rest.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §3.K
Effort: ongoing
Roadmap status: open
<!-- SECTION:NOTES:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Data-layer tests landed (§3.H)
- [ ] #2 Alert decision-core tests landed (§3.C step 1)
- [ ] #3 Provider-module tests added after §3.A
- [ ] #4 architecture_test.dart landed (§3.G)
- [ ] #5 Widget tests only for bolus sheet + quick-log; pumpDemoApp covers the rest
<!-- AC:END -->
