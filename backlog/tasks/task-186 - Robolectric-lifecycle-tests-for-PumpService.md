---
id: TASK-186
title: Robolectric lifecycle tests for PumpService
status: To Do
assignee: []
created_date: '2026-07-06 09:20'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - native
  - testing
milestone: m-8
dependencies:
  - TASK-178
priority: medium
ordinal: 108600
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `android/app/src/test` covers mappers/probe/snapshot only — there are zero tests for `PumpService` lifecycle (notification channel created before `startForeground`, boot-receiver path) or `PumpCommHandler.onPumpDisconnected` reconnect behaviour; these are the state machines that keep monitoring alive for days.

**Reason for change.** The longest-running, hardest-to-reproduce failure modes live in exactly the code with no test harness.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Robolectric tests: channel-before-startForeground, boot path with/without BT permission
- [ ] #2 Reconnect-on-disconnect behaviour test (may need the TASK-178 extraction)
- [ ] #3 Gradle tests green in CI (blocking per the CI ticket TASK-159)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add Robolectric test scaffolding for `PumpService` (channel created before `startForeground`, boot-receiver path with and without BT permission).
- Add a reconnect-on-disconnect behaviour test for `PumpCommHandler.onPumpDisconnected`, building on the TASK-178 extraction if needed.
- Verify: `flutter analyze` clean, `flutter test` green, `cd android && ./gradlew :app:testDebugUnitTest` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (test-quality finding 13)
- Effort: M
- Where: `android/app/src/test/`, `PumpService.kt`, `PumpCommHandler.kt`
- Related: TASK-12, TASK-178
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
