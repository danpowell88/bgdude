---
id: TASK-282
title: 'Meals-tab tap-miss on a saved meal tile (app_test.dart:267)'
status: Done
assignee:
  - Claude
created_date: '2026-07-08 00:16'
updated_date: '2026-07-08 02:58'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 113251
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Found by TASK-219's emulator workflow: tapping a saved meal tile ('Test pasta') in integration_test/app_test.dart:267 warns 'derived an Offset that would not hit test on the specified widget... off-screen, or another widget is obscuring it' -- the exact TASK-234/235 tap-miss pattern (scrollUntilVisible without ensureVisible), but at a site NOT among the 4 TASK-235 fixed. Should route through the shared tapListTile helper (integration_test/harness.dart) like the others.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 app_test.dart:267's meal-tile tap routes through tapListTile or an equivalent ensureVisible fix
- [x] #2 Confirmed via the emulator workflow
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test --coverage test/ green
- [x] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [x] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 00:18
---
Started: route the meals-tab tap through the shared tapListTile helper, same fix as TASK-235/279.
---

author: Claude
created: 2026-07-08 02:58
---
Confirmed via run 28912128406 (untouched, ran to its own natural conclusion): app_test.dart's 13 tests pass cleanly, including the meals-tab tile-tap test at app_test.dart:267 this fix targets. Pipeline: flutter analyze clean, flutter test --coverage green, flutter build apk --debug succeeds. No native/user-guide changes needed.
---
<!-- COMMENTS:END -->
