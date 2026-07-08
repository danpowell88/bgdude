---
id: TASK-238
title: 'Native follow-ups: widget unit fallback + restart-policy parameter honesty'
status: Done
assignee:
  - Claude
created_date: '2026-07-07 07:48'
updated_date: '2026-07-08 02:37'
labels:
  - code-health
  - native
  - cleanup
milestone: m-8
dependencies: []
priority: low
ordinal: 113248
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Two small carry-forwards from the native landings:

- `WidgetNativePush.push` (`WidgetNativePush.kt:38-44`, 95ceaf8) reads the display unit that only Dart ever writes; on a cold sticky-restart where UNIT was never persisted, an mg/dL user gets a mmol-formatted widget value — the one spot where the advertised native/Dart formatting parity can silently diverge.
- `ServiceRestartPolicy.hasBluetoothPermission` is hard-coded `true` at its only production call site (`PumpService.kt:87`, 522be09), so the policy branch is dead in production and its test proves a path the app never takes.

**Reason for change.** Both are one-line honesty fixes that keep the new native code meaning what it says.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 UNIT persisted (or sourced) natively so the fallback cannot misformat
- [x] #2 The real permission value passed (or the parameter removed)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Persist UNIT from the native push path; pass `hasBluetoothPermission(this)`.
- Adjust tests accordingly.
- Verify: `gradlew :app:testDebugUnitTest` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: hourly quality check 2026-07-07 #3 (findings 4+5)
- Effort: S
- Where: android/.../widget/WidgetNativePush.kt:38-44, android/.../pump/PumpService.kt:87
- Related: TASK-177, TASK-178
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 02:28
---
Started: (1) WidgetNativePush.push UNIT fallback -- investigating whether to persist the unit natively or source it from an already-native-visible value; (2) PumpService.kt:87 hasBluetoothPermission hard-coded true -- passing the real permission check.
---

author: Claude
created: 2026-07-08 02:37
---
Fixed both:

AC#1 (UNIT fallback): added HomeWidgetService.seedUnit(), which persists just the bg_unit key to the home_widget SharedPreferences store immediately -- independent of any pump snapshot, unlike setUnit()/pushUpdate() which only write it as a side effect of formatting a full snapshot. Wired homeWidgetServiceProvider to call it at construction (reading the current glucoseUnitProvider value), and forced eager construction in BgDudeApp.build() (ref.read(homeWidgetServiceProvider), mirroring the existing modeExpiryWatchdogProvider pattern) so it runs at app boot rather than lazily on the first snapshot. This closes the gap where WidgetNativePush.push (which can run with no Flutter engine alive) found no stored unit and silently defaulted to mmol.

AC#2 (permission honesty): PumpService.kt:91 now passes hasBluetoothPermission(this) instead of a hard-coded true. Behaviourally identical today (the call is already inside the enclosing hasBluetoothPermission(this) branch), but it's a real check instead of a literal that would silently go stale if that guard ever changed -- and ServiceRestartPolicyTest's existing hasBluetoothPermission=false test case now documents a branch a future call site could actually exercise, not a permanently dead one.

Added 3 new tests in test/home_widget_service_glue_test.dart (seedUnit persists just the unit key with no snapshot; a later pushUpdate overwrites the seed as normal; a MissingPluginException from seedUnit is logged not thrown). Rigor check: temporarily made seedUnit a no-op, reran -- 2 of the 3 new tests failed as predicted, reverted (git diff confirmed clean).

Verified: flutter analyze clean, flutter test --coverage green (1153 tests, 67.54% >= 65% floor), build_runner clean (no generated-file diffs), flutter build apk --debug succeeds, gradlew :app:testDebugUnitTest green. No user-guide update needed (internal reliability fix, no new user-visible surface).
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
