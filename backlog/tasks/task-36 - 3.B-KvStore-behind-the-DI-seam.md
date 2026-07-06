---
id: TASK-36
title: 3.B KvStore behind the DI seam
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:44'
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
**Background.** bgdude's "demo mode" promises never to touch your real data. That promise holds for the main database, but a separate simple key-value store (used for small settings and flags) sits outside that safety wrapper, so demo mode can still write to it.

**Reason for change.** For the demo-mode isolation guarantee to be real, the key-value store needs to go through the same swappable seam, so demo mode can point it at a throwaway store.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 KeyValueStore interface + Db/Memory impls via provider
- [ ] #2 Demo mode overrides to isolated store
- [ ] #3 Static facade removed after migration
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Add a KeyValueStore interface + DbKeyValueStore/MemoryKeyValueStore via kvStoreProvider; demo overrides to a namespaced/memory store. Keep a delegating static facade during migration (~40 call sites), then delete. PersistedStateNotifier takes the interface from day one.

**Testing.** Test that demo mode routes KV writes to the memory store (no real KV mutation); facade delegates correctly during migration. Refactor must be behaviour-preserving: full `flutter test` + `flutter analyze` green before and after; add the new unit tests the refactor unlocks.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §3.B
- Effort: M
- Depends on: 3.A (PersistedStateNotifier)
- Roadmap status: open
<!-- SECTION:NOTES:END -->
