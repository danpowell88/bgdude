---
id: TASK-302
title: >-
  Range-clamp persisted decoder numerics on restore -- esp. AlertThresholds
  mg/dL
status: Done
assignee:
  - Claude
created_date: '2026-07-08 08:27'
updated_date: '2026-07-08 08:37'
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
- [x] #1 AlertThresholds.fromJson rejects or clamps out-of-physiological-range low/high/urgentLow to safe values (or treats a corrupt triple as absent -> fall back to defaults), so a corrupt stored threshold cannot silently drive alert firing
- [x] #2 The other restoreJsonGuarded decoders with bounded numerics (UserProfile, WeatherSettings, etc.) clamp/validate to their sensible ranges on decode
- [x] #3 The hostile-input corpus asserts the clamped/rejected range invariant (not just isFinite) for these fields
- [x] #4 Fix the vacuous MedicationMode corpus assertion (the hostileTimestampVariants loop asserts anyOf(returnsNormally, throwsA(anything)), a tautology) so it asserts a real invariant like the first loop
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-255; surfaced while verifying the corpus extension)
- Files: lib/insights/alert_thresholds.dart fromJson (Mgdl() wrap, no clamp), other restoreJsonGuarded sites in lib/state/providers.dart; test/pump/hostile_input_corpus_test.dart MedicationMode timestamp loop
- Precedent: TASK-273 (PumpSnapshot glucose/dosing clamp-or-absent), TASK-190 (reject zero ISF/CR at the boundary)
- Safety: AlertThresholds feeds AlertMonitor real-time low/high/urgent-low firing
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 08:28
---
Started. Precedent: TASK-273s pump_snapshot.dart _rejectOutOfRangeDouble/_rejectOutOfRangeInt -- for glucose/dosing-adjacent fields, REJECT out-of-range to null/default rather than clamp, since clamping a corrupt -5 mg/dL to a plausible-looking 40 could suppress or misfire a real alert; clamping is only safe where "more alarming" is the failure direction (battery/reservoir toward 0). Applying the same reject-to-default pattern across all the flagged decoders: AlertThresholds low/high/urgentLow (top-level and per-segment) reject out-of-band [20,600] mg/dL (reusing pump_snapshot.darts own cgmMgdl band) back to the class default rather than a fabricated threshold; UserProfile birthYear/diagnosisYear/weightKg/heightCm reject to null for an implausible human value; WeatherSettings lat/lon reject to null outside valid geo range; NotificationPrefs repeatMinutes/QuietHours start-end reject negative/out-of-day-range to their defaults; SystemHealthReport consecutiveFailures rejects negative to 0. AC number 4 (the vacuous MedicationMode timestamp-loop assertion I wrote in TASK-255) also being fixed in the same pass.
---

author: Claude
created: 2026-07-08 08:37
---
Done. AC number 1: AlertThresholds (top-level and per-segment AlertBand) rejects an out-of-[20,600]mg/dL low/high/urgentLow back to the shipped default/all-day-row fallback via a shared _sanitizeMgdl helper, matching TASK-273s reject-not-clamp precedent exactly (a corrupt -5 clamped to 20 would still be a plausible-looking, actionable threshold). AC number 2: UserProfile birthYear/diagnosisYear (1900-2100), weightKg (1-500), heightCm (30-300) reject to null; WeatherSettings lat (-90..90)/lon (-180..180) reject to null; NotificationPrefs repeatMinutes/QuietHours startMinute/endMinute (0-1440) reject to default via a shared _sanitizeMinutesOfDay; SystemHealthReports consecutiveFailures clamps negative to 0. AC number 3: the hostile-input corpus now asserts each real range invariant (inInclusiveRange(...)) instead of only isFinite -- verified locally, all 289 corpus tests pass. AC number 4: fixed the vacuous MedicationMode timestamp-loop assertion (anyOf(returnsNormally, throwsA(anything)) was a tautology) -- verified empirically it deterministically throws a TypeError (the int-for-String cast fails before DateTime.parse is ever reached) and asserted that specifically. Rigor-checked the AlertThresholds fix: temporarily disabled _sanitizeMgdl (fell back to only the null-coalesce), confirmed 6 tests failed with the predicted symptom (huge/negative values passing straight through), reverted, confirmed clean. Pipeline green: analyze clean, 1317/1317 tests pass, coverage 68.00% (was 67.95%, floor 65%), apk debug build succeeds. No native Kotlin touched.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test --coverage test/ green
- [x] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [x] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [x] #9 backlog item updated with comments
<!-- DOD:END -->
