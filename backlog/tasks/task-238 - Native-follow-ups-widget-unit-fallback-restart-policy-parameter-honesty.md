---
id: TASK-238
title: 'Native follow-ups: widget unit fallback + restart-policy parameter honesty'
status: To Do
assignee: []
created_date: '2026-07-07 07:48'
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
- [ ] #1 UNIT persisted (or sourced) natively so the fallback cannot misformat
- [ ] #2 The real permission value passed (or the parameter removed)
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

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
