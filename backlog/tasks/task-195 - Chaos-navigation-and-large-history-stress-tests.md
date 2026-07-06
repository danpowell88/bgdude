---
id: TASK-195
title: Chaos navigation and large-history stress tests
status: To Do
assignee: []
created_date: '2026-07-06 12:56'
updated_date: '2026-07-06 12:58'
labels:
  - code-health
  - testing
milestone: m-8
dependencies: []
priority: medium
ordinal: 109200
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The integration suite drives calm, scripted flows only; nothing stresses the app: no rapid cross-screen navigation while the demo pump emits, no backgrounding/rotation churn, and no large-data run (a year of 5-minute CGM is ~100k rows — reports, metrics and training have never been exercised at that size; several paths recompute over full lists).

**Reason for change.** Long-run degradation and navigation races only surface under stress; a repeatable chaos run catches them before a real overnight failure does.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 An integration chaos test: N minutes of random screen navigation + rotation + background/foreground in demo mode with an accelerated emitter, asserting zero uncaught exceptions
- [ ] #2 A large-history unit/integration test seeding ~100k CGM rows: reports and metrics complete within a stated time bound; training completes off-thread
- [ ] #3 Bounds documented so regressions are visible
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a chaos driver to integration_test/ (random walk over the nav graph, seeded for reproducibility).
- Add a large-seed generator to test/support/ and the bounded-time report/metrics test.
- Run the chaos test on the emulator; record baseline timings.
- Verify: `flutter analyze` clean, `flutter test` green; chaos run green on emulator.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep 2026-07-06
- Effort: M
- Where: integration_test/, test/support/
- Related: TASK-167 (value assertions), TASK-98 (goldens), TASK-179 (unbounded list fix)
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
