---
id: TASK-279
title: tapListItem has the same TASK-234 tap-miss gap as tapListTile did
status: Done
assignee:
  - Claude
created_date: '2026-07-07 23:28'
updated_date: '2026-07-08 04:16'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 113243
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
While fixing TASK-235 (extracting tapListTile with scrollUntilVisible + ensureVisible + tap for app_test.dart's 4 tap-miss sites), found that harness.dart's PRE-EXISTING tapListItem(tester, label) helper has the identical gap: it calls scrollUntilVisible + pumpAndSettle + tap, with no ensureVisible step. Per TASK-234's diagnosis, scrollUntilVisible alone stops as soon as a tile's EDGE enters the viewport, so tap()'s center hit-test can miss. tapListItem is used across features_settings_test.dart, features_reports_test.dart and other files via openSettingsScreen -- any of those tiles could start flaking the same way Diagnostics log did, especially as lists grow. Not fixed in TASK-235 itself: adding ensureVisible to a helper already used by many currently-passing tests, with no way to verify no regression in a session without emulator connectivity, was judged riskier than the well-scoped tapListTile addition.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 tapListItem gains the same ensureVisible step as tapListTile (or is merged into a single helper)
- [x] #2 The functional integration_test files that use it are re-verified green on an emulator after the change
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test --coverage test/ green
- [ ] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [ ] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 23:29
---
Started: on reflection, the same low-risk analyze-only verification standard already applied to TASK-235/220 applies here too -- fixing tapListItem directly now rather than leaving a known gap.
---

author: Claude
created: 2026-07-07 23:31
---
AC#1 done: merged tapListItem into tapListTile (tapListItem(tester, label) now delegates to tapListTile(tester, find.text(label))) -- one implementation of the scroll+ensureVisible+tap pattern instead of two, closing the gap without touching any call site's signature (openSettingsScreen and every features_*_test.dart file that uses it are unaffected). AC#2 (re-verify the functional integration files on an emulator) stays Blocked -- same emulator-connectivity limitation as the rest of this session's integration_test/ work. Pipeline: build_runner build, flutter analyze clean, flutter test test/ 1150/1150 green, flutter build apk --debug succeeded.
---

author: Claude
created: 2026-07-08 04:16
---
Unblocked and confirmed for real: dispatch 28915351919 ran every file that uses tapListItem (via openSettingsScreen) -- features_settings_test.dart (12/15 passed; the 3 failures were unrelated new bugs, filed as TASK-294/295, NOT tap-miss failures), features_reports_test.dart (3/3), features_protocol_explorer_test.dart (2/2), db_recovery_screen_test.dart (1/1). Confirmed via the actual failure log: none of the 4 failures across the whole dispatch were a tap-miss/hit-test-warning pattern -- 2 were a pre-existing RenderFlex overflow (pump_screen.dart, TASK-294), 1 was a missing-scroll assertion gap (TASK-295), 1 was a missing-scroll drag() gap in a different file entirely (TASK-296, features_flows_test.dart, doesn't even use tapListItem). tapListItem's own fix is validated working across every settings navigation it drives.
---
<!-- COMMENTS:END -->
