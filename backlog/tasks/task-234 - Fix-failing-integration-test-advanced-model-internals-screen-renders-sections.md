---
id: TASK-234
title: 'Fix failing integration test: advanced/model internals screen renders sections'
status: Done
assignee:
  - Claude
created_date: '2026-07-07 04:58'
updated_date: '2026-07-07 07:13'
labels:
  - code-health
  - testing
  - ui
milestone: m-8
dependencies: []
priority: medium
ordinal: 103100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `integration_test/app_test.dart` test 'advanced/model internals screen renders sections' fails on emulator-5554 on unmodified main (verified 2026-07-07 via git stash: fails with and without the TASK-167 changes, ~2min timeout-ish runtime before the failure). All other app_test cases pass.

**Reason for change.** The on-device suite should be green so real regressions are visible; CLAUDE.md treats emulator coverage as required for screens.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The advanced/model-internals integration test passes on the emulator
- [x] #2 Root cause noted (renamed section, missing demo data, or scroll timing)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: TASK-167 emulator run 2026-07-07
- Effort: S
- Where: `integration_test/app_test.dart`, `lib/ui/advanced_screen.dart`
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 05:01
---
Started: reproduce the on-device failure and root-cause (renamed section vs missing demo data vs scroll timing).
---

author: Claude
created: 2026-07-07 07:13
---
Done. The Advanced screen grew (Clarke grid section etc.), pushing the tile further down — which is why this started failing.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Root cause: scroll timing, not a renamed section or missing data — the failure log showed tap()'s warnIfMissed warning; scrollUntilVisible had only brought the 'Diagnostics log' tile's edge into the viewport, the center hit-test missed, the screen never opened, and the AppBar expectation failed. Fix: ensureVisible + settle before the tap. Verified on emulator-5554 (test green in 53s). Analyze clean; unit suite untouched. Commit c7dac48.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [x] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
