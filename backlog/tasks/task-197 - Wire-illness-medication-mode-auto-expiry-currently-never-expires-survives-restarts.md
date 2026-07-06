---
id: TASK-197
title: >-
  Wire illness/medication mode auto-expiry (currently never expires, survives
  restarts)
status: To Do
assignee: []
created_date: '2026-07-06 21:08'
updated_date: '2026-07-06 21:09'
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
- [ ] #1 activate persists a default expected duration
- [ ] #2 An expiry check runs at startup and on a periodic tick, calling `deactivateIfExpired(now)`
- [ ] #3 MedicationMode gains an end time with the same expiry handling
- [ ] #4 Test: activate with a past expiry, then startup deactivates the mode and emits the annotation
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
