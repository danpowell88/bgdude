---
id: TASK-293
title: >-
  Chaos-walk crash-log assertion is still inert -- flutter_test overrides
  FlutterError.onError
status: Blocked
assignee:
  - Claude
created_date: '2026-07-08 03:31'
updated_date: '2026-07-08 03:40'
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
- [x] #1 The chaos walk fails on an injected build/null-deref via a mechanism that actually fires in the test binding -- assert tester.takeException() (per step or at end) so the framework-captured exception is surfaced explicitly
- [x] #2 The misleading crash-tag assertion + comment are either made real (populated in-binding) or removed in favour of the takeException/framework-exception signal, so no future reader believes an inert check is the guard
- [ ] #3 Verified by injecting a deliberate crash on a walked screen and observing the test go red (the AC-3 empirical check that would have caught this)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 verifying the TASK-257 fix (2cdcbdb)
- Files: integration_test/harness.dart _installCrashCapture, integration_test/chaos_navigation_test.dart:130-134
- Root cause: setting FlutterError.onError in setUp does not survive into the flutter_test test body (framework overrides it); use tester.takeException instead
- Related: TASK-291 bounded the same file (orthogonal)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 03:36
---
Started: confirmed the finding is correct -- flutter_test's TestWidgetsFlutterBinding overrides FlutterError.onError for the whole test body, restored only at postTest, so setUp-installed handlers never fire during the actual chaos walk. Replacing with tester.takeException() (the framework's own supported mechanism) and removing the now-proven-inert chained-handler wiring.
---

author: Claude
created: 2026-07-08 03:40
---
Fixed AC#1/#2 with real code changes; AC#3 (empirical on-device verification) partially addressed -- see below.

AC#1/#2: removed the inert chained-FlutterError.onError/appLog machinery from integration_test/harness.dart entirely (setUpDemoHarness is back to just KvStore.useMemory()). chaos_navigation_test.dart now calls tester.takeException() after every step (not just at the end, since the framework only holds ONE pending exception at a time -- checking per-step means an early crash cannot be silently overwritten by a later one) and once more after the trailing cleanup, fail()-ing with a message naming the exact step/action. Confirmed by reading flutter_test's actual binding.dart source (packages/flutter_test/lib/src/binding.dart:1632 takeException, :1705 the end-of-test auto-report path, :1770 the test-body FlutterError.onError override) that this is the framework's real, supported mechanism -- not a guess.

AC#3 partial: cannot run chaos_navigation_test.dart itself on-device in this session (no working local emulator). Instead wrote two throwaway (uncommitted, deleted after) PLAIN flutter_test widget tests -- IntegrationTestWidgetsFlutterBinding is a subclass of the same TestWidgetsFlutterBinding that implements takeException/FlutterError.onError override, so this exercises the identical underlying mechanism and runs locally with no device: (1) a widget that throws during build -- confirmed takeException() captures it AND the throw is never rethrown to the caller (so the per-action catch(_) can't mask it); (2) replicated TASK-257's exact setUp-installed FlutterError.onError chain -- confirmed empirically that it captures NOTHING during the test body (proving the TASK-293 root-cause diagnosis directly, not just by reading source). Both ran clean, then were deleted (git status confirmed no leftover files).

Staying Blocked, not Done: this proves the MECHANISM works, not that chaos_navigation_test.dart itself goes red on an injected crash on a real device, which is what AC#3 literally asks for. Needs a session with working local emulator access (or another CI dispatch cycle with a deliberately-broken temp state pushed and reverted, which carries the same elevated risk/cost noted on TASK-257/291) to fully close.

Verified: flutter analyze clean, flutter test test/ green (1158, unaffected -- integration_test/-only change), flutter build apk --debug succeeds. No native/user-guide changes.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test --coverage test/ green
- [x] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [ ] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->
