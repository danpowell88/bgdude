---
id: TASK-127
title: Typed route registry (decouple settings from the screen graph)
status: In Progress
assignee:
  - Claude
created_date: '2026-07-06 08:37'
updated_date: '2026-07-07 19:31'
labels:
  - code-health
  - ui
  - cleanup
  - detail-needed
milestone: m-8
dependencies: []
priority: low
ordinal: 110100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** There are 49 inline `Navigator.push`/`MaterialPageRoute` calls across 9 files; `lib/ui/settings_screen.dart` alone has 30 and imports ~15 screen files. There are no typed routes and no single navigation map.

**Reason for change.** The settings screen is coupled to the entire screen graph; a typed registry gives one place to see navigation and cuts the import fan-out.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A lightweight `AppRoutes` registry (or go_router) exists with typed push helpers
- [x] #2 `settings_screen` navigates by route and drops direct screen imports
- [ ] #3 Integration tests still pass on the emulator
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add an `AppRoutes` registry (or adopt go_router) with typed push helpers.
- Convert `settings_screen.dart` to route-based navigation, dropping direct screen imports.
- Convert remaining inline `Navigator.push` sites.
- Verify: `flutter analyze` clean, `flutter test` green, integration tests pass on the emulator.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (navigation sweep, `lib/ui/settings_screen.dart`)
- Effort: M
- Where: `lib/ui/settings_screen.dart` and 8 other `lib/ui/` files, new routes file
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 15:07
---
Started: surveying the 49 Navigator.push/MaterialPageRoute call sites across 9 lib/ui files to design a typed AppRoutes registry.
---

author: Claude
created: 2026-07-07 15:12
---
Added lib/ui/app_routes.dart: an AppRoute enum (15 zero-argument screens) + AppRoutes.push(context, route) typed helper (AC#1). Converted all 15 Navigator.push/MaterialPageRoute call sites in settings_screen.dart to AppRoutes.push(...) and dropped its 14 direct screen imports down to a single 'app_routes.dart' import (AC#2). Scope note: the other 8 files with inline Navigator.push (advanced_screen, developer_screen, home_screen, main_shell, meal_library_screen, reports_hub_screen, therapy_report_screen, timeline_screen) were deliberately left as-is -- checked each and most carry constructor arguments (ExplainReadingScreen(at:), MealDetailScreen(mealId:)), return a typed result (MaterialPageRoute<Annotation>), or use a runtime builder() callback (reports_hub_screen) -- none fit a zero-arg enum registry without a bigger typed-route-with-args design than this ticket's ACs called for. flutter analyze clean, flutter test test/ green (942 tests), flutter build apk --debug succeeded. AC#3 (integration tests on the emulator): could not be verified in this sandboxed session -- the emulator VM-service WebSocket connection is broken here for ANY integration_test file, a pre-existing environment limitation (see memory integration-test-emulator-limitation), not specific to this change. This is a behaviour-preserving refactor (identical MaterialPageRoute/builder pairs, just routed through the registry), so risk is low, but AC#3 needs a session with real emulator connectivity to actually confirm -- flagging rather than claiming it passed.
---

author: Claude
created: 2026-07-07 15:12
---
Status correction: leaving In Progress rather than Done since AC#3 (integration tests pass on the emulator) is explicitly unverified here, matching this project's convention for emulator/hardware-blocked ACs (see TASK-31/TASK-33) rather than marking a task Done with an unmet AC. AC#1/#2 and all applicable DoD items are genuinely complete; only AC#3 remains, and it needs a session with real emulator connectivity, not further code changes.
---

author: Claude
created: 2026-07-07 19:31
---
detail-needed: AC#3 (integration tests pass on the emulator) cannot be verified in this sandboxed session -- the emulator VM-service WebSocket connection is broken here for ANY integration_test file (pre-existing, documented environment limitation, not specific to this change). AC#1/#2 and all applicable DoD items are complete; this needs a session with real emulator connectivity to close out, matching the TASK-31/TASK-33 hardware-blocked convention.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
