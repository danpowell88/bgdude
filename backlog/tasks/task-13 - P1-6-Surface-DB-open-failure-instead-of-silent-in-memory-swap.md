---
id: TASK-13
title: P1-6 Surface DB-open failure instead of silent in-memory swap
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 05:27'
labels:
  - roadmap
  - §1-P1
  - phase-0
  - data-integrity
dependencies: []
priority: high
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** If the encrypted database fails to open (for example a bad key), the app quietly switches to a temporary in-memory database and carries on as though nothing is wrong.

**Reason for change.** That means silent data loss — you think your history is being saved when it is not. A visible warning is far safer than pretending everything is fine.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 DB-open failure shows a banner
- [x] #2 Failure is logged
- [x] #3 No silent in-memory fallback
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- In `main.dart:26-34` surface a banner + log on DB-open failure instead of the silent in-memory fallback (ties to the §3.D logging infra).
- Test: force a DB-open failure (bad key) and assert the banner shows + failure is logged; app does not silently continue on memory DB.
- Repository tests on `NativeDatabase.memory()`; add drift schema-export + step-migration tests BEFORE any schema change (§3.H).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §1 P1-6
- Effort: S
- Where: main.dart:26-34
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
DB-open failure in `main.dart` is now surfaced with a visible banner and logged instead of silently swapping to an in-memory database. Landed in commit f623821 with tests forcing a bad-key open failure; `flutter analyze` clean and `flutter test` green.
<!-- SECTION:FINAL_SUMMARY:END -->
