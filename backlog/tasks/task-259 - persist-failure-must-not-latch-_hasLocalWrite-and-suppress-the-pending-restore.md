---
id: TASK-259
title: >-
  persist() failure must not latch _hasLocalWrite and suppress the pending
  restore
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 16:26'
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
- [ ] #1 persist() snapshots the prior _hasLocalWrite and restores it in the catch on failure
- [ ] #2 A failed persist during an in-flight restore does not suppress applying the real persisted value once load() completes
- [ ] #3 Test: a persist failure racing a restore results in the disk value being applied, not the default
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-198)
- File: lib/state/persisted_state_notifier.dart:110 (restore guard), :122 (latch set), :131 (state-only revert)
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
