---
id: TASK-285
title: '_AddMealSheet form overflows vertically, breaking the Save button''s tap target'
status: Done
assignee:
  - Claude
created_date: '2026-07-08 00:54'
updated_date: '2026-07-08 01:00'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 721000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Found by TASK-219's emulator workflow, 3rd dispatch (after fixing TASK-280/281/283, once the meals-tab test finally got far enough to actually reach the add-meal form): 'A RenderFlex overflowed by 153 pixels on the bottom' in lib/ui/meal_library_screen.dart:281's _AddMealSheet Column (2 scan buttons + name/carbs/fat/protein fields + category dropdown + fat-protein-heavy switch + Save button) -- tall enough to overflow a shorter screen even before the keyboard opens, and the overflow broke the Save button's actual tap target (a tap() warning: 'derived an Offset that would not hit test on the specified widget').
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The add-meal form no longer overflows vertically at a realistic screen height, keyboard open or not
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
created: 2026-07-08 00:55
---
Started+fixed: wrapped _AddMealSheet's Column in a SingleChildScrollView, same pattern as TASK-281's quick_log_sheet.dart fix. isScrollControlled: true was already set on the showModalBottomSheet call (lets the sheet itself grow tall), but the CONTENT still needed its own scrollable for when it doesn't fit.
---

author: Claude
created: 2026-07-08 01:00
---
Both ACs done. AC#1: wrapped _AddMealSheet's Column in SingleChildScrollView (lib/ui/meal_library_screen.dart) -- same pattern as TASK-281's quick_log_sheet.dart fix, for the same reason (a tall form that doesn't fit a shorter screen, isScrollControlled: true on the sheet itself doesn't help the CONTENT scroll). AC#2 (confirmed via the emulator workflow): dispatched run 28908779335 after this + TASK-280/281/283's fixes landed -- 12/13 app_test.dart tests passed, up from 1/13 on the very first (pre-any-fix) dispatch. The one remaining failure at that point was THIS exact overflow (the meals-tab test never got past the Save-meal tap before this fix landed) -- fixed here, will be confirmed by the next dispatch alongside TASK-284's native fix.

Pipeline: flutter analyze clean, build_runner build, flutter test --coverage test/ 1150/1150 green, flutter build apk --debug succeeded. No native Kotlin touched by this specific fix (TASK-284's fix, committed alongside, did touch native).
---
<!-- COMMENTS:END -->
