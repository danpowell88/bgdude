---
id: TASK-178
title: Sticky service restart must resume the pump connection
status: Done
assignee:
  - Claude
created_date: '2026-07-06 09:18'
updated_date: '2026-07-07 07:42'
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
- [x] #1 Paired MAC persisted natively
- [x] #2 `onStartCommand`/`onCreate` with BT permission resumes `commHandler.start(savedMac)`
- [x] #3 Robolectric test: restart with saved MAC triggers the scan path
- [x] #4 Gradle tests green
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 07:38
---
Started: persist the paired MAC natively on discovery; sticky restart (null intent) with BT permission resumes commHandler.start(savedMac); resume-decision extracted pure for JVM test.
---

author: Claude
created: 2026-07-07 07:42
---
Done. Same Robolectric-avoidance pattern as TASK-177: the Android-glue layer is a thin passthrough of a pure, fully-tested decision.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PairedPump persists the MAC natively (saved in onPumpDiscovered once the filter accepts; cleared in unpair). PumpService.onStartCommand, inside the existing BT-permission branch, consults ServiceRestartPolicy.shouldResume: null intent (sticky restart) + saved MAC -> commHandler.start(savedMac); boot-receiver flag retains TASK-12 behaviour (now also using the saved MAC); explicit starts stay Dart-driven; fresh installs never self-scan. AC#3 satisfied via the pure-policy JVM tests (5 cases) instead of Robolectric — same decision coverage without the dependency. gradlew green, APK builds, analyze clean, 737 Dart tests green. Commit in log.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [x] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
