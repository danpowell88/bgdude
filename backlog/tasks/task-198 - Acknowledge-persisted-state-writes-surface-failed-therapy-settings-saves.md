---
id: TASK-198
title: Acknowledge persisted-state writes; surface failed therapy-settings saves
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:09'
updated_date: '2026-07-07 16:10'
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
- [x] #1 `persist` awaits the store and signals failure to the caller
- [x] #2 The therapy save path awaits and catches, showing a could-not-save error with the form still recoverable
- [x] #3 Failures from unawaited mode persists are at least logged
- [x] #4 Test: a throwing store causes the caller to observe failure, and the state is not treated as persisted
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 16:01
---
Started: reviewing PersistedStateNotifier.persist, therapy_settings_screen.dart's save path, and KvStore.setString to wire real failure signalling for dosing-relevant settings saves.
---

author: Claude
created: 2026-07-07 16:10
---
AC#1: PersistedStateNotifier.persist now returns Future<bool> (was Future<void>) -- on a throwing store(), it logs via appLog.error, REVERTS state to the last successfully-persisted value (so the rest of the app immediately stops using a value that isn't actually saved, instead of it silently reverting on the next restart), and returns false. This automatically covers every existing subclass (NotificationPrefs, UserProfile, AlertThresholds, GlucoseUnit, Therapy, A1cTarget, WeatherSettings, NightscoutConfig) since they all route through this one method; their Future<void> wrapper wrapper wrappers (e.g. 'Future<void> save(...) => persist(...)') still compile unchanged (Dart allows discarding a Future<bool> where Future<void> is declared) but now log+revert internally even if a caller doesn't await. AC#2: TherapyNotifier.save's declared return type changed to Future<bool> specifically so therapy_settings_screen.dart's _save can observe it; _save is now async, awaits the result, and shows a SnackBar ('Could not save therapy settings...') on failure -- the segment list/edit dialog remain fully available for the user to retry (state already reverted by persist(), so the screen shows the true, still-saved values). AC#3: the three hand-rolled _persist() methods that don't go through the base class (IllnessModeNotifier, MedicationModeNotifier, MealLibraryNotifier -- all called via unawaited(_persist()) or await _persist() at various call sites) now wrap their KvStore write in try/catch + appLog.error; scoped to logging only (not full revert) per the ticket's own narrower bar for these secondary paths, avoiding a much larger refactor of every activate/deactivate call site to snapshot pre-mutation state. AC#4: added 3 tests to persisted_state_notifier_test.dart with a new _ThrowingIntNotifier double (a throwing store causes persist() to return false; state is reverted, not treated as persisted, and nothing lands in KvStore; a later successful persist still works after an earlier failure) -- plus a new test/therapy_settings_screen_test.dart widget test driving the real screen (add a segment via a genuine successful save, flip the double to throw, delete a segment, assert the segment count is unchanged AND the 'Could not save' SnackBar appears). flutter analyze clean, flutter test test/ green (962 tests), flutter build apk --debug succeeded. No native Kotlin changed -- DoD #5 n/a; doc/user-guide.html not updated since this is error-path behavior (a form still says what it always said), not a new visible feature -- DoD #6 n/a.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [x] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
