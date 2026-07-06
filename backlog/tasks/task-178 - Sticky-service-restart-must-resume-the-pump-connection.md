---
id: TASK-178
title: Sticky service restart must resume the pump connection
status: To Do
assignee: []
created_date: '2026-07-06 09:18'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - native
  - pump
milestone: m-4
dependencies: []
priority: medium
ordinal: 108000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `PumpService.onStartCommand` (`PumpService.kt:59-74`) returns `START_STICKY` but on a system restart (null intent) only re-foregrounds — scanning starts exclusively from the Dart `startScan` channel (`PumpBridge.kt:71-78`) and no MAC is persisted natively, so a service-only restart leaves the pump disconnected until the user opens the app.

**Reason for change.** The sticky restart currently restores the notification but not the connection; overnight kills silently end monitoring.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Paired MAC persisted natively
- [ ] #2 `onStartCommand`/`onCreate` with BT permission resumes `commHandler.start(savedMac)`
- [ ] #3 Robolectric test: restart with saved MAC triggers the scan path
- [ ] #4 Gradle tests green
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Persist the paired MAC natively (SharedPreferences) when pairing/connecting succeeds.
- On sticky restart (null intent) with BT permission granted, resume `commHandler.start(savedMac)`.
- Add a Robolectric test asserting the restart-with-saved-MAC path triggers scanning.
- Verify: `flutter analyze` clean, `flutter test` green, `cd android && ./gradlew :app:testDebugUnitTest` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (reliability finding 4)
- Effort: M
- Where: `PumpService.kt`, `PumpBridge.kt`, `PumpCommHandler.kt`
- Related: TASK-12 (boot path), TASK-95
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
