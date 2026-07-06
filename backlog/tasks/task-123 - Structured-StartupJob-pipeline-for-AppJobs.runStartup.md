---
id: TASK-123
title: Structured StartupJob pipeline for AppJobs.runStartup
status: To Do
assignee: []
created_date: '2026-07-06 08:36'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - architecture
  - logging
milestone: m-8
dependencies: []
priority: medium
ordinal: 106100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `runStartup` (`lib/state/providers.dart:1734-1779`) is 12 sequential steps each wrapped in `try{}catch(_){}` with implicit ordering and no aggregated result — a broken migration or training crash is invisible.

**Reason for change.** Silent startup failures hide data-integrity and model problems; a structured pipeline makes each job observable and its ordering explicit.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 An ordered `List<StartupJob>` (name + run) is iterated with per-job logging
- [ ] #2 A `StartupReport` summary is surfaced to the dev log ring buffer
- [ ] #3 Job ordering is explicit
- [ ] #4 A unit test with a deliberately failing job asserts the other jobs still run and the failure is recorded
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Define `StartupJob` (name + run) and convert the 12 steps into an ordered list.
- Iterate with per-job try/catch, logging each outcome.
- Aggregate into a `StartupReport` and surface it to the dev log ring buffer.
- Add a unit test with a deliberately failing job.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/state/providers.dart:1734-1779`)
- Effort: M
- Where: `lib/state/providers.dart`
- Related: TASK-38 (ring buffer), TASK-39 (clock)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 09:20
---
Accuracy-reliability sweep 2026-07-06: concrete instance for this ticket — training isolate failures are currently swallowed (Isolate.run in providers.dart:1876-1879 inside catch(_)); the structured pipeline must record per-job outcomes and surface a training-failed diagnostic, with a bounded retry considered.
---
<!-- COMMENTS:END -->

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
