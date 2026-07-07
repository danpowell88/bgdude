---
id: TASK-164
title: Rename the gmi_eA1c_pct export column
status: Done
assignee:
  - Claude
created_date: '2026-07-06 09:14'
updated_date: '2026-07-07 15:31'
labels:
  - code-health
  - reports
  - cleanup
milestone: m-8
dependencies: []
priority: low
ordinal: 110500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/reports/report_exporter.dart:39` exports `m.gmi` (Bergenstal GMI) under the header `gmi_eA1c_pct`; GMI and eA1c (ADAG eAG-derived) are different quantities and no ADAG conversion exists in the codebase — a clinician comparing the CSV to a lab A1c can be misled by the label.

**Reason for change.** The column label claims a quantity the code does not compute; the header should say what the value is.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Column renamed `gmi_pct` (or a separate correctly-computed eA1c column added — decide)
- [x] #2 Any doc/guide reference to the column updated
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 15:28
---
Started: renaming the gmi_eA1c_pct CSV export column to gmi_pct -- decision is the plain rename (option A), not adding a new ADAG eA1c column, since no ADAG conversion exists in the codebase and inventing one is out of scope for a labeling fix.
---

author: Claude
created: 2026-07-07 15:31
---
Renamed the CSV export header gmi_eA1c_pct -> gmi_pct in lib/reports/report_exporter.dart (option A: plain rename, not a new eA1c column -- no ADAG conversion exists in the codebase and inventing one is out of scope here). Also fixed the same conflation in the PDF's 'Key metrics' table label ('GMI (est. A1c)' -> 'GMI (glucose management indicator)'), since it was the identical mislabeling in the other export surface. Checked doc/user-guide.html and doc/index.html: neither references the literal column header or PDF label text -- their prose descriptions of GMI as a 'CGM-derived A1c estimate' are accurate plain-language framing (that's literally what GMI is designed to approximate) and don't need changing, so AC#2 has nothing to update. Updated test/glucose_report_test.dart's hardcoded 'gmi_eA1c_pct' assertion to 'gmi_pct'. flutter analyze clean, flutter test test/ green (950 tests), flutter build apk --debug succeeded.
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
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
