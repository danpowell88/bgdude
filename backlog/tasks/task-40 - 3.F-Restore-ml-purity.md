---
id: TASK-40
title: 3.F Restore ml/ purity
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §3
  - architecture
  - ml
dependencies: []
priority: low
ordinal: 40000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
ml/forecaster_service.dart is the only ml/ file importing Riverpod. Split: store + train/gate/promote logic stay in ml/ (pure; takes KeyValueStore after §3.B); the thin StateNotifier controller moves to state/forecast_providers.dart. Enables a dart test-only CI lane for analytics/ + ml/.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ml/ has no Riverpod imports
- [ ] #2 Controller moved to state/forecast_providers.dart
- [ ] #3 dart-test-only lane for analytics/+ml/ possible
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §3.F
Effort: S
Depends on: 3.B
Roadmap status: open
<!-- SECTION:NOTES:END -->
