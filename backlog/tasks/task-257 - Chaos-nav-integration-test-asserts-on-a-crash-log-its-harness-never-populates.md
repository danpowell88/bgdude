---
id: TASK-257
title: Chaos-nav integration test asserts on a crash log its harness never populates
status: Blocked
assignee:
  - Claude
created_date: '2026-07-07 15:26'
updated_date: '2026-07-08 03:07'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 156000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The chaos-navigation integration test pass/fail signal is expect(crashes, isEmpty) where crashes = appLog entries tagged crash. But the only writer of the crash tag is _captureCrash at lib/main.dart:27, wired exclusively inside main() via FlutterError.onError, PlatformDispatcher.instance.onError and runZonedGuarded. The integration harness pumpDemoApp (integration_test/harness.dart) bypasses main() entirely and calls tester.pumpWidget directly, so none of those handlers are installed and nothing can ever populate a crash entry. The assertion is vacuously true. Compounding it, each navigation action is wrapped in catch (_) that swallows exceptions, and the commit message states the test has never actually run. A real null-deref or build exception on any screen reachable by the walk would still pass green.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The chaos walk fails when a screen it reaches throws or logs a crash (install main()'s error handlers in the harness, or assert on tester.takeException / framework exceptions)
- [ ] #2 The per-action catch (_) does not mask a genuine app crash from the pass/fail signal
- [ ] #3 The test is actually executed on a device and observed to fail when a deliberate crash is injected
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-195)
- Files: integration_test/chaos_navigation_test.dart, integration_test/harness.dart, lib/main.dart:27
- Sibling to TASK-251 (hollow restart-test assertions) — same class of always-green test
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 03:03
---
Started: reading lib/main.dart's crash-handler wiring and integration_test/harness.dart's pumpDemoApp to figure out how to make the chaos walk's crash detection real instead of vacuous.
---

author: Claude
created: 2026-07-08 03:07
---
AC#1 done: integration_test/harness.dart's setUpDemoHarness now installs a chained (not replacing) FlutterError.onError + PlatformDispatcher.instance.onError handler pair that mirrors main.dart's _captureCrash -- appLog.error('crash', ...) on any framework/platform-dispatcher error, exactly the tag chaos_navigation_test.dart's assertion already checks. Guarded by a one-time install flag since these are process-global statics and pumpDemoApp/setUpDemoHarness can run many times per file (e.g. app_test.dart's 13 tests) -- re-wrapping every call would chain handlers ever deeper. Also clears appLog per-test so an earlier testWidgets block's entries can't leak into a later one's crash-log assertion.

AC#2 reasoning (no code change needed): Flutter's framework catches build/layout/gesture-handler exceptions internally and routes them through FlutterError.onError WITHOUT rethrowing synchronously to the caller -- so a genuine app crash from a widget the chaos walk navigates into never reaches the loop's own try/catch at all; only test-side finder issues (0/multiple widgets found, index-out-of-range from a rebuild race) do, which is exactly the 'expected hazard of a random walk' class the existing catch (_) was scoped for. AC#1's fix makes the crash-log channel real and INDEPENDENT of that per-action catch, so the two don't conflict.

AC#3 NOT verified -- staying Blocked, not guessing. Proving 'the test fails when a deliberate crash is injected' properly needs either local emulator access (fast inject/dispatch/revert iteration) this session doesn't have, or pushing a deliberately-broken temp-bug to main for a ~15-45 min CI dispatch cycle (twice, to prove both the fail and the revert-to-pass), which is a real elevated risk/cost this session's established local-revert-before-commit practice was specifically designed to avoid. Leaving for a session with working local emulator connectivity, matching the TASK-31/33/220/226/127 convention.

Verified (what CAN run here): flutter analyze clean, flutter test test/ green (1156, harness.dart isn't test/-scoped so unaffected but confirms nothing else broke), flutter build apk --debug succeeds. No native Kotlin, no user-guide update (test-infra-only change).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
