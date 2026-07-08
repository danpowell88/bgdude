---
id: TASK-280
title: AppBar title Row overflows in demo mode on a narrow screen
status: Done
assignee:
  - Claude
created_date: '2026-07-08 00:06'
updated_date: '2026-07-08 00:17'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 113245
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Found by TASK-219's first dispatch of the new nightly emulator workflow (the exact value proposition of adding that automated coverage -- caught immediately, something no unit test could since RenderFlex overflow needs a real layout pass): 'A RenderFlex overflowed by 50 pixels on the right' in lib/ui/main_shell.dart:147's AppBar title Row (Text(_titles[_index]) + a DEMO Chip when devMode is on), reported against 12 of the 13 tests in integration_test/app_test.dart on a fresh API 34 google_apis x86_64 AVD. The devMode-only 'Exit demo' action button plus the quick-log/settings icons squeeze the AppBar title area down to as little as ~75 logical px, and the unwrapped title Text + Chip don't fit.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The AppBar title Row no longer overflows in demo mode at a realistic minimum screen width
- [x] #2 Confirmed fixed via a real run of the emulator workflow (not just static review)
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
created: 2026-07-08 00:06
---
Started: wrap the AppBar title Text in Flexible+ellipsis in lib/ui/main_shell.dart so it shrinks instead of overflowing at any width; the DEMO chip (the more important visual cue in demo mode) stays fully visible. flutter analyze clean, flutter test test/ 1150/1150 green, flutter build apk --debug succeeded. Re-dispatching the emulator workflow now to confirm the fix against the exact scenario that found it (AC#2) before checking off AC#1.
---

author: Claude
created: 2026-07-08 00:17
---
Both ACs confirmed via a REAL run, not just static review: dispatched the emulator workflow before the fix (run 28906890824, 12/13 tests failed on the exact RenderFlex overflow this task describes) and after (run 28907529774, https://github.com/danpowell88/bgdude/actions/runs/28907529774 -- 9/13 passed, ZERO overflow errors, the specific tests that were failing purely due to this bug now pass). The remaining 4 failures in that second run are unrelated, genuine, pre-existing bugs the new coverage surfaced for the first time (the AppBar crash was blocking every test from ever reaching them) -- filed as TASK-281 (quick-log sheet vertical overflow), TASK-282 (a meals-tab tap-miss, same class as TASK-234/235 but a different site), TASK-283 ('Clarke error grid' text missing on Advanced). Not fixed here -- out of this task's scope, which was specifically the AppBar title overflow.

Fix: wrapped the AppBar title's Text in Flexible+overflow:ellipsis in lib/ui/main_shell.dart so it shrinks instead of erroring regardless of how narrow the title area gets (the devMode 'Exit demo' action + quick-log/settings icons can squeeze it down to ~75px); the DEMO chip (more important cue) always stays fully visible. Did not add a dedicated headless widget test: MainShell has a heavy provider/screen dependency graph (TodayTab, appJobsProvider.runStartup, etc.) that would need substantial harness work to instantiate in isolation -- the emulator suite itself (which just proved the bug and the fix) is this fix's real regression test going forward.

Pipeline: flutter analyze clean, build_runner build, flutter test --coverage test/ 1150/1150 green (no coverage change -- UI-only fix, covered by integration_test/ not unit tests per CLAUDE.md), flutter build apk --debug succeeded.
---
<!-- COMMENTS:END -->
