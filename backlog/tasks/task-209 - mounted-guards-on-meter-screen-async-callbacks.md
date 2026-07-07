---
id: TASK-209
title: mounted guards on meter-screen async callbacks
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:11'
updated_date: '2026-07-07 18:21'
labels:
  - code-health
  - ui
milestone: m-8
dependencies: []
priority: medium
ordinal: 112300
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/glucose_meter_screen.dart:40` calls setState after `await transport.isAvailable()` without a mounted check, and the scan-result listener at `lib/glucose_meter_screen.dart:46` mutates state in onData unguarded (unlike lines 50/53 which do guard).

**Reason for change.** Leaving the screen mid-scan throws setState-after-dispose.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 mounted guards added to both call sites
- [x] #2 Widget test: dispose mid-scan, deliver a result, no error
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a mounted check after `await transport.isAvailable()` before setState
- Guard the scan-result onData listener the same way lines 50/53 already do
- Add a widget test that disposes the screen mid-scan, delivers a result, and asserts no error
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (dart finding 14)
- Effort: S
- Where: `lib/glucose_meter_screen.dart:40,46`
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 18:14
---
Started: add mounted guards at the two unguarded call sites in lib/ui/glucose_meter_screen.dart.
---

author: Claude
created: 2026-07-07 18:21
---
Done. Fixed the two named sites in lib/ui/glucose_meter_screen.dart: mounted guard after 'await transport.isAvailable()' before both the snackbar and the setState, and a mounted guard in the scan-result onData listener matching the existing onError/onDone pattern.

While writing the widget test (dispose mid-scan, then deliver a result) I found a worse pre-existing bug in the same class: dispose() called 'ref.read(glucoseMeterTransportProvider).stopScan()' directly, but flutter_riverpod throws 'Cannot use ref after the widget was disposed' unconditionally once dispose() runs (Element.mounted/context.mounted is already false by the time State.dispose() is invoked, per ConsumerStatefulElement's _assertNotDisposed check) -- confirmed via the riverpod 2.6.1 source. That meant every real navigation away from this screen threw, stopScan() never actually ran (so the native BLE scan kept going after the screen was gone), and super.dispose() never completed. Fixed by caching the transport in initState() so dispose() never touches ref.

Test: test/glucose_meter_screen_test.dart -- pushes the screen via a real Navigator (so ProviderScope survives, unlike a raw pumpWidget swap), starts a scan, pops the route mid-scan, then delivers a result on the fake transport's stream and asserts no exception. Verified this test actually fails on the unfixed dispose() (reproduced the StateError twice while diagnosing) before landing the fix.

Pipeline: flutter analyze clean, flutter test test/ 1006/1006, flutter build apk --debug succeeded. No native Kotlin touched, no user-visible behavior change -- no user-guide update.
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
