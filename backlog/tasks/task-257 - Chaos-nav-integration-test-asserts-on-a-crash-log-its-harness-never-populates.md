---
id: TASK-257
title: Chaos-nav integration test asserts on a crash log its harness never populates
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 15:26'
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
- [ ] #1 The chaos walk fails when a screen it reaches throws or logs a crash (install main()'s error handlers in the harness, or assert on tester.takeException / framework exceptions)
- [ ] #2 The per-action catch (_) does not mask a genuine app crash from the pass/fail signal
- [ ] #3 The test is actually executed on a device and observed to fail when a deliberate crash is injected
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-195)
- Files: integration_test/chaos_navigation_test.dart, integration_test/harness.dart, lib/main.dart:27
- Sibling to TASK-251 (hollow restart-test assertions) — same class of always-green test
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
