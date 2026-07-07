---
id: TASK-184
title: Monotonic alert cooldowns (DST/clock-change safe)
status: Done
assignee:
  - Claude
created_date: '2026-07-06 09:19'
updated_date: '2026-07-06 22:38'
labels:
  - code-health
  - alerts
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 101300
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `AlertService._shouldFire` (`lib/state/providers.dart:1382-1390`) compares wall-clock `DateTime.now().difference(_lastFired)` — a DST fall-back makes the diff negative for an hour so urgent-low re-alerts are suppressed; a forward jump expires all cooldowns at once.

**Reason for change.** Alert cooldowns must not depend on wall-clock continuity; a suppressed urgent-low during the DST hour is a safety failure.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Cooldowns tracked via a monotonic source (`Stopwatch`/elapsedRealtime) or negative diffs clamped to eligible
- [x] #2 Clock-injection test crossing a backward jump asserts an urgent-low still re-fires
- [x] #3 The same treatment applied to `AlertMonitor` cooldowns
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 22:34
---
Started: extract a pure CooldownGate (negative elapsed => eligible, fail-open) used by AlertService._coolPassed; same clamp in AlertMonitor.cool; clock-injection tests crossing a backward jump assert urgent-low re-fires.
---

author: Claude
created: 2026-07-06 22:38
---
Done (commit 54086cc).
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
New CooldownGate (lib/alerts/alert_orchestrator.dart): per-category cooldown tracker where a NEGATIVE wall-clock elapsed (DST fall-back, manual clock change) is treated as eligible — fail open, so the worst case is one early re-alert, never a suppressed urgent low. AlertService._coolPassed/_markFired delegate to it; AlertMonitor.cool() got the identical clamp (AC#3). Clock-injection tests: backward jump re-fires urgent-low through both the gate and AlertMonitor.evaluate, forward jump expires (accepted fail-open), normal suppression preserved. Chose the clamp over a Stopwatch source: monotonic elapsedRealtime isn't available to pure Dart across process restarts anyway, and the clamp keeps the wrapper stateless per AC#1's allowance. Verified: analyze clean, 651 tests green, debug APK builds. Commit 54086cc.
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
