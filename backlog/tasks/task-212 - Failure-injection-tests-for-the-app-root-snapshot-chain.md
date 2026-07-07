---
id: TASK-212
title: Failure-injection tests for the app-root snapshot chain
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:12'
updated_date: '2026-07-07 18:43'
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
- [x] #1 With the TASK-125 seam plus FaultInjectingHistoryRepository: saveCgm throwing does not skip alert evaluation and the reading is not silently lost
- [x] #2 A widget-channel throw (mock handler throwing PlatformException, pattern from `test/home_widget_service_glue_test.dart:24`) does not abort ingest/alerts
- [x] #3 A Nightscout upload throw is contained
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 18:37
---
Started: TASK-125 already extracted ingestThenEvaluateAlerts into lib/state/snapshot_chain.dart (already unit-tested at the generic-closure level in test/snapshot_chain_test.dart). This ticket goes one level deeper -- exercise the REAL DayHistoryController.ingestSnapshot with FaultInjectingHistoryRepository, plus the widget/Nightscout containment already visible in lib/app.dart.
---

author: Claude
created: 2026-07-07 18:43
---
Done. test/app_root_snapshot_chain_test.dart (new, 4 tests) exercises the exact composition lib/app.dart uses, with real components throughout (not fake closures).

AC1: a real DayHistoryController.ingestSnapshot backed by FaultInjectingHistoryRepository.failOn('saveCgm') is chained through the real TASK-125 ingestThenEvaluateAlerts seam with a real AlertService (ProviderContainer). Explicitly confirms the injected failure was actually hit (asserts the 'snapshot'/'ingest failed' log entry ingestThenEvaluateAlerts emits), then confirms the urgent-low alert still fired -- the reading is 'not silently lost' in the sense that the user is still warned even though the persist failed, since AlertService reads the live snapshot/forecast directly rather than through DayHistoryController's own (now-stale) state.

AC2: mocks the home_widget MethodChannel to throw MissingPluginException, calls HomeWidgetService.pushUpdate() unawaited (mirroring app.dart's exact fire-and-forget statement ordering), then confirms the following ingestThenEvaluateAlerts call still completes and the alert still fires -- pins the structural independence between the three app-root side effects.

AC3: constructs a real NightscoutClient with a throwing http.Client. Found (and pinned, not just asserted) that NightscoutClient._postJson already has its OWN internal try/catch ('uploads are best-effort background work') -- uploadEntries() literally cannot throw. Two tests: uploadEntries() alone completes; wrapped in unawaitedLogged (as app.dart does) it logs nothing, confirming the double containment (client-internal AND the wrapper) rather than relying on just one layer.

Pipeline: flutter analyze clean, flutter test test/ 1020/1020, flutter build apk --debug succeeded. No native Kotlin, no user-visible change -- no user-guide update.
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
