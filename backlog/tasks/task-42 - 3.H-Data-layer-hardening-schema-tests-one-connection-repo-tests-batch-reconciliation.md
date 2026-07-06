---
id: TASK-42
title: >-
  3.H Data-layer hardening (schema tests, one connection, repo tests, batch
  reconciliation)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 04:51'
labels:
  - roadmap
  - §3
  - phase-2
  - data-integrity
  - testing
  - detail-needed
dependencies: []
priority: medium
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude stores glucose, insulin and meal history in a local database. That data layer has no direct tests, opens a second database connection from background work (which can conflict), and reconciles predictions inefficiently (one query per row).

**Reason for change.** Dosing advice reads insulin-on-board and daily totals from this data, so it must be trustworthy. Add migration + repository tests, use a single database connection, and batch the reconciliation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Drift schema-export + migration tests before v3
- [ ] #2 Single DB connection across isolates
- [ ] #3 Repository unit tests on in-memory DB
- [ ] #4 Batched prediction reconciliation
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Drift schema-export + step-migration tests (test/drift/ snapshots) BEFORE schema v3 (P1-2/P1-3). One DB connection across isolates (drift DatabaseConnection.delayed / isolate port). Repository unit tests on NativeDatabase.memory() (upsert/dedupe, reconciliation, KV). Batch prediction reconciliation.

**Testing.** Migration tests across schema versions; repo tests on in-memory DB; assert a single connection; batched-reconciliation correctness + perf. Repository tests on `NativeDatabase.memory()`; drift schema-export + step-migration tests BEFORE any schema change.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §3.H
- Effort: M
- Roadmap status: open

detail-needed (2026-07-06, goal triage): Data-layer hardening: drift schema-export + step-migration test infra, single cross-isolate DB connection — big and precedes schema v3. Want the migration-test approach confirmed.
<!-- SECTION:NOTES:END -->
