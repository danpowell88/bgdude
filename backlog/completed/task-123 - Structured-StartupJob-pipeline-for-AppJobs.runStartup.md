---
id: TASK-123
title: Structured StartupJob pipeline for AppJobs.runStartup
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:36'
updated_date: '2026-07-07 03:49'
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
- [x] #1 An ordered `List<StartupJob>` (name + run) is iterated with per-job logging
- [x] #2 A `StartupReport` summary is surfaced to the dev log ring buffer
- [x] #3 Job ordering is explicit
- [x] #4 A unit test with a deliberately failing job asserts the other jobs still run and the failure is recorded
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

author: Claude
created: 2026-07-07 03:46
---
Started: StartupJob (name+run) list runner with per-job logging, StartupReport aggregated into the dev log; failing-job unit test.
---

author: Claude
created: 2026-07-07 03:49
---
Done.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
New lib/state/startup_jobs.dart: StartupJob(name, run, enabled) + runStartupJobs -> StartupReport (per-job ok/skipped/error/elapsed; failures logged loudly with the job name; summary warn/info line into the appLog ring buffer the Diagnostics screen shows). AppJobs.runStartup now declares the 12 jobs as an explicit ordered list with demo-mode jobs marked enabled:false (reported skipped). 4 unit tests incl. the deliberately-failing-job case. Verified: analyze clean, 706 tests green, APK builds.
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
