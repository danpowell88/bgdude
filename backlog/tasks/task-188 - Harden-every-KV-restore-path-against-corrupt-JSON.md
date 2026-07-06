---
id: TASK-188
title: Harden every KV restore path against corrupt JSON
status: To Do
assignee: []
created_date: '2026-07-06 12:55'
labels:
  - code-health
  - data-integrity
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 188000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Every persisted-state `_restore()` in `lib/state/providers.dart` decodes its KV blob with zero guarding — verified at lines 125 (NotificationPrefs), 278 (UserProfile), 306 (AlertThresholds), 423 (TherapySettings), 950 (MedicationMode), 1024 (WeatherSettings), 1210 (SavedMeal), 1280 — pattern: `state = X.fromJson(jsonDecode(raw) as Map<String, dynamic>)`. A truncated or corrupt value throws an uncaught async error from the constructor-launched restore and the notifier silently keeps defaults.

**Reason for change.** For `TherapySettings` this is clinical: a corrupt blob means the app silently runs on default ISF/CR/targets and every dose suggestion is wrong with no indication. Corruption must be loud and recovery deliberate.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each restore path catches decode/shape errors, logs loudly, and falls back to defaults explicitly
- [ ] #2 For TherapySettings and AlertThresholds a user-visible banner/notice states that settings were reset and need review
- [ ] #3 The corrupt raw value is preserved under a quarantine key for diagnosis, not overwritten
- [ ] #4 Test: corrupt JSON in KV for each notifier → no uncaught error, defaults active, log entry present
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a shared guarded-decode helper (fits naturally into the TASK-35 `PersistedStateNotifier` base; coordinate).
- Sweep the 8+ restore sites onto it; keep per-type defaults explicit.
- Quarantine the bad raw value under `<key>.corrupt` before resetting.
- Add the safety banner for therapy/threshold resets.
- Table-driven test with corrupted payloads per notifier.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep 2026-07-06 (verified: all restore decodes unguarded)
- Effort: M
- Where: lib/state/providers.dart:122-128, 275-281, 303-309, 420-426, 947-953, 1021-1027, 1207-1213, 1277-1283
- Related: TASK-35 (base class should own this), TASK-38, TASK-128 (same hardening for the model blob)
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
