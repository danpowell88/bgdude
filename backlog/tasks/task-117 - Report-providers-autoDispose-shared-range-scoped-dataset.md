---
id: TASK-117
title: 'Report providers: autoDispose + shared range-scoped dataset'
status: To Do
assignee: []
created_date: '2026-07-06 08:35'
updated_date: '2026-07-06 12:57'
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
- [ ] #1 A `reportDatasetProvider` (family on `ReportRange`) fetches cgm/health/boluses/basal/carbs/annotations once
- [ ] #2 Report builders consume the shared dataset provider
- [ ] #3 Report providers are `autoDispose`
- [ ] #4 The therapy-report IOB lookback expansion (`lib/state/providers.dart:734`) is preserved in the shared fetch
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
