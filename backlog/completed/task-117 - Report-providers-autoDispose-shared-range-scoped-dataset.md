---
id: TASK-117
title: 'Report providers: autoDispose + shared range-scoped dataset'
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:35'
updated_date: '2026-07-07 03:15'
labels:
  - code-health
  - architecture
  - ui
milestone: m-8
dependencies: []
priority: medium
ordinal: 105500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** ~10 top-level `FutureProvider`s (`lib/state/providers.dart:464-487, 519-544, 677-808`) each independently query the repository for the same `reportRange`; every range change re-runs all of them, and the file has zero `autoDispose`, so report data stays cached forever after leaving Reports.

**Reason for change.** Redundant repository queries and permanent caching waste memory and IO; a single range-scoped dataset provider makes the report layer cheaper and simpler.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A `reportDatasetProvider` (family on `ReportRange`) fetches cgm/health/boluses/basal/carbs/annotations once
- [x] #2 Report builders consume the shared dataset provider
- [x] #3 Report providers are `autoDispose`
- [x] #4 The therapy-report IOB lookback expansion (`lib/state/providers.dart:734`) is preserved in the shared fetch
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add `reportDatasetProvider` as an `autoDispose` family on `ReportRange` fetching all report inputs once.
- Fold the therapy-report IOB lookback expansion into the shared fetch.
- Convert each report builder provider to consume the dataset and mark it `autoDispose`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/state/providers.dart:464-808`)
- Effort: M
- Where: `lib/state/providers.dart`
- Related: TASK-42, TASK-25
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 03:11
---
Started: add an autoDispose family reportDatasetProvider fetching all report inputs once (with the therapy IOB lookback folded in), convert the report builders to consume it and mark them autoDispose.
---

author: Claude
created: 2026-07-07 03:15
---
Done (commit b8f0b25). modelReport/bandCoverage query predictions directly (not part of the shared dataset per the AC list) but are now autoDispose.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
New lib/reports/report_dataset.dart (ReportDataset value type: dosing lists extended by the 6h lookback const, health/annotations exact-range, ...InRange getters replicating repo query semantics incl. basal overlap) + reportDatasetProvider (FutureProvider.autoDispose.family on ReportRange) fetching everything once. glucose/insulin/postMealMovement/therapy/correlation/cycle/eventsJournal report providers consume it; therapy uses the extended lists so the IOB lookback is preserved (AC#4); meals/bandCoverage/model also switched to autoDispose. Verified: analyze clean, 701 tests green, debug APK builds. Commit b8f0b25.
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
