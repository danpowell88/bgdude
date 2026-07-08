---
id: TASK-264
title: >-
  Garmin health should track per-target so a not-installed watch face or data
  field does not flap the row
status: Done
assignee:
  - Claude
created_date: '2026-07-07 17:30'
updated_date: '2026-07-08 08:22'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 525000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
GarminSender sends to all three watchTargets (watch app, watch face, data field) and each per-app async callback writes the SHARED lastSuccessAtMs and consecutiveFailures. A typical user installs only one of the three form factors, so every send cycle produces one success plus two app-not-installed failures, and the final counter value depends purely on async callback ordering. Result: watch delivery is working perfectly for the one installed app, but the Garmin row on the system-health screen randomly shows red (failed N times in a row) whenever a failing callback resolves last. The indicator is unreliable for the common case and actively misleading on a health surface.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Garmin health is tracked per target, or the aggregate treats an app-not-installed result as not-a-failure
- [x] #2 A user with a single form factor installed sees a stable healthy row while delivery is working
- [x] #3 Test: one success plus not-installed results does not mark the row failed
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-201)
- File: android/app/src/main/kotlin/com/bgdude/app/garmin/GarminSender.kt shared lastSuccessAtMs/consecutiveFailures across watchTargets
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 08:11
---
Started. Investigated the Connect IQ SDK (javap on the cached ciq-companion-app-sdk-2.0.3 jar) to confirm the fix approach before writing: IQMessageStatus (SUCCESS, FAILURE_UNKNOWN, FAILURE_INVALID_FORMAT, FAILURE_MESSAGE_TOO_LARGE, FAILURE_UNSUPPORTED_TYPE, FAILURE_DURING_TRANSFER, FAILURE_INVALID_DEVICE, FAILURE_DEVICE_NOT_CONNECTED) has NO distinct "app not installed" value -- sendMessage alone cannot tell a genuine send failure from "this app isnt on the watch". There IS a separate getApplicationInfo() API with an onApplicationNotInstalled callback, but wiring an extra async pre-check round-trip per device per target before every send is a bigger, riskier change than AC number 1s own first option. Going with per-target tracking instead: GarminSender tracks lastSuccessAtMs/consecutiveFailures per watchTarget (keyed by applicationId) rather than one shared counter, and health() aggregates via lastSuccessAtMs = max across targets (most recent successful delivery to ANY installed target) and consecutiveFailures = min across targets (0 as long as at least one targets last attempt succeeded; only nonzero when EVERY target failed together, which is a real send-path problem, not "2 of 3 arent installed"). This directly matches the described symptom without needing the getApplicationInfo round-trip.
---

author: Claude
created: 2026-07-08 08:22
---
Done. GarminSender now tracks lastSuccessAtMs/consecutiveFailures per watchTarget (keyed by applicationId, lazily populated) instead of one shared counter; health() aggregates lastSuccessAtMs as the max across targets (most recent success on ANY target) and consecutiveFailures as the min (stays 0 as long as at least one target is currently succeeding, only nonzero when EVERY target fails together -- a real send-path problem, not "2 of 3 arent installed"). Non-per-target failures (the outer catch blocks, e.g. ciq.connectedDevices itself throwing before any per-app send was attempted) advance every targets streak together via recordSendFailureAllTargets, matching how a genuinely down send path should read. Real bug found and fixed while writing tests: my first implementation eagerly pre-populated the tracking map from watchTargets at construction (using IQApp.applicationId), which left a permanent stale zero-failure entry that could pollute the min-aggregate if a caller ever recorded through a key that did not exactly match those eager entries -- removed the eager pre-population entirely (lazy-only, populated the first time a key actually records an event), which also fixed a real test failure this exact mismatch caused under Robolectric. Rigor-checked: swapped minOfOrNull for maxOfOrNull, confirmed 2 of the 7 tests failed with the predicted symptom, reverted. Files: GarminSender.kt, GarminSenderTest.kt (5 new tests). Pipeline: analyze clean, gradlew :app:testDebugUnitTest green (7/7 in the affected file, full native suite green), apk debug build succeeds. No Dart files touched.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [x] #8 backlog item updated with comments
<!-- DOD:END -->
