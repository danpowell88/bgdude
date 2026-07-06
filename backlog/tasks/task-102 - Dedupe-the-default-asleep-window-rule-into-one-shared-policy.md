---
id: TASK-102
title: Dedupe the default asleep-window rule into one shared policy
status: Done
assignee: []
created_date: '2026-07-06 04:53'
updated_date: '2026-07-06 05:04'
labels:
  - code-health
  - cleanup
dependencies: []
priority: medium
ordinal: 102000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The default asleep rule (`hour >= 23 || hour < 7`) is copy-pasted in six places:

- `lib/timeline/event_builder.dart:226` (`_defaultAsleep`)
- `lib/feedback/confirmation_service.dart:122` (byte-for-byte duplicate `_defaultAsleep`)
- `lib/state/providers.dart:1708`
- `lib/pump/simulated_pump_client.dart:106`
- `lib/ui/home_screen.dart:239` (inline in `_explainCurrent`)
- `lib/ui/timeline_screen.dart:166-167` (inline)

**Reason for change.** The sleep window is a clinical policy that will likely become user-configurable; six divergent copies (two inside widget build code) mean a future change will miss call sites.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 One shared helper (`isDefaultAsleep(DateTime)` or a `SleepWindow` value object) in a neutral non-UI module
- [ ] #2 All six call sites use it; the duplicates are deleted
- [ ] #3 Unit test covers the boundary hours (22:59, 23:00, 06:59, 07:00)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add the shared policy (suggest `lib/core/` next to units, or a small `lib/core/sleep_window.dart`).
- Migrate the two named helpers, the provider/simulator usages, and the two inline widget expressions.
- Add the boundary unit test.
- `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: code-health survey 2026-07-06 (lib finding 2)
- Effort: S
- Where: event_builder.dart:226, confirmation_service.dart:122, providers.dart:1708, simulated_pump_client.dart:106, home_screen.dart:239, timeline_screen.dart:166
<!-- SECTION:NOTES:END -->
