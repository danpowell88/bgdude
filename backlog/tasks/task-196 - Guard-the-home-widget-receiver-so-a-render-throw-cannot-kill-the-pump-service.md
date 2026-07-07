---
id: TASK-196
title: Guard the home-widget receiver so a render throw cannot kill the pump service
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:08'
updated_date: '2026-07-07 15:45'
labels:
  - code-health
  - native
  - ui
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 111000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `BgWidgetProvider` is a BroadcastReceiver with no `android:process` attribute (`android/app/src/main/AndroidManifest.xml:102-111`), so it runs in the same process as `PumpService`. `onUpdate`/`render` (`android/app/src/main/kotlin/com/bgdude/app/widget/BgWidgetProvider.kt:29-94`) have zero try/catch, and an uncaught exception escaping `onReceive` crashes the whole process — the BLE link and the native urgent-low backstop die with it.

Throw vectors:

- `data.getString(KEY_BG_TEXT, null)` throws ClassCastException if a non-String value is ever stored under the key
- `RemoteViews` construction / `updateAppWidget` can fail (TransactionTooLarge, resource failures)
- `HomeWidgetLaunchIntent.getActivity` can throw

**Reason for change.** A cosmetic widget render failure must never take down the pump service process that keeps the BLE link and safety backstop alive.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 render/onUpdate are wrapped; on failure the receiver pushes a minimal safe RemoteViews (or skips the update) and logs the error
- [x] #2 A test feeds a prefs double with a wrong-typed value and asserts no exception escapes onReceive
- [x] #3 `cd android && ./gradlew :app:testDebugUnitTest` green
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Wrap the `onUpdate`/`render` bodies in `BgWidgetProvider.kt` with try/catch around per-widget work
- On failure, push a minimal safe RemoteViews or skip the update, and log via the existing logging path
- Add a Robolectric test that stores a wrong-typed value under `KEY_BG_TEXT` and asserts `onReceive` does not throw
- Verify: `flutter analyze` clean, `flutter test` green.
- Verify native: `cd android && ./gradlew :app:testDebugUnitTest` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (native finding 1)
- Effort: S
- Where: `android/app/src/main/kotlin/com/bgdude/app/widget/BgWidgetProvider.kt`, `android/app/src/main/AndroidManifest.xml`
- Related: TASK-177 (widget staleness — different concern)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 15:38
---
Started: reviewing BgWidgetProvider.kt's onUpdate/render to wrap the throw vectors (bad prefs type, RemoteViews/updateAppWidget failure, launch-intent failure) so a render exception can't kill the shared pump-service process.
---

author: Claude
created: 2026-07-07 15:45
---
Guarded BgWidgetProvider using the existing SafeCallbacks helper (TASK-189's pattern for exactly this class of process-shared-with-PumpService risk), two layers deep: (1) the whole onReceive body is wrapped as the outermost backstop; (2) render() is wrapped individually with a fallback to a minimal static '--' RemoteViews built from fixed strings only (no prefs reads, so it can't hit the same failure modes); (3) each per-widgetId updateAppWidget() call is wrapped individually so one bad widget instance can't block the others. Verified the fallback-construction edge case: since SafeCallbacks.run(name, fallback, block)'s fallback arg is evaluated eagerly (before entering its own try/catch), a throw from building the fallback itself wouldn't be caught by that inner guard -- but it IS still caught by the outer onReceive-level guard, since renderSafely() executes inside that outer lambda. Added android/app/src/test/kotlin/com/bgdude/app/widget/BgWidgetProviderTest.kt (Robolectric, matching the BootReceiverTest pattern): stores a wrong-typed Int under BG_TEXT and a Boolean under TREND (SharedPreferences.getString's real ClassCastException trigger), asserts onReceive doesn't throw and that SafeCallbacks logged the render failure by name; a third case exercises the non-ACTION_REFRESH fallthrough. gradlew :app:testDebugUnitTest green (75 tests across 16 classes, 0 failures, including the new 3). flutter analyze clean, flutter test test/ green (951 tests), flutter build apk --debug succeeded. No user-visible/screen change -- DoD #6/#7 n/a.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
