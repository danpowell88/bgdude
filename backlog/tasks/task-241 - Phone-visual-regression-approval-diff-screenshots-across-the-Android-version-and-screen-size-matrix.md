---
id: TASK-241
title: >-
  Phone visual-regression: approval-diff screenshots across the Android-version
  and screen-size matrix
status: To Do
assignee: []
created_date: '2026-07-07 12:54'
updated_date: '2026-07-07 12:54'
labels:
  - testing
  - infra
milestone: m-8
dependencies:
  - TASK-220
priority: medium
ordinal: 113800
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Today the functional integration suite (`integration_test/`, demo mode) runs on a single emulator config and asserts behaviour, not appearance. There is no image-based approval diff, so layout/visual drift (overflow, clipped text, colour/contrast, spacing) on other Android versions or screen sizes goes unnoticed until it ships.

**Reason for change.** Capturing a reference screenshot per screen and failing on unexpected pixel/layout changes catches visual regressions automatically. Running that capture across every supported Android API level and a range of phone screen dimensions turns the existing suite into a device-drift tripwire at bounded (nightly) cost.

**Scope.** Drive the existing demo-mode harness to capture one image per key screen, for each supported Android API level and a set of representative phone screen dimensions/densities, and compare against committed baselines with an approval-diff step. Non-deterministic surfaces (clock/time-of-day, current reading, near-now events, seeded noise, any `DateTime.now()`) must be mocked or frozen so diffs reflect real UI change only. This ties together the golden-capture idea (TASK-98), the device-config matrix (TASK-223), the deterministic demo seam (TASK-220), and the nightly emulator job (TASK-219) into a single phone visual-regression pipeline.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every key screen produces a captured screenshot in demo mode via the existing integration harness
- [ ] #2 Capture runs across each supported Android API level (per the documented supported/tested matrix) and a set of representative phone screen dimensions/densities
- [ ] #3 An approval-diff step compares captures against committed baselines and fails on unexpected visual change, with a documented command to review/update baselines
- [ ] #4 Baseline images are committed and organised by screen x API level x screen-size
- [ ] #5 Time and other non-deterministic surfaces (clock, current reading, near-now events, seeded noise) are mocked/frozen so diffs reflect only real UI changes
- [ ] #6 Runs in the nightly CI emulator job (or a documented manual command) and the supported matrix is documented in SETUP.md
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: device-testing sweep 2026-07-07 (user request: cross-version + screen-dimension visual regression)
- Effort: M-L
- Where: `integration_test/` (harness + screenshot driver), `test_driver/screenshot_driver.dart`, `.github/workflows/`, `SETUP.md`, `doc/user-guide.html`
- Depends: TASK-220 (deterministic `now`/seed seam is the prerequisite for mocking time)
- Related: TASK-98 (golden/screenshot harness), TASK-223 (device-config API/dimension matrix), TASK-219 (nightly emulator job), TASK-240 (the Garmin equivalent — mirror its approach)
- Note: overlaps TASK-98 and TASK-223; if consolidating, fold those in rather than duplicating baselines
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
