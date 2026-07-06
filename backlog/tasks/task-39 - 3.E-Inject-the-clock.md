---
id: TASK-39
title: 3.E Inject the clock
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §3
  - architecture
dependencies: []
priority: medium
ordinal: 39000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
78 raw DateTime.now() (45 in providers.dart) make time-relative behaviour untestable. Add clockProvider (DateTime Function()), constructor-injected into AppJobs/AlertService/persisted notifiers during §3.A. Keep analytics/ml explicit-DateTime style; do not sweep display-only UI usages.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 clockProvider added
- [ ] #2 Injected into AppJobs/AlertService/persisted notifiers
- [ ] #3 Time-relative behaviour testable
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §3.E
Effort: S–M
Depends on: moves with 3.A
Roadmap status: open
<!-- SECTION:NOTES:END -->
