---
id: TASK-41
title: 3.G Architecture guard test (+ read-only-pump check)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §3
  - phase-0
  - architecture
  - testing
  - "\U0001F512 safety"
dependencies: []
priority: high
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Rule: UI may import value/DTO types from any layer, never interfaces/stores/services (those come via providers). Current violations: meal_library_screen.dart→kv_store.dart; protocol_explorer_screen.dart→pump_source.dart. Enforce with test/architecture_test.dart (~30 lines walking lib/ui/** imports); in the same file, FAIL the build if any Kotlin file imports request.control (mechanical read-only-pump guarantee).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 architecture_test.dart walks lib/ui/** imports and fails on interface/store/service imports
- [ ] #2 Existing violations fixed (meal_library_screen, protocol_explorer_screen)
- [ ] #3 Build fails if any Kotlin imports request.control
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §3.G
Effort: S
Flags: 🔒 safety
Roadmap status: open
<!-- SECTION:NOTES:END -->
