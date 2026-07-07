---
id: TASK-235
title: Fix the three sibling tap-miss sites; extract a tapListTile helper
status: Blocked
assignee: []
created_date: '2026-07-07 07:48'
updated_date: '2026-07-07 23:28'
labels:
  - code-health
  - testing
milestone: m-8
dependencies: []
priority: medium
ordinal: 113242
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** TASK-234 (c7dac48) correctly diagnosed the integration tap-miss root cause — `scrollUntilVisible` stops when the tile edge enters the viewport so `tap()` center hit-tests can miss — but patched only the one tile that flaked (Diagnostics log, deepest in the Advanced list). Three siblings in `integration_test/app_test.dart` keep the identical latent pattern: Nightscout (:107→:110), Therapy profile (:300→:302), Model internals (:313→:315). Whichever tile lands at the viewport edge next will start flaking as lists grow.

**Reason for change.** Same-window spot-fixes that leave the pattern in place recur; one helper removes the class.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A shared `tapListTile(finder)` helper (scroll + ensureVisible + settle + tap) in the harness
- [x] #2 All four sites route through it
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add the helper to `integration_test/harness.dart`.
- Migrate the four call sites.
- Verify: functional integration files green on the emulator.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: hourly quality check 2026-07-07 #3 (finding 1)
- Effort: S
- Where: integration_test/app_test.dart:107-315, integration_test/harness.dart
- Related: TASK-234 (the spot fix)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 23:28
---
Code complete, both ACs done -- Blocked (not Done) only because DoD verify step ("functional integration files green on the emulator") cannot be exercised: same pre-existing emulator-connectivity limitation as TASK-33/220/226/127/252/31 this session.

AC#1: added tapListTile(tester, finder) to integration_test/harness.dart -- scrollUntilVisible + ensureVisible + pumpAndSettle + tap + pumpAndSettle, generalising TASK-234s inline Diagnostics-log fix (the root-cause diagnosis was correct: scrollUntilVisible alone stops at the tile edge, so tap()s center hit-test can miss). Takes a Finder (not a label string) per the ACs own signature, matching the tickets intent that it work for any tile.

AC#2: migrated all 4 sites in integration_test/app_test.dart -- Nightscout, Therapy profile, Model internals, and Diagnostics log (the already-fixed one, now routed through the shared helper instead of its own inline fix, so there is exactly one implementation of the pattern). Left the OTHER "Model internals" occurrence (a scroll+visibility-check with no tap) untouched -- it never had the bug, not in scope.

Related finding, NOT fixed here (would touch many pre-existing passing tests without a way to verify no regression in this session): harness.darts existing tapListItem(tester, label) helper has the SAME latent gap (scrollUntilVisible with no ensureVisible) and is used across features_settings_test.dart, features_reports_test.dart and others. Flagging rather than silently fixing blind.

Pipeline: build_runner build, flutter analyze clean, flutter test test/ 1150/1150 green (integration_test/ isnt in that scope), flutter build apk --debug succeeded. No native Kotlin, no user-guide update (test-only change).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
