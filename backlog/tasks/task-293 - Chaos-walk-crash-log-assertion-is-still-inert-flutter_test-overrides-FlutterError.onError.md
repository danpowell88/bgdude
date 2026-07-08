---
id: TASK-293
title: >-
  Chaos-walk crash-log assertion is still inert -- flutter_test overrides
  FlutterError.onError
status: To Do
assignee:
  - Claude
created_date: '2026-07-08 03:31'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 156500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-257 tried to fix the vacuous chaos crash-log assertion by installing a chained FlutterError.onError + PlatformDispatcher.instance.onError in integration_test/harness.dart (_installCrashCapture, from setUpDemoHarness) that mirrors main.dart _captureCrash by writing appLog.error(crash, ...). It does not work: flutter_test binding saves the current handler and REPLACES FlutterError.onError with its own for the entire test body (flutter_test/src/binding.dart:1770-1773, restored only in postTest), and setUp runs before the test body, so the harness handler is always overridden. During the chaos walk a widget build/layout/gesture exception routes to the framework handler and _pendingExceptionDetails, never to appLog, and the only in-app writer of the crash tag (main.dart:27) is not installed because pumpDemoApp bypasses main(). So chaos_navigation_test.dart:132 expect(crashes, isEmpty) remains vacuously true and injecting a crash on a walked screen would NOT populate the crash signal -- AC#1 is checked but not actually met. NOTE the test is not fully blind: a genuine crash still turns it red via flutter_test own _pendingExceptionDetails to reportTestException path (binding.dart:1710), which the per-action catch(_) does not mask. The defect is that the ADDED crash-log assertion is a no-op and its comment misleadingly calls it the actual pass/fail signal.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The chaos walk fails on an injected build/null-deref via a mechanism that actually fires in the test binding -- assert tester.takeException() (per step or at end) so the framework-captured exception is surfaced explicitly
- [ ] #2 The misleading crash-tag assertion + comment are either made real (populated in-binding) or removed in favour of the takeException/framework-exception signal, so no future reader believes an inert check is the guard
- [ ] #3 Verified by injecting a deliberate crash on a walked screen and observing the test go red (the AC-3 empirical check that would have caught this)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 verifying the TASK-257 fix (2cdcbdb)
- Files: integration_test/harness.dart _installCrashCapture, integration_test/chaos_navigation_test.dart:130-134
- Root cause: setting FlutterError.onError in setUp does not survive into the flutter_test test body (framework overrides it); use tester.takeException instead
- Related: TASK-291 bounded the same file (orthogonal)
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test --coverage test/ green
- [ ] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [ ] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->
