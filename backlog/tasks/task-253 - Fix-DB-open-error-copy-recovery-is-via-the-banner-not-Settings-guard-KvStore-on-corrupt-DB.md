---
id: TASK-253
title: >-
  Fix DB-open error copy: recovery is via the banner not Settings; guard KvStore
  on corrupt DB
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 14:29'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 165000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The startup error banner text in main.dart tells users to open Settings to reset storage or export what is readable, but DbRecoveryScreen is reachable ONLY by tapping the banner in main_shell.dart and there is no Settings entry (none in settings_screen.dart). The instruction points at a nonexistent path and contradicts the user guide which says tap the banner. Separately, on a corruptedData verdict openDb is non-null so KvStore.init runs against a DB whose quick_check just failed: history goes in-memory which is safe, but app settings keep reading and writing the corrupt on-disk DB the recovery screen is about to delete.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Error copy matches the real recovery path (tap the banner) or a Settings entry is added and the copy points to it
- [ ] #2 Banner affordance makes clear it is tappable
- [ ] #3 KvStore is not initialised against a DB that failed its integrity check on the corruptedData verdict
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-192)
- Files: lib/main.dart, lib/ui/main_shell.dart, lib/ui/settings_screen.dart
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
