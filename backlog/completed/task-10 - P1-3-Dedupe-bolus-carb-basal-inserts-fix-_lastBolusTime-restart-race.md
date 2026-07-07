---
id: TASK-10
title: Dedupe bolus/carb/basal inserts; fix _lastBolusTime restart race
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 15:20'
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
- [x] #1 Bolus/carb/basal inserts deduped (unique key or event-id upsert)
- [x] #2 _lastBolusTime restart race fixed
- [x] #3 ingestSnapshot restart/dedupe test
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

Implemented. AC#1: bolus/carb/basal tables get unique keys ({time,units} / {time,grams} / {start}); saves upsert via DoUpdate targeting those columns (the default insertOnConflictUpdate target is the PK id, which throws on the real unique constraint — verified). schemaVersion 3→4 migration deletes existing dups (keep min(id)) then creates unique indexes; a fresh v4 db gets the table-level constraint. InMemory repo mirrors the dedup. AC#2: ingestSnapshot seeds _lastBolusTime from persisted history when null, so a snapshot reporting the pump's already-saved last bolus after a restart isn't re-inserted (the upsert is the backstop). AC#3: test/bolus_dedup_test.dart — double-save dedup for all three types, a re-observed basal segment updates not duplicates, restart ingest adds no dup, and a genuinely-new bolus is still saved. The v2→v4 migration test (cgm_calibration_test) extended to create the three tables. build_runner regen, analyze clean, 541 tests green, APK builds.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:26
---
detail-needed (2026-07-06, goal triage): Dedupe needs a schema change (unique key / event-id) + the §3.H migration infra; want the dedupe-key design confirmed to avoid a data-losing migration.
---
<!-- COMMENTS:END -->
