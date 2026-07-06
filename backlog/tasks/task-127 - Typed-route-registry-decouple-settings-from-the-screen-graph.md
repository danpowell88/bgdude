---
id: TASK-127
title: Typed route registry (decouple settings from the screen graph)
status: To Do
assignee: []
created_date: '2026-07-06 08:37'
labels:
  - code-health
  - ui
  - cleanup
milestone: m-8
dependencies: []
priority: low
ordinal: 127000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** There are 49 inline `Navigator.push`/`MaterialPageRoute` calls across 9 files; `lib/ui/settings_screen.dart` alone has 30 and imports ~15 screen files. There are no typed routes and no single navigation map.

**Reason for change.** The settings screen is coupled to the entire screen graph; a typed registry gives one place to see navigation and cuts the import fan-out.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A lightweight `AppRoutes` registry (or go_router) exists with typed push helpers
- [ ] #2 `settings_screen` navigates by route and drops direct screen imports
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

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
