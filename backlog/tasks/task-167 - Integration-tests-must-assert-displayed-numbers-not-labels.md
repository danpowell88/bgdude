---
id: TASK-167
title: 'Integration tests must assert displayed numbers, not labels'
status: Done
assignee:
  - Claude
created_date: '2026-07-06 09:15'
updated_date: '2026-07-07 05:01'
labels:
  - code-health
  - testing
  - ui
milestone: m-8
dependencies: []
priority: medium
ordinal: 107300
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `integration_test/app_test.dart:192-205` asserts only that the strings Working and Suggested appear, never the suggested dose; `integration_test/app_test.dart:136-148` asserts horizon labels exist, not values; `integration_test/features_flows_test.dart:41-55` drags the what-if slider and asserts nothing. A units bug or IOB-sign flip in the presenter would still pass.

**Reason for change.** No test verifies a correct number survives engine → provider → widget; the on-device suite currently proves layout, not correctness.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 In demo mode (deterministic seed) the displayed advisor suggestion equals the engine-computed value for a known input
- [x] #2 A forecast horizon shows a plausible numeric value, not a placeholder
- [x] #3 What-if: increasing the carb slider moves the projection in the expected direction
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 04:34
---
Started: assert the rendered advisor dose equals the engine-computed value for the demo state; forecast horizon shows a plausible numeric; what-if carb slider moves the projection the expected direction. Will run the touched files on emulator-5554.
---

author: Claude
created: 2026-07-07 05:01
---
Done. Pre-existing on-device failure split out as TASK-234 rather than scope-creeping this ticket.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
app_test: the advisor test reads the ProviderContainer, computes advise(state, carbsGrams: 45) for the states captured before AND after the tap (mid-flow snapshot safety) and asserts the rendered N.NN dose text matches; the Predict tab test collects rendered numerics and requires >=3 plausible mmol values (2-30). features_flows: the what-if test parses 'ending X' from the projection sentence, raises the carb slider twice, and asserts the ending glucose strictly increases. Ran on emulator-5554: features_flows 4/4 green; app_test 12 green + 1 PRE-EXISTING failure ('advanced/model internals renders sections', fails on unmodified main too — verified via git stash) filed as TASK-234. Local pipeline: analyze clean, 729 unit tests green, APK builds.
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
