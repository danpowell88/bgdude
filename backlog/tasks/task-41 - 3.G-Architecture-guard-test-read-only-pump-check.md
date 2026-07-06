---
id: TASK-41
title: 3.G Architecture guard test (+ read-only-pump check)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 05:24'
labels:
  - roadmap
  - §3
  - phase-0
  - architecture
  - testing
  - "\U0001F512 safety"
  - detail-needed
dependencies: []
priority: high
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude has a layering rule: screens may use plain data types from anywhere, but must not reach directly into the app's services or storage. Two screens currently break that rule, and the "the app never sends write/control commands to the pump" promise is only enforced by discipline, not by any check.

**Reason for change.** A tiny automated test can enforce both the layering rule and the read-only-pump guarantee, turning "we promise" into "the build fails if anyone breaks it".
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 architecture_test.dart walks lib/ui/** imports and fails on interface/store/service imports
- [ ] #2 Existing violations fixed (meal_library_screen, protocol_explorer_screen)
- [ ] #3 Build fails if any Kotlin imports request.control
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add `test/architecture_test.dart` (~30 lines) walking `lib/ui/**` imports: UI may import value/DTO types from any layer, never interfaces/stores/services.
- Fix the two current violations (`meal_library_screen`, `protocol_explorer_screen`).
- In the same test, fail the build if any Kotlin file imports `request.control`.
- Sanity-check the guard: the test fails on a deliberately-added bad import and on a deliberately-added `request.control` import; passes once violations are fixed.
- Add/extend unit tests under `test/`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §3.G
- Effort: S
- Flags: 🔒 safety
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:24
---
detail-needed (2026-07-06, goal triage): The guard test itself is easy, but fixing the existing violation protocol_explorer_screen→PumpSource (an interface import) needs a provider-routing redesign of the probe API — want the approach confirmed so the read-only Explorer keeps working.
---
<!-- COMMENTS:END -->
