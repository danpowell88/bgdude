---
id: TASK-10
title: P1-3 Dedupe bolus/carb/basal inserts; fix _lastBolusTime restart race
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
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
No dedupe on bolus/carb/basal inserts inflates IOB/TDD used for advice. Add a unique key or event-id + upsert; fix the _lastBolusTime restart race.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Bolus/carb/basal inserts deduped (unique key or event-id upsert)
- [ ] #2 _lastBolusTime restart race fixed
- [ ] #3 ingestSnapshot restart/dedupe test
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P1-3 (headline issue #3)
Effort: M
Where: database.dart, day_history_controller.dart, history_backfill.dart
Roadmap status: open
<!-- SECTION:NOTES:END -->
