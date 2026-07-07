---
id: TASK-268
title: >-
  Bounds-guard the AnnotationKind index decode in
  HistoryRepository.annotations()
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 18:33'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 116000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-207 added a per-row guard to HistoryRepository.health() precisely because one bad row aborting the whole range read silently drops every sample. The annotations() method in the same file has the identical failure mode via a different mechanism: AnnotationKind is persisted as an integer index (saveAnnotation writes a.kind.index) and read back with a raw AnnotationKind.values[r.kind] list index at line 345. If an AnnotationKind value is ever removed or reordered (the exact enum-drift scenario this whole sweep targets) or a row is corrupt, r.kind goes out of range, RangeError throws, and the entire annotations() read aborts, silently dropping ALL confirmed annotations (the confirmed data tier for reports and training labels), not just the bad row. The sibling GlucoseTrend.values[r.trend.clamp(...)] at line 154 IS defensively clamped; AnnotationKind is not. Separately, the TASK-207 health corrupt-meta test asserts the fallback but never asserts the log fired, unlike the TASK-206 corruption tests.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 annotations() decodes AnnotationKind per-row with a bounds guard; an out-of-range or corrupt row is skipped-and-logged, not fatal to the whole read
- [ ] #2 A test proves a corrupt annotation row does not drop the other annotations
- [ ] #3 history_repository_health corrupt-meta test also asserts the corruption was logged
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-207)
- File: lib/data/history_repository.dart:345 annotations(), compare the clamped :154; test/history_repository_health_test.dart log assertion
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
