---
id: TASK-28
title: P2-12 Split providers.dart + PersistedStateNotifier base
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:43'
labels:
  - roadmap
  - §1-P2
  - phase-6
  - architecture
dependencies: []
priority: medium
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Most of bgdude's app-wide state lives in one 2,239-line file ("providers.dart") holding 85 pieces of state. It's the largest tangle of technical debt in the project and the same work as the §3.A refactor.

**Reason for change.** That one file concentrates most of the app's silently-swallowed errors and untestable time handling, and it blocks cleaner testing and the background-alert work. Splitting it up (delivered via TASK-35) unblocks a lot.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 providers.dart split into the §3.A target modules
- [ ] #2 PersistedStateNotifier<T> base with restore-then-save ordering
- [ ] #3 Detailed plan + migration steps in TASK-35 (§3.A)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Deliver via §3.A / TASK-35: PersistedStateNotifier<T> base first, then split into settings/mode/meal/pump/forecast/integration provider modules + services/{alert_service,app_jobs}.

**Testing.** A restore-then-save race test on PersistedStateNotifier; provider-module tests after the split. Detailed in TASK-35. Add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able). `flutter analyze` clean and `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P2-12 → §3.A
Effort: L
Roadmap status: open
<!-- SECTION:NOTES:END -->
