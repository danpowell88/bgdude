---
id: TASK-10
title: Dedupe bolus/carb/basal inserts; fix _lastBolusTime restart race
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 12:57'
labels:
  - roadmap
  - data-integrity
  - detail-needed
milestone: m-2
dependencies:
  - TASK-42
priority: high
ordinal: 102100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Every insulin dose, carb entry and basal change is saved to the database. There is currently no guard against saving the same event twice, so re-reading history (for example after the app restarts) can double-count events; a related timing bug can also mis-handle the "last bolus" on restart.

**Reason for change.** Duplicated events inflate two numbers the advisor relies on — insulin on board and total daily dose — so dosing advice built on double-counted insulin is unsafe. Inserts need to be de-duplicated.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Bolus/carb/basal inserts deduped (unique key or event-id upsert)
- [ ] #2 _lastBolusTime restart race fixed
- [ ] #3 ingestSnapshot restart/dedupe test
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a unique key or event-id + upsert for bolus/carb/basal (`database.dart`, `history_backfill.dart`).
- Fix the `_lastBolusTime` restart race in `day_history_controller.dart`.
- `ingestSnapshot` restart/dedupe test (re-ingest yields no duplicates); repo upsert test on `NativeDatabase.memory()`.
- Repository tests on `NativeDatabase.memory()`; add drift schema-export + step-migration tests BEFORE any schema change (TASK-42).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1, P1-3 (headline issue #3)
- Effort: M
- Where: `database.dart`, `day_history_controller.dart`, `history_backfill.dart`
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:26
---
detail-needed (2026-07-06, goal triage): Dedupe needs a schema change (unique key / event-id) + the §3.H migration infra; want the dedupe-key design confirmed to avoid a data-losing migration.
---
<!-- COMMENTS:END -->
