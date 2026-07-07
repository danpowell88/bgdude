---
id: TASK-259
title: >-
  persist() failure must not latch _hasLocalWrite and suppress the pending
  restore
status: Done
assignee:
  - Claude
created_date: '2026-07-07 16:26'
updated_date: '2026-07-07 20:25'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 148000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
In PersistedStateNotifier.persist() the _hasLocalWrite latch is set to true BEFORE store(value). The TASK-198 fix reverts state to previous in the catch on a write failure, but does not revert _hasLocalWrite. If a persist() fails during the in-flight startup restore window, the latch stays true; when the concurrent _restore() load() completes, the guard if (loaded == null or _hasLocalWrite) return discards the real persisted disk value. Net: the session runs on defaults for a dosing-relevant setting even though disk holds a valid saved value, and only the write error is logged, so the suppressed-restore consequence is invisible. Narrow (startup-only window) but a real correctness gap the fix introduced by reverting state while leaving the latch set.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 persist() snapshots the prior _hasLocalWrite and restores it in the catch on failure
- [x] #2 A failed persist during an in-flight restore does not suppress applying the real persisted value once load() completes
- [x] #3 Test: a persist failure racing a restore results in the disk value being applied, not the default
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-198)
- File: lib/state/persisted_state_notifier.dart:110 (restore guard), :122 (latch set), :131 (state-only revert)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 20:21
---
Started: snapshot/restore _hasLocalWrite around persist()'s store() failure so a failed write during an in-flight restore doesn't permanently suppress applying the real disk value.
---

author: Claude
created: 2026-07-07 20:25
---
Done. lib/state/persisted_state_notifier.dart: persist() now snapshots _hasLocalWrite (hadLocalWrite) before latching it true, and on a store() failure restores THAT snapshot rather than leaving the latch permanently true. A failed FIRST write (hadLocalWrite was false) reverts the latch to false, so a concurrent in-flight _restore() can still apply the real disk value once load() completes. A failed write that comes AFTER a genuine earlier successful write (hadLocalWrite true) correctly stays latched, so a stale restore still can't clobber real local state.

Tests added to test/persisted_state_notifier_test.dart: a new _SlowLoadIntNotifier (load() gated on an externally-controlled Completer) lets a test force a persist() failure to land while restore()'s load() is still in flight. Two new tests: (1) the exact bug scenario -- failed write during in-flight restore -> disk value (55) wins once load() completes, not the default; (2) the latch-must-not-over-revert case -- a genuine successful write followed by a later failed one still blocks the stale restore.

Verified rigor: temporarily removed the latch-revert line, reran -- test (1) failed with exactly the described symptom (state stuck at 0/default instead of the real disk value 55). Reverted (git diff clean).

Pipeline: flutter analyze clean, flutter test test/ 1039/1039, flutter build apk --debug succeeded. No native Kotlin, no user-visible change.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
