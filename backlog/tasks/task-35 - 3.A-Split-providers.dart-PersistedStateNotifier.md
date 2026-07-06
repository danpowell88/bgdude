---
id: TASK-35
title: Split providers.dart + PersistedStateNotifier
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 08:11'
labels:
  - roadmap
  - architecture
  - detail-needed
milestone: m-6
dependencies: []
priority: medium
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Nearly all of bgdude's app-wide state is crammed into one 2,239-line file ("providers.dart") — 85 separate pieces of state plus two big background services. It also holds most of the app's silently-ignored errors and hard-to-test "what time is it now" calls, and about a dozen pieces of state have a subtle save/load race that can lose a write.

**Reason for change.** This one file is the project's biggest structural problem: it makes the code hard to test and blocks the background-alert safety work. Splitting it into focused files — and fixing the save/load race with a shared base class — is the refactor most other cleanups depend on.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 PersistedStateNotifier<T> base with restore-then-save ordering + race test
- [ ] #2 AlertService/AppJobs take explicit deps (unit-testable)
- [ ] #3 providers.dart split into the target modules
- [ ] #4 One documented pattern per state kind
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Build `PersistedStateNotifier<T>` first: a `_ready` future completed by restore; saves queue behind it; subclasses provide encode/decode/kvKey.
- Migrate two notifiers + a race test, then sweep the rest.
- Make `AlertService`/`AppJobs` take explicit deps (repository, notification service, thresholds, clock), not `Ref`.
- Split into `state/{settings,mode,meal,pump,forecast,integration}_providers.dart` + `services/{alert_service,app_jobs}.dart`.
- Document one pattern per state kind.
- No riverpod codegen migration.
- Test: a restore-then-save race test on `PersistedStateNotifier`; unit tests for `AlertService`/`AppJobs` now that they take explicit deps; provider-module tests after the split; add the new unit tests the refactor unlocks.
- Verify: refactor must be behaviour-preserving — full `flutter test` + `flutter analyze` green before and after.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 3.A (P2-12)
- Effort: L
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:28
---
detail-needed (2026-07-06, goal triage): Anchor refactor: splitting providers.dart (85 providers) + PersistedStateNotifier base. High blast-radius; want the module boundaries + migration order confirmed before touching it.
---
<!-- COMMENTS:END -->
