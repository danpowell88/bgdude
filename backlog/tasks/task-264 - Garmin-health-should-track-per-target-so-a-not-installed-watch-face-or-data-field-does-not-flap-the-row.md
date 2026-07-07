---
id: TASK-264
title: >-
  Garmin health should track per-target so a not-installed watch face or data
  field does not flap the row
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 17:30'
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
- [ ] #1 Garmin health is tracked per target, or the aggregate treats an app-not-installed result as not-a-failure
- [ ] #2 A user with a single form factor installed sees a stable healthy row while delivery is working
- [ ] #3 Test: one success plus not-installed results does not mark the row failed
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-201)
- File: android/app/src/main/kotlin/com/bgdude/app/garmin/GarminSender.kt shared lastSuccessAtMs/consecutiveFailures across watchTargets
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
