---
id: TASK-164
title: Rename the gmi_eA1c_pct export column
status: To Do
assignee: []
created_date: '2026-07-06 09:14'
labels:
  - code-health
  - reports
  - cleanup
milestone: m-8
dependencies: []
priority: low
ordinal: 164000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/reports/report_exporter.dart:39` exports `m.gmi` (Bergenstal GMI) under the header `gmi_eA1c_pct`; GMI and eA1c (ADAG eAG-derived) are different quantities and no ADAG conversion exists in the codebase — a clinician comparing the CSV to a lab A1c can be misled by the label.

**Reason for change.** The column label claims a quantity the code does not compute; the header should say what the value is.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Column renamed `gmi_pct` (or a separate correctly-computed eA1c column added — decide)
- [ ] #2 Any doc/guide reference to the column updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Decide: rename the header to `gmi_pct`, or add a separate ADAG-derived eA1c column.
- Apply the change in `lib/reports/report_exporter.dart` and adjust any export test.
- Update doc/user-guide references to the CSV columns if present.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (accuracy finding 4)
- Effort: S
- Where: `lib/reports/report_exporter.dart`, `doc/user-guide.html`
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
