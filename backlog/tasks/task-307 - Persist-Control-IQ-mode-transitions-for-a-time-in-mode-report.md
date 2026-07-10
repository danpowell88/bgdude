---
id: TASK-307
title: Persist Control-IQ mode transitions for a time-in-mode report
status: To Do
assignee: []
created_date: '2026-07-10 10:26'
labels: []
milestone: m-7
dependencies: []
ordinal: 722000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-151 (Control-IQ workload insights) explicitly flagged this as optional/deferrable: live controlIqMode is snapshot-only today (read from the pump connection, never persisted), so any 'time spent in Sleep/Exercise/Normal mode' report needs a genuinely new data source -- a small mode-transition log (timestamp + mode on each change) -- not just new math over existing history like the rest of TASK-151 was. Deferred out of TASK-151 to keep that task scoped to metrics derivable from already-persisted bolus/basal history; this ticket is the follow-up if time-in-mode is wanted later.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A persisted log records controlIqMode transitions (timestamp + mode) as they're observed from the pump connection
- [ ] #2 A report/insight can compute time-in-mode (Sleep/Exercise/Normal/etc.) over a date range from that log
<!-- AC:END -->

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
- [ ] #10 Reviewed by a different agent than the implementer -- a reviewed-by comment is present and the task passed through Review before Done
<!-- DOD:END -->
