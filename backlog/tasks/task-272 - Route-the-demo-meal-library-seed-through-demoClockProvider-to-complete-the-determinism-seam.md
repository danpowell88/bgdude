---
id: TASK-272
title: >-
  Route the demo meal-library seed through demoClockProvider to complete the
  determinism seam
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 20:26'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 529000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-220 threaded a fixed clock through the demo seam (demoClockProvider, defaulting to DateTime.now, overridden only in pumpDemoApp) and is correct on the critical axis: no frozen clock reaches production. But the demo meal-library seed at providers.dart:1515 still calls DemoHistory.demoMeals(now: DateTime.now()) with the raw wall clock, whereas the sibling demoHistoryRepositoryProvider at :1265 was correctly routed through ref.watch(demoClockProvider)(). DemoHistory.demoMeals uses now for outcome eatenAt timestamps, so an integration test asserting a displayed value in the meal library or Meals report (logged X ago, outcome times) still flakes by run time — the exact flake class TASK-220 set out to kill. Scoping gap, not a regression.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The demo meal-library seed uses ref.watch(demoClockProvider)() instead of DateTime.now()
- [ ] #2 A determinism test covers the meal-library/Meals surface (same fixed now yields identical meal timestamps)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-220)
- File: lib/state/providers.dart:1515 (contrast the correctly-routed :1265); lib/dev/demo_history.dart demoMeals now usage
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
