---
id: TASK-212
title: Failure-injection tests for the app-root snapshot chain
status: To Do
assignee: []
created_date: '2026-07-06 21:12'
labels:
  - code-health
  - testing
milestone: m-8
dependencies:
  - TASK-210
  - TASK-125
priority: medium
ordinal: 112600
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The chain `ingestSnapshot(...).then((_) => onSnapshot())` (`lib/app.dart:28-31`) saves to the repo BEFORE updating state (`lib/day_history_controller.dart:121`) — a repo throw silently skips alert evaluation and drops the reading. The chain is currently un-unit-testable because it lives inline in `BgDudeApp.build` (extraction is TASK-125).

**Reason for change.** The most safety-relevant pipeline in the app (reading ingest to alert evaluation) has zero failure-path coverage; a storage or plugin throw must not silently drop readings or skip alerts.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 With the TASK-125 seam plus FaultInjectingHistoryRepository: saveCgm throwing does not skip alert evaluation and the reading is not silently lost
- [ ] #2 A widget-channel throw (mock handler throwing PlatformException, pattern from `test/home_widget_service_glue_test.dart:24`) does not abort ingest/alerts
- [ ] #3 A Nightscout upload throw is contained
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Build on the TASK-125 extraction seam to construct the snapshot chain in a test
- Use `FaultInjectingHistoryRepository` to make saveCgm throw; assert alert evaluation still runs and the reading is not silently lost
- Add a widget-channel failure case using a mock handler throwing PlatformException (pattern from `test/home_widget_service_glue_test.dart:24`) and assert ingest/alerts continue
- Add a Nightscout upload throw case and assert it is contained
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (injection finding 17)
- Effort: L
- Where: `lib/app.dart:28-31`, `lib/day_history_controller.dart:121`, new test
- Related: TASK-125, TASK-181
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
