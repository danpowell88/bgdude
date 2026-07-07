---
id: TASK-197
title: >-
  Wire illness/medication mode auto-expiry (currently never expires, survives
  restarts)
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:08'
updated_date: '2026-07-07 16:00'
labels:
  - code-health
  - insights
  - dosing-math
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 111100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `IllnessModeNotifier.activate` (`lib/providers.dart:882-889`) never passes `expectedDuration`; `deactivateIfExpired` (`lib/insights/illness_mode.dart:177-178`) has zero callers; `_restore` (`lib/providers.dart:869-875`) reloads `active=true` with no expiry check; and the startup pipeline has no expiry job. `MedicationMode` (`lib/providers.dart:940-972`) has no expiry field at all. `illness_mode.dart:48` documents an auto-expiry (so a forgotten mode does not inflate dosing for weeks) that was never wired.

**Reason for change.** A forgotten mode keeps multiplying resistance (up to 1.5x, confidence floored at 0.7) into the advisor and rescue-carb math indefinitely, across restarts.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 activate persists a default expected duration
- [x] #2 An expiry check runs at startup and on a periodic tick, calling `deactivateIfExpired(now)`
- [x] #3 MedicationMode gains an end time with the same expiry handling
- [x] #4 Test: activate with a past expiry, then startup deactivates the mode and emits the annotation
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Pass a default `expectedDuration` in `IllnessModeNotifier.activate` and persist it
- Add an expiry check at startup (after `_restore`) and on a periodic tick that calls `deactivateIfExpired(now)`
- Add an end-time field to `MedicationMode` and apply the same expiry handling
- Add a test that activates with a past expiry and asserts startup deactivation plus the emitted annotation
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (dart finding 2)
- Effort: M
- Where: `lib/providers.dart:869-972`, `lib/insights/illness_mode.dart`
- Related: TASK-124 (widget-policy refactor — different concern)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 15:46
---
Started: reviewing IllnessModeNotifier/MedicationModeNotifier in lib/state/providers.dart plus illness_mode.dart/medication_mode.dart to wire real auto-expiry (activate persists a default duration, startup + periodic expiry check calls deactivateIfExpired, MedicationMode gains an end time).
---

author: Claude
created: 2026-07-07 16:00
---
AC#1: IllnessModeNotifier.activate now always passes expectedDuration: IllnessMode.defaultExpectedDuration (new const, 7 days). AC#2: added AppJobs.checkModeExpiry() (calls both notifiers' deactivateIfExpired(now)), wired as an early StartupJob (before checkIllnessSuggestion, so a just-expired mode is already off by the time that gate reads it), PLUS a new ModeExpiryWatchdogService (mirrors the existing StaleDataWatchdogService pattern) with a 30-min Timer.periodic, instantiated unconditionally in BgDudeApp.build() (not gated on pump activity -- a forgotten mode must expire even with no pump connected). AC#3: MedicationMode gained expiresAt (+ defaultExpectedDuration=14 days, isExpired(), threaded through copyWith/toJson/fromJson) and MedicationModeNotifier gained deactivateIfExpired(now), same shape as illness's. AC#4: added 3 tests to restart_recovery_test.dart (new TASK-197 group) using the existing RestartSimulation harness -- pre-seed KvStore with an illness/medication mode whose expiresAt is already in the past (simulating an activation from days earlier), build a container, run AppJobs.checkModeExpiry(), and assert both the mode deactivates AND (for illness) lastDeactivationAnnotation is set with AnnotationKind.illness; a third test confirms a not-yet-expired mode survives the check untouched. Also added direct MedicationMode.isExpired unit tests. doc/user-guide.html's Medication/Illness sections now mention the auto-expiry. flutter analyze clean, flutter test test/ green (958 tests), flutter build apk --debug succeeded. No native Kotlin touched -- DoD #5 n/a; no new screen -- DoD #7 n/a. Filed TASK-258: while implementing this, found lastDeactivationAnnotation is set but never actually read/persisted anywhere in the codebase (a separate, pre-existing gap -- the illness annotation this whole mechanism exists to produce has never actually reached the retraining pipeline).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
