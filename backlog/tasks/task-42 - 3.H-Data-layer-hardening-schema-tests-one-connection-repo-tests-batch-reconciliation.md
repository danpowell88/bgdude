---
id: TASK-42
title: >-
  Data-layer hardening (schema tests, one connection, repo tests, batch
  reconciliation)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 15:55'
labels:
  - roadmap
  - data-integrity
  - testing
  - detail-needed
milestone: m-2
dependencies: []
priority: medium
ordinal: 104300
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude stores glucose, insulin and meal history in a local database. That data layer has no direct tests, opens a second database connection from background work (which can conflict), and reconciles predictions inefficiently (one query per row).

**Reason for change.** Dosing advice reads insulin-on-board and daily totals from this data, so it must be trustworthy. Add migration + repository tests, use a single database connection, and batch the reconciliation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Drift schema-export + migration tests before v3
- [ ] #2 Single DB connection across isolates
- [x] #3 Repository unit tests on in-memory DB
- [x] #4 Batched prediction reconciliation
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add Drift schema-export + step-migration tests (`test/drift/` snapshots) BEFORE schema v3 (P1-2/P1-3).
- Move to one DB connection across isolates (drift `DatabaseConnection.delayed` / isolate port).
- Add repository unit tests on `NativeDatabase.memory()` (upsert/dedupe, reconciliation, KV).
- Batch prediction reconciliation (replace one-query-per-row).
- Test: migration tests across schema versions; repo tests on in-memory DB; assert a single connection; batched-reconciliation correctness + perf.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 3.H
- Effort: M
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:24
---
detail-needed (2026-07-06, goal triage): Data-layer hardening: drift schema-export + step-migration test infra, single cross-isolate DB connection — big and precedes schema v3. Want the migration-test approach confirmed.
---

author: Claude
created: 2026-07-06 15:55
---
Delivered (commit 6f5a62b): AC#4 batched prediction reconciliation (single CGM query + batched updates) with reconcile_predictions_test; AC#3 repository unit tests on an in-memory Drift DB (reconcile_predictions_test, plus cgm_calibration_test + bolus_dedup_test from TASK-9/10); AC#1 migration tests exist and pass (cgm_calibration_test builds a real v2 schema and runs v2→v4; bolus_dedup covers the v4 dedup) — note the schema is now v4 (TASK-9/10), so 'before v3' is moot; the formal drift_dev schema-export/SchemaVerifier tooling isn't set up (hand-written migration tests instead). AC#2 (single DB connection across isolates) is NOT done and needs a design decision: background_summary.dart runs in a WorkManager-spawned isolate that opens its OWN AppDatabase over the same SQLCipher file. drift's DriftIsolate/port sharing doesn't cleanly apply because the OS spawns that isolate independently (no shared ports/memory), and the passphrase adds complexity. Options to decide: (a) a drift DriftIsolate server the WorkManager isolate connects to, (b) route background reads through a single owner, or (c) accept two WAL connections with careful write-isolation. This blocks TASK-37/14 AC#4 (headless evaluation).
---
<!-- COMMENTS:END -->
