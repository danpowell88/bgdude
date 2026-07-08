---
id: TASK-280
title: AppBar title Row overflows in demo mode on a narrow screen
status: In Progress
assignee:
  - Claude
created_date: '2026-07-08 00:06'
updated_date: '2026-07-08 00:06'
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
- [ ] #1 The AppBar title Row no longer overflows in demo mode at a realistic minimum screen width
- [ ] #2 Confirmed fixed via a real run of the emulator workflow (not just static review)
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
created: 2026-07-08 00:06
---
Started: wrap the AppBar title Text in Flexible+ellipsis in lib/ui/main_shell.dart so it shrinks instead of overflowing at any width; the DEMO chip (the more important visual cue in demo mode) stays fully visible. flutter analyze clean, flutter test test/ 1150/1150 green, flutter build apk --debug succeeded. Re-dispatching the emulator workflow now to confirm the fix against the exact scenario that found it (AC#2) before checking off AC#1.
---
<!-- COMMENTS:END -->
