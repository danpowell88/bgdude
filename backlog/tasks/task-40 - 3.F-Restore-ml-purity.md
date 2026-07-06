---
id: TASK-40
title: 3.F Restore ml/ purity
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 05:23'
labels:
  - roadmap
  - §3
  - architecture
  - ml
  - detail-needed
dependencies: []
priority: low
ordinal: 40000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude's machine-learning code is meant to be "pure" — free of the app framework, so it can be tested quickly on its own. One file breaks that rule by importing the framework (Riverpod).

**Reason for change.** Keeping the ML layer framework-free lets it run in a fast test lane and keeps the model logic clean. The fix splits the offending file so the pure logic stays put and only a thin controller touches the framework.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ml/ has no Riverpod imports
- [ ] #2 Controller moved to state/forecast_providers.dart
- [ ] #3 dart-test-only lane for analytics/+ml/ possible
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Split the offending file: store + train/gate/promote logic stay in `ml/` (pure; takes `KeyValueStore` after §3.B).
- Move the thin `StateNotifier` controller to `state/forecast_providers.dart`.
- Set up a `dart test` (no Flutter) lane that runs `analytics/` + `ml/`; controller test lives with the providers.
- Refactor must be behaviour-preserving: full `flutter test` + `flutter analyze` green before and after; add the new unit tests the refactor unlocks.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §3.F
- Effort: S
- Depends on: 3.B
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:23
---
detail-needed (2026-07-06, goal triage): Restoring ml/ purity depends on the §3.B KeyValueStore seam existing first.
---
<!-- COMMENTS:END -->
