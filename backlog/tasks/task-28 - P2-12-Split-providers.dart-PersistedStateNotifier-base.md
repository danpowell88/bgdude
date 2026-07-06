---
id: TASK-28
title: Split providers.dart + PersistedStateNotifier base
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 12:57'
labels:
  - roadmap
  - architecture
  - detail-needed
milestone: m-6
dependencies:
  - TASK-35
priority: medium
ordinal: 103800
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Most of bgdude's app-wide state lives in one 2,239-line file ("providers.dart") holding 85 pieces of state. It's the largest tangle of technical debt in the project and the same work as the TASK-35 refactor.

**Reason for change.** That one file concentrates most of the app's silently-swallowed errors and untestable time handling, and it blocks cleaner testing and the background-alert work. Splitting it up (delivered via TASK-35) unblocks a lot.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 PersistedStateNotifier<T> base with restore-then-save ordering
- [ ] #2 providers.dart split into the TASK-35 (3.A) target modules
- [ ] #3 Detailed plan + migration steps in TASK-35 (3.A)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Deliver via TASK-35 (3.A).
- Build the `PersistedStateNotifier<T>` base first (restore-then-save ordering).
- Then split `providers.dart` into settings/mode/meal/pump/forecast/integration provider modules + `services/{alert_service,app_jobs}`.
- Test: a restore-then-save race test on `PersistedStateNotifier`; provider-module tests after the split (detailed in TASK-35); add/extend unit tests under `test/`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1 P2-12 → TASK-35 (3.A)
- Effort: L
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:26
---
detail-needed (2026-07-06, goal triage): The 2,239-line providers.dart split (= §3.A / TASK-35): an invasive, risk-laden refactor of app-wide state. Want scope/sequencing sign-off before starting.
---
<!-- COMMENTS:END -->
