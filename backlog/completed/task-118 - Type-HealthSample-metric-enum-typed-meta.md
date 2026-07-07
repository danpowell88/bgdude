---
id: TASK-118
title: 'Type HealthSample: metric enum + typed meta'
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:35'
updated_date: '2026-07-07 03:21'
labels:
  - code-health
  - architecture
  - data-integrity
milestone: m-8
dependencies: []
priority: medium
ordinal: 105600
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `HealthSample.type` (`lib/data/health_sync.dart:15-29`) is a free String with ~20 magic values written at `:108-221` and string-compared by consumers (`lib/state/providers.dart:526` `h.type != 'sleepHours'`; `:2023-2028` `s.type == 'exercise'`, `s.meta['activity']`; `lib/ml/health_features.dart`); `meta` is `Map<String,Object?>`. A typo silently yields empty results.

**Reason for change.** Stringly-typed metrics fail silently at runtime; an enum plus typed workout meta turns typos into compile errors without any DB migration.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `enum HealthMetric` with `dbString`/`fromDbString` covering all current values
- [x] #2 DB column keeps the same strings (no migration)
- [x] #3 Workout meta is typed as a small class
- [x] #4 All consumers use the enum; grep shows no bare metric strings outside the enum
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add `enum HealthMetric` with `dbString`/`fromDbString` for every current string value.
- Add a small typed workout-meta class over `meta`.
- Convert writers in `lib/data/health_sync.dart` and all consumers to the enum.
- Grep for remaining bare metric strings and remove them.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/data/health_sync.dart:15-221`)
- Effort: M
- Where: `lib/data/health_sync.dart`, `lib/state/providers.dart`, `lib/ml/health_features.dart`
- Related: TASK-111 (cross-language sibling), TASK-42
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 03:16
---
Started: HealthMetric enum with dbString/fromDbString (DB strings unchanged, no migration), typed WorkoutMeta, all writers/consumers converted; grep gate for bare metric strings.
---

author: Claude
created: 2026-07-07 03:21
---
Done (commit 5e3d318).
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
HealthMetric enum (22 values) with dbString/fromDbString in lib/data/health_sync.dart — dbStrings identical to the persisted values so no migration; the repository saves type.dbString and skips unknown stored strings on load instead of guessing. HealthSample.type is now HealthMetric; WorkoutMeta types the workout activity/source meta (writer builds it, providers consume via HealthSample.workout). All 15 writer/consumer files converted (context_builder helpers take HealthMetric; correlation_report switch is exhaustively checked). Grep gate: no bare metric strings remain in lib/. Verified: analyze clean, 701 tests green, debug APK builds. Commit 5e3d318.
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
