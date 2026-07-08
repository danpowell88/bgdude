---
id: TASK-270
title: >-
  Two app-root snapshot-chain containment sub-tests are hollow and prove no
  containment
status: Done
assignee:
  - Claude
created_date: '2026-07-07 19:24'
updated_date: '2026-07-08 03:14'
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
- [x] #1 The widget containment test awaits (or otherwise observes) a throw from the push path and asserts it is contained without aborting ingest/alerts, so removing the pushUpdate try/catch turns it red
- [x] #2 The Nightscout containment test exercises unawaitedLogged catchError (a path that actually fails at the app-root wrapper), not the client internal swallow
- [x] #3 Both tests assert the sibling subsystems still ran, not just that the outer call completed
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-212)
- File: test/app_root_snapshot_chain_test.dart widget AC2 :150-167, Nightscout AC3 :171-215
- TASK-211 tests are meaningful (retry ordering + per-category isolation are load-bearing); AC1 here is the strongest test in either file
- Sibling to TASK-251 / TASK-257 (same hollow-containment-test class)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 03:08
---
Started: reading test/app_root_snapshot_chain_test.dart's widget AC2 and Nightscout AC3 sub-tests plus app.dart's actual containment wiring to design real, load-bearing assertions.
---

author: Claude
created: 2026-07-08 03:14
---
Fixed both hollow sub-tests:

AC1 (widget containment): added a new test that AWAITS HomeWidgetService().pushUpdate directly (unlike app.dart's unawaited() call) so the test actually observes what happens to the injected MissingPluginException, and asserts an error was logged. Kept the original unawaited-structural test separately, now correctly framed as testing structure only (unawaited() can never block by definition, regardless of what's inside).

AC2 (Nightscout wrapper vs client swallow): the old test only ever exercised NightscoutClient._postJson's internal try/catch (a throwing http client), which fires before unawaitedLogged's catchError could ever see anything -- so it never actually pinned the app-root wrapper. Replaced with a CgmSample(mgdl: double.nan) case: entryFromCgm's sample.mgdl.round() throws UnsupportedError inside uploadEntries' own List.map, BEFORE _postJson is ever reached -- a genuine caller-side serialisation bug reaching unawaitedLogged's catchError for real. Kept the original http-throw test too, now correctly labeled as testing the client's OWN internal swallow, distinct from the wrapper.

AC3 (sibling subsystem, not just outer completion): added a third Nightscout test using the same build()/urgentLow-alert harness as AC1/AC2 -- fires the throwing (NaN) upload unawaited, then confirms ingestThenEvaluateAlerts still completes and the urgentLow notification still fires, proving the independent ingest+alerts subsystem is unaffected rather than just checking the upload call didn't hang.

Rigor check (both fixes): (1) temporarily disabled HomeWidgetService.pushUpdate's try/catch (if(true)/else-if(false) swap since it's the whole block) -- both AC2 tests correctly failed with the raw MissingPluginException. (2) temporarily removed unawaitedLogged's catchError -- both new/rewritten AC3 tests correctly failed with the raw UnsupportedError. Reverted both; git diff on lib/ is clean.

Verified: flutter analyze clean, flutter test --coverage green (1158 tests, 67.59% >= 65% floor), flutter build apk --debug succeeds. No native/user-guide changes (test-only).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
