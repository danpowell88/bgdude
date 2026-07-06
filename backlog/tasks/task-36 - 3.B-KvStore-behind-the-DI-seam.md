---
id: TASK-36
title: 3.B KvStore behind the DI seam
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §3
  - architecture
dependencies: []
priority: medium
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Static KvStore (and PumpEventLog store) bypass Riverpod, so demo-mode isolation holds for the repository but not KV-backed state. Add KeyValueStore interface + DbKeyValueStore/MemoryKeyValueStore via kvStoreProvider; demo overrides to a namespaced/memory store. Keep a delegating static facade during migration (~40 call sites), then delete. PersistedStateNotifier takes the interface from day one.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 KeyValueStore interface + Db/Memory impls via provider
- [ ] #2 Demo mode overrides to isolated store
- [ ] #3 Static facade removed after migration
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §3.B
Effort: M
Depends on: 3.A (PersistedStateNotifier)
Roadmap status: open
<!-- SECTION:NOTES:END -->
