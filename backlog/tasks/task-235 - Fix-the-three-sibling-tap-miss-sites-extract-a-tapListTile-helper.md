---
id: TASK-235
title: Fix the three sibling tap-miss sites; extract a tapListTile helper
status: To Do
assignee: []
created_date: '2026-07-07 07:48'
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
- [ ] #1 A shared `tapListTile(finder)` helper (scroll + ensureVisible + settle + tap) in the harness
- [ ] #2 All four sites route through it
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

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
