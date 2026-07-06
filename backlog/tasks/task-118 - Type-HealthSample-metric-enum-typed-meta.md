---
id: TASK-118
title: 'Type HealthSample: metric enum + typed meta'
status: To Do
assignee: []
created_date: '2026-07-06 08:35'
updated_date: '2026-07-06 12:57'
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
- [ ] #1 `enum HealthMetric` with `dbString`/`fromDbString` covering all current values
- [ ] #2 DB column keeps the same strings (no migration)
- [ ] #3 Workout meta is typed as a small class
- [ ] #4 All consumers use the enum; grep shows no bare metric strings outside the enum
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
