---
id: TASK-302
title: >-
  Range-clamp persisted decoder numerics on restore -- esp. AlertThresholds
  mg/dL
status: To Do
assignee:
  - Claude
created_date: '2026-07-08 08:27'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 121000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The TASK-255 corpus extension surfaced that the persisted-store decoders behind restoreJsonGuarded (AlertThresholds, UserProfile, WeatherSettings, NotificationPrefs, etc. in providers.dart) apply NO numeric range validation on decode -- they pass values straight through. AlertThresholds.fromJson (alert_thresholds.dart) wraps low/high/urgentLow directly in Mgdl() with no clamp. So a corrupt or tampered stored blob with a parseable-but-out-of-range value (e.g. urgentLowMgdl = -5, lowMgdl = 1.79e308) survives restore intact, and the only invariant the corpus can assert today is isFinite (which 1.79e308 passes). This is safety-adjacent: AlertThresholds drives real-time alert firing, so a corrupt low/urgent-low line could suppress a genuine low-glucose alert or fire spuriously. The corpus honestly documents this as a scoped-out follow-up (test asserts what the code guarantees today). This mirrors the PumpSnapshot glucose/dosing hardening (TASK-273) and the reject-zero-ISF/CR validation (TASK-190) -- decode-boundary defense-in-depth against a corrupt persisted value.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 AlertThresholds.fromJson rejects or clamps out-of-physiological-range low/high/urgentLow to safe values (or treats a corrupt triple as absent -> fall back to defaults), so a corrupt stored threshold cannot silently drive alert firing
- [ ] #2 The other restoreJsonGuarded decoders with bounded numerics (UserProfile, WeatherSettings, etc.) clamp/validate to their sensible ranges on decode
- [ ] #3 The hostile-input corpus asserts the clamped/rejected range invariant (not just isFinite) for these fields
- [ ] #4 Fix the vacuous MedicationMode corpus assertion (the hostileTimestampVariants loop asserts anyOf(returnsNormally, throwsA(anything)), a tautology) so it asserts a real invariant like the first loop
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-255; surfaced while verifying the corpus extension)
- Files: lib/insights/alert_thresholds.dart fromJson (Mgdl() wrap, no clamp), other restoreJsonGuarded sites in lib/state/providers.dart; test/pump/hostile_input_corpus_test.dart MedicationMode timestamp loop
- Precedent: TASK-273 (PumpSnapshot glucose/dosing clamp-or-absent), TASK-190 (reject zero ISF/CR at the boundary)
- Safety: AlertThresholds feeds AlertMonitor real-time low/high/urgent-low firing
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test --coverage test/ green
- [ ] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [ ] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->
