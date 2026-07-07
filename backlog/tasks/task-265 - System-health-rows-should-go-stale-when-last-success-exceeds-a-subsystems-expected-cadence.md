---
id: TASK-265
title: >-
  System-health rows should go stale when last-success exceeds a subsystems
  expected cadence
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 17:30'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 530000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
SubsystemHealth.isUnhealthy is consecutiveFailures > 0 OR (attempted AND never succeeded). There is no time-since-last-success threshold anywhere. Failure scenario: a WorkManager or periodic job (health sync, reconciliation) stops being scheduled after an OS kill or a cancelled job — it neither succeeds nor throws, so nothing is recorded and the row shows a green check with Last success 6d ago indefinitely. Silent cessation is the most common and most dangerous background-failure mode and is exactly what a health screen exists to catch, yet it is invisible. The user guide currently only promises red-on-failure (which is accurate to the code), so this is an enhancement to detect silent stalls, not a doc mismatch.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each subsystem has an expected cadence and its row goes stale/amber when last-success exceeds it, even with zero recorded failures
- [ ] #2 The cadence thresholds match each subsystems real schedule (not a single global value)
- [ ] #3 User guide updated to describe the stale/amber state
- [ ] #4 Test: a subsystem with an old last-success and no recent attempt reads stale, not healthy
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-201)
- File: lib/insights/system_health.dart:60 isUnhealthy
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
