---
id: TASK-35
title: 3.A Split providers.dart + PersistedStateNotifier
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §3
  - phase-6
  - architecture
dependencies: []
priority: medium
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
providers.dart is 2,239 lines / 85 providers / 20 inline notifiers + AlertService (~358) + AppJobs (~520); 33/43 silent catches and 45/78 raw DateTime.now() live here. Target modules: state/{persisted_state_notifier,settings_providers,mode_providers,meal_providers,pump_providers,forecast_providers,integration_providers}.dart; services/{alert_service,app_jobs}.dart. PersistedStateNotifier<T> first (fixes ~12 un-awaited _restore() races): _ready future; saves queue behind it; subclasses provide encode/decode/kvKey; migrate two + a race test, then sweep. AlertService/AppJobs take explicit deps, not Ref. One pattern per state kind, documented in the module header. No riverpod codegen migration.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 PersistedStateNotifier<T> base with restore-then-save ordering + race test
- [ ] #2 AlertService/AppJobs take explicit deps (unit-testable)
- [ ] #3 providers.dart split into the target modules
- [ ] #4 One documented pattern per state kind
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §3.A (P2-12)
Effort: L
Roadmap status: open
<!-- SECTION:NOTES:END -->
