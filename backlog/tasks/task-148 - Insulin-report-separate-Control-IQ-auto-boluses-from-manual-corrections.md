---
id: TASK-148
title: 'Insulin report: separate Control-IQ auto-boluses from manual corrections'
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:42'
updated_date: '2026-07-07 04:23'
labels:
  - code-health
  - reports
milestone: m-8
dependencies: []
priority: medium
ordinal: 106900
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/reports/insulin_report.dart:88-95` classifies every `carbsGrams == 0` bolus as a user correction, so Control-IQ microboluses inflate `correctionBolusCount`, `bolusesPerDay`, `avgBolusUnits`; `BolusEvent.isAutomatic` exists (`lib/core/samples.dart:82`), is persisted (`lib/data/history_repository.dart:146,164`), and is already used by the timeline (`lib/timeline/event_builder.dart:50`).

**Reason for change.** The report misstates user behaviour by counting loop microboluses as manual corrections; the flag to fix it is already persisted.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Boluses are partitioned manual-correction / automatic / meal via `isAutomatic`
- [x] #2 An `autoBolusCount` is added and manual-vs-auto is surfaced on the report screen
- [x] #3 A unit test covers mixed data
- [x] #4 The user guide is updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Partition boluses by `isAutomatic` and `carbsGrams` into manual-correction / automatic / meal.
- Add `autoBolusCount` and surface manual-vs-auto on the report screen.
- Add a unit test with mixed manual/auto data.
- Update `doc/user-guide.html`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/reports/insulin_report.dart:88-95`)
- Effort: S
- Where: `lib/reports/insulin_report.dart`, report screen, `doc/user-guide.html`
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 04:20
---
Started: partition boluses meal/manual-correction/automatic via isAutomatic; add autoBolusCount; surface manual-vs-auto on the Insulin report screen; mixed-data test; guide row.
---

author: Claude
created: 2026-07-07 04:23
---
Done.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
InsulinReportBuilder partitions in-range boluses via isAutomatic: auto -> autoBolusCount, non-auto with carbs -> meal, remainder -> manual corrections; the screen rows read 'Manual corrections' / 'Control-IQ auto-boluses'. Mixed manual/auto test pins the split (5 boluses -> 1 meal, 1 manual correction, 3 auto). Guide's report table row updated. Verified: analyze clean, 722 tests green, APK builds.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [x] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
