---
id: TASK-272
title: >-
  Route the demo meal-library seed through demoClockProvider to complete the
  determinism seam
status: Done
assignee:
  - Claude
created_date: '2026-07-07 20:26'
updated_date: '2026-07-08 05:30'
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
- [x] #1 The demo meal-library seed uses ref.watch(demoClockProvider)() instead of DateTime.now()
- [x] #2 A determinism test covers the meal-library/Meals surface (same fixed now yields identical meal timestamps)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-220)
- File: lib/state/providers.dart:1515 (contrast the correctly-routed :1265); lib/dev/demo_history.dart demoMeals now usage
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 05:21
---
Started: routing the demo meal-library seed through demoClockProvider, matching the sibling demoHistoryRepositoryProvider pattern.
---

author: Claude
created: 2026-07-08 05:30
---
Fixed both ACs.

AC#1: MealLibraryNotifier now takes an optional now parameter (defaulting to DateTime.now), stored as _now and used in _restore instead of the raw wall clock. mealLibraryProvider wires it via ref.watch(demoClockProvider), matching the sibling demoHistoryRepositoryProvider pattern exactly.

AC#2: added two test groups to test/demo_determinism_test.dart -- (1) DemoHistory.demoMeals determinism at the pure-function level (two calls with the same now produce identical meals/outcome timestamps; a different now produces different ones, sanity check), and (2) the REAL fix site: MealLibraryNotifier(demo: true, now: fixed) seeds meals matching DemoHistory.demoMeals direct output for the same fixed clock -- using a deliberately non-today fixture date so the check cannot coincidentally pass if the notifier is still secretly reading the real wall clock.

Rigor check: reverted _restore to DateTime.now() directly. First attempt with a same-day fixture (2026-07-08, matching todays actual date in this environment) did NOT catch it -- a false pass, since demoMeals relative-day offsets happened to still land close enough. Caught the gap, switched to a clearly-historical fixture (2020-01-15) -- reran, the new test correctly failed with visibly different (2026 vs 2020) outcome timestamps. Reverted the bug; git diff clean. Also had to reword one comment that literally contained the substring DateTime.now() -- TASK-237s wall-clock guard test correctly flagged it as an unjustified match even though it was prose, not code; reworded to describe the same thing without that exact string.

Verified: flutter analyze clean, flutter test --coverage green (1181 tests, 67.91% >= 65% floor). flutter build apk --debug succeeds. No native Kotlin, no user-guide update (internal demo-fixture determinism fix, no user-visible surface).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
