---
id: TASK-268
title: >-
  Bounds-guard the AnnotationKind index decode in
  HistoryRepository.annotations()
status: Done
assignee:
  - Claude
created_date: '2026-07-07 18:33'
updated_date: '2026-07-07 21:13'
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
- [x] #1 annotations() decodes AnnotationKind per-row with a bounds guard; an out-of-range or corrupt row is skipped-and-logged, not fatal to the whole read
- [x] #2 A test proves a corrupt annotation row does not drop the other annotations
- [x] #3 history_repository_health corrupt-meta test also asserts the corruption was logged
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-207)
- File: lib/data/history_repository.dart:345 annotations(), compare the clamped :154; test/history_repository_health_test.dart log assertion
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 21:06
---
Started: bounds-guard AnnotationKind.values[r.kind] in HistoryRepository.annotations() per-row (matching health()'s TASK-207 pattern), and add the missing log assertion to the TASK-207 test.
---

author: Claude
created: 2026-07-07 21:13
---
Fixed: annotations() now decodes AnnotationKind per-row in a for-loop with a bounds guard (r.kind < 0 || r.kind >= AnnotationKind.values.length), matching health()'s TASK-207 skip-and-log pattern -- logs via appLog.error('persistence', ...) and continues rather than aborting the whole read.

Added a new 'annotations (TASK-268)' test group in test/history_repository_health_test.dart: 2 good rows + 1 row inserted directly with kind = values.length + 5; asserts both good rows survive and the corruption was logged (appLog.entries).

Also extended the pre-existing TASK-207 corrupt-meta test in the same file to assert appLog.entries contains the 'corrupt health-sample meta' error entry (AC#3) -- previously it only asserted the {} fallback, not that the corruption was logged.

Rigor check: reverted the fix locally (git stash), reran the new test -- failed with the exact predicted RangeError (length): Invalid value: Not in inclusive range 0..10: 16 at history_repository.dart:345, confirming the test genuinely pins this bug. Restored the fix (git stash pop); full suite green again.

Pipeline: flutter pub get, build_runner build (no schema changes, ran anyway per CLAUDE.md), flutter analyze clean, flutter test test/ -- 1052/1052 green, flutter build apk --debug succeeded. No native Kotlin touched so gradlew unit tests not applicable (DoD #5); no user-visible screen/flow changed so doc/user-guide.html and integration_test additions not applicable (DoD #6/#7) -- this is an internal data-integrity fix, not a UI change.

Files: lib/data/history_repository.dart, test/history_repository_health_test.dart
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
- [x] #8 backlog item updated with comments
<!-- DOD:END -->
