---
id: TASK-270
title: >-
  Two app-root snapshot-chain containment sub-tests are hollow and prove no
  containment
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 19:24'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 157000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-212 app_root_snapshot_chain_test.dart AC1 is strong (real DayHistoryController.ingestSnapshot failure, asserts the injected failure was hit before asserting the alert still fired), but two sub-tests are hollow. First, the widget AC2 test (pushUpdate throwing does not block the following ingest+alerts) calls the real HomeWidgetService().pushUpdate, which swallows everything in its own try/catch (TASK-208), via unawaited — the throw is doubly neutralised and nothing asserts the push was even attempted; the sole assertion (shown contains urgentLow) is independent of the widget path. Deleting the pushUpdate try/catch so a MissingPluginException propagates onto the pump-snapshot listener (re-introducing the TASK-208 bug) leaves this test green. Second, the AC3 Nightscout tests exercise NightscoutClient which catches everything in _postJson by design, so expectLater(completes) and the no-error-logged assertion are guaranteed by the internal swallow, not by any caller-side containment; they never exercise the app-root unawaitedLogged catchError they claim to pin, and they entrench a blanket catch that would hide a genuine upload/serialisation bug.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The widget containment test awaits (or otherwise observes) a throw from the push path and asserts it is contained without aborting ingest/alerts, so removing the pushUpdate try/catch turns it red
- [ ] #2 The Nightscout containment test exercises unawaitedLogged catchError (a path that actually fails at the app-root wrapper), not the client internal swallow
- [ ] #3 Both tests assert the sibling subsystems still ran, not just that the outer call completed
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-212)
- File: test/app_root_snapshot_chain_test.dart widget AC2 :150-167, Nightscout AC3 :171-215
- TASK-211 tests are meaningful (retry ordering + per-category isolation are load-bearing); AC1 here is the strongest test in either file
- Sibling to TASK-251 / TASK-257 (same hollow-containment-test class)
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
