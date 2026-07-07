---
id: TASK-266
title: >-
  Use a neutral unknown indicator not a green check for never-run subsystems on
  the system-health screen
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 17:30'
labels: []
milestone: m-8
dependencies: []
priority: low
ordinal: 720000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
On the system-health screen, when lastAttemptAt is null the subtitle says Never run yet but isUnhealthy is false, so the leading icon is a green check_circle_outline. Same for the Garmin Not available (demo mode) and no-send-attempted states. On a fresh install, or in demo mode where syncHealth is disabled, the screen is a wall of green checkmarks for subsystems that have never actually run. A green tick communicates healthy/verified, not unknown, which is false reassurance.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Never-run and not-available states render a neutral/unknown indicator distinct from the healthy green check
- [ ] #2 Demo mode does not present unrun subsystems as healthy
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-201)
- File: lib/ui/system_health_screen.dart:57,60,69 and the Garmin tile :118
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
