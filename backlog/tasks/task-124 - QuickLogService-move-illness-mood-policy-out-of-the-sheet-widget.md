---
id: TASK-124
title: 'QuickLogService: move illness/mood policy out of the sheet widget'
status: To Do
assignee: []
created_date: '2026-07-06 08:36'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - ui
  - insights
milestone: m-8
dependencies: []
priority: medium
ordinal: 106200
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/ui/quick_log_sheet.dart:85-163` hard-codes illness boost intensities `1.1/1.2/1.35`, mood levels, and illness on/off orchestration in dialogs; each chip wires `appJobsProvider` flows inline (`:43-73`). Domain policy in a view cannot be reused or tested.

**Reason for change.** Clinical policy (illness resistance boosts) belongs in a testable service, not a bottom-sheet widget.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A `QuickLogService` (or AppJobs methods) owns `logIllness(severity)`/`logMood(level)` and the boost mapping
- [ ] #2 The widget only picks an option and calls the service
- [ ] #3 Unit tests cover the severity-to-boost mapping
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add `QuickLogService` (or AppJobs methods) owning `logIllness(severity)`/`logMood(level)` and the boost mapping.
- Reduce `quick_log_sheet.dart` to option selection plus a service call.
- Add unit tests for the mapping.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ui/quick_log_sheet.dart:85-163`)
- Effort: S–M
- Where: `lib/ui/quick_log_sheet.dart`, new service or `AppJobs`
- Related: TASK-34
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
