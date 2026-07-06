---
id: TASK-42
title: >-
  3.H Data-layer hardening (schema tests, one connection, repo tests, batch
  reconciliation)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §3
  - phase-2
  - data-integrity
  - testing
dependencies: []
priority: medium
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Drift schema-export + step migration tests (test/drift/ snapshots) BEFORE schema v3 (P1-2/P1-3). One DB connection across isolates (drift DatabaseConnection.delayed / isolate port) — prerequisite for §3.C step 3. Repository unit tests on NativeDatabase.memory() (the data/ layer has zero direct tests): upsert/dedupe, reconciliation, KV. Batch prediction reconciliation (currently N+1 cgmBetween per pending row).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Drift schema-export + migration tests before v3
- [ ] #2 Single DB connection across isolates
- [ ] #3 Repository unit tests on in-memory DB
- [ ] #4 Batched prediction reconciliation
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §3.H
Effort: M
Roadmap status: open
<!-- SECTION:NOTES:END -->
