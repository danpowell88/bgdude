---
id: TASK-167
title: 'Integration tests must assert displayed numbers, not labels'
status: To Do
assignee: []
created_date: '2026-07-06 09:15'
labels:
  - code-health
  - testing
  - ui
milestone: m-8
dependencies: []
priority: medium
ordinal: 167000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `integration_test/app_test.dart:192-205` asserts only that the strings Working and Suggested appear, never the suggested dose; `integration_test/app_test.dart:136-148` asserts horizon labels exist, not values; `integration_test/features_flows_test.dart:41-55` drags the what-if slider and asserts nothing. A units bug or IOB-sign flip in the presenter would still pass.

**Reason for change.** No test verifies a correct number survives engine → provider → widget; the on-device suite currently proves layout, not correctness.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 In demo mode (deterministic seed) the displayed advisor suggestion equals the engine-computed value for a known input
- [ ] #2 A forecast horizon shows a plausible numeric value, not a placeholder
- [ ] #3 What-if: increasing the carb slider moves the projection in the expected direction
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- In demo mode, compute the expected advisor suggestion from the engine for the seeded input and assert the rendered text matches.
- Assert a forecast horizon renders a numeric value within a plausible range.
- Extend the what-if flow: capture the projection, raise the carb slider, assert the projection moves in the expected direction.
- Verify: `flutter analyze` clean, `flutter test` green; run the touched `integration_test/*_test.dart` files on the emulator.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (test-quality finding 5)
- Effort: M
- Where: `integration_test/app_test.dart`, `integration_test/features_flows_test.dart`
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
