---
id: TASK-184
title: Monotonic alert cooldowns (DST/clock-change safe)
status: To Do
assignee: []
created_date: '2026-07-06 09:19'
labels:
  - code-health
  - alerts
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 184000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `AlertService._shouldFire` (`lib/state/providers.dart:1382-1390`) compares wall-clock `DateTime.now().difference(_lastFired)` — a DST fall-back makes the diff negative for an hour so urgent-low re-alerts are suppressed; a forward jump expires all cooldowns at once.

**Reason for change.** Alert cooldowns must not depend on wall-clock continuity; a suppressed urgent-low during the DST hour is a safety failure.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Cooldowns tracked via a monotonic source (`Stopwatch`/elapsedRealtime) or negative diffs clamped to eligible
- [ ] #2 Clock-injection test crossing a backward jump asserts an urgent-low still re-fires
- [ ] #3 The same treatment applied to `AlertMonitor` cooldowns
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Switch `AlertService._shouldFire` to a monotonic elapsed source (or clamp negative wall-clock diffs to eligible).
- Apply the same change to `AlertMonitor` cooldowns.
- Add a clock-injection test crossing a backward jump asserting urgent-low re-fires.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (reliability finding 10)
- Effort: M
- Where: `lib/state/providers.dart`
- Related: TASK-39 enables the test
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
