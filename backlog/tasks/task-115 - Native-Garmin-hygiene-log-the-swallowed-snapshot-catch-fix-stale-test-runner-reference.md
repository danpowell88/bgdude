---
id: TASK-115
title: >-
  Native/Garmin hygiene: log the swallowed snapshot catch; fix stale test-runner
  reference
status: To Do
assignee: []
created_date: '2026-07-06 04:57'
updated_date: '2026-07-06 08:08'
labels:
  - code-health
  - cleanup
  - native
  - garmin
milestone: m-8
dependencies: []
priority: low
ordinal: 115000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Two small hygiene issues from the 2026-07-06 survey:

- `GarminIntegration.kt:53` — a bare catch swallows a malformed snapshot with no log, so a broken watch feed leaves no trace (every other Kotlin catch in the codebase logs).
- `garmin/tests/BgDataTest.mc:15` — the run instructions point to tools/run_garmin_tests.ps1 / .sh, which do not exist; the real scripts are garmin/tools/run_tests.ps1 / .sh (garmin/README.md:136 documents them correctly).

**Reason for change.** The silent catch makes a stopped watch feed undiagnosable; the stale comment sends anyone running the only Garmin unit tests to a dead end.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The catch logs at info level with the throwable (does not destabilise the pump path)
- [ ] #2 BgDataTest.mc comment points at garmin/tools/run_tests.ps1 / .sh
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add an info-level log with the throwable in GarminIntegration.kt:53.
- Fix the comment in BgDataTest.mc:15.
- gradlew :app:testDebugUnitTest green (Kotlin touched).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: code-health survey 2026-07-06 (test findings 8, 9)
- Effort: S
- Where: android/.../garmin/GarminIntegration.kt:53, garmin/tests/BgDataTest.mc:15
<!-- SECTION:NOTES:END -->
