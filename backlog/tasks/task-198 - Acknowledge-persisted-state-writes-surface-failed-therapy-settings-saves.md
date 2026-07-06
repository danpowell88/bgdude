---
id: TASK-198
title: Acknowledge persisted-state writes; surface failed therapy-settings saves
status: To Do
assignee: []
created_date: '2026-07-06 21:09'
labels:
  - code-health
  - data-integrity
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 111200
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `PersistedStateNotifier.persist` sets `state = value` BEFORE `await store(value)` (`lib/persisted_state_notifier.dart:45-49`); `lib/settings/therapy_settings_screen.dart:66-68` calls `.save(...)` un-awaited and un-caught with the dialog already closed; and `KvStore.setString` (`lib/kv_store.dart:34-41`) never checks the write result. A failed encrypted write (locked storage, disk pressure) shows as saved in the UI, the session uses the new ISF/CR, then it silently reverts on restart — a dosing-relevant regression the user believes they changed.

- Same pattern on alert thresholds, profile, weather, and the `unawaited(_persist())` modes (`lib/providers.dart:888`, meal library `lib/providers.dart:1232,1242`)

**Reason for change.** Dosing-relevant settings must not silently revert; failed saves need to be visible to the user at save time.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `persist` awaits the store and signals failure to the caller
- [ ] #2 The therapy save path awaits and catches, showing a could-not-save error with the form still recoverable
- [ ] #3 Failures from unawaited mode persists are at least logged
- [ ] #4 Test: a throwing store causes the caller to observe failure, and the state is not treated as persisted
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Change `PersistedStateNotifier.persist` to await the store and propagate/signal failure (return a result or rethrow)
- Update `therapy_settings_screen.dart` save path to await, catch, and show a could-not-save error while keeping the form recoverable
- Audit the `unawaited(_persist())` call sites (modes, meal library) and add at least error logging
- Add a test with a throwing store asserting the caller observes failure and state is not treated as persisted
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (dart finding 3)
- Effort: M
- Where: `lib/persisted_state_notifier.dart`, `lib/settings/therapy_settings_screen.dart`, `lib/kv_store.dart`, `lib/providers.dart`
- Related: TASK-188 (read path), TASK-35 (base class)
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
