---
id: TASK-281
title: Quick-log sheet overflows vertically on a real device/emulator
status: Done
assignee:
  - Claude
created_date: '2026-07-08 00:16'
updated_date: '2026-07-08 02:58'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 113250
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Found by TASK-219's emulator workflow (2nd dispatch, after TASK-280's AppBar fix unblocked these tests from ever running): 'A RenderFlex overflowed by 16 pixels on the bottom' inside the quick-log bottom sheet (a DraggableScrollableNotification-nested Column), affecting integration_test/app_test.dart's 'quick log sheet opens and logs carbs' and 'quick-log exposes wellbeing logs incl. illness + mood' tests. Likely lib/ui/quick_log_sheet.dart's content not fitting the sheet's initial extent on this AVD's screen size -- needs the exact failing widget/Column identified from a full log capture (only the overflow summary was captured here, not the full creator chain).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The quick-log sheet no longer overflows vertically at a realistic screen size
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
created: 2026-07-08 00:20
---
Started+fixed: wrapped the quick-log sheet's Column in a SingleChildScrollView so the 9-chip Wrap can scroll instead of overflowing when showModalBottomSheet's height cap is tight on a shorter screen.
---

author: Claude
created: 2026-07-08 02:58
---
Confirmed via run 28912128406 (untouched, ran to its own natural conclusion): integration_test/app_test.dart's 13 tests pass cleanly, including 'quick log sheet opens and logs carbs' and 'quick-log exposes wellbeing logs incl. illness + mood' which this fix targets. Pipeline (re-verified multiple times this session since): flutter analyze clean, flutter test --coverage green (67%+, above floor), flutter build apk --debug succeeds. No native Kotlin change, no user-guide update needed (internal layout fix).
---
<!-- COMMENTS:END -->
