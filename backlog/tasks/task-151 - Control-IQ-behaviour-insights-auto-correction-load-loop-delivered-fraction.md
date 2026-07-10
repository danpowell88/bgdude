---
id: TASK-151
title: 'Control-IQ behaviour insights (auto-correction load, loop-delivered fraction)'
status: Needs Review
assignee:
  - Claude
created_date: '2026-07-06 08:43'
updated_date: '2026-07-10 14:03'
labels:
  - feature
  - reports
  - insights
milestone: m-7
dependencies:
  - TASK-148
priority: medium
ordinal: 702100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Historical boluses carry the persisted `isAutomatic` flag and basal segments are stored, so the app can report how hard Control-IQ works: auto-corrections/day, share of daily insulin delivered automatically, trend over the range; live `controlIqMode` is snapshot-only (not persisted) — time-in-mode needs a small mode log (flag as the one new source).

**Value.** Shows whether base settings are drifting: a loop compensating heavily is the earliest sign that basal/ISF/CR need attention.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The insulin report is extended with `autoBolusUnits/day`, `autoCorrectionCount/day`, loop-bolus fraction and a per-day sparkline
- [x] #2 The optional mode-log decision is documented (do or defer)
- [x] #3 Tests cover the new metrics
- [x] #4 The user guide is updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Extend the insulin report with `autoBolusUnits/day`, `autoCorrectionCount/day`, and loop-bolus fraction.
- Add a per-day sparkline to the report screen.
- Decide and document whether to add the small mode log for time-in-mode (do or defer).
- Add tests.
- Update `doc/user-guide.html`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/reports/insulin_report.dart`, `lib/core/samples.dart:82`)
- Effort: M
- Where: `lib/reports/insulin_report.dart`, report screen, `doc/user-guide.html`
- Related: TASK-42 if the mode log is added
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-10 10:30
created: 2026-07-10 10:45
---
branch: task-151
---

author: Claude
created: 2026-07-10 10:30
---
implemented-by: Claude (Sonnet 5, session 5ecb6b72-c69b-4afb-b36c-af3d04f85cad) -- lib/reports/insulin_report.dart: DailyInsulin gained autoBolusUnits/autoBolusCount per day (mirrors the existing bolus/basal per-day fields, so the per-day list already IS the sparkline data source); InsulinReport gained avgAutoBolusUnits/avgAutoCorrectionCount (per-day averages over the same activeDays basis as avgBolus/avgBasal) and loopBolusFraction (auto bolus units / all bolus units in range). lib/ui/reports/insulin_report_screen.dart: new 'Control-IQ workload' section (3 stat rows + a per-day sparkline via fl_chart LineChart, mirroring the existing TDD BarChart's style). AC#2 (mode-log decision): DEFERRED -- filed TASK-307 as the follow-up. Reasoning: unlike this task's metrics (all derivable from already-persisted BolusEvent.isAutomatic history), a genuine time-in-controlIqMode report needs a NEW persisted data source (controlIqMode is snapshot-only today, never logged on transition) -- that's schema + a new tracking hook, a materially different and larger scope than 'new math over existing history', so it doesn't belong folded into this task. Tests: test/reports/reports_phase2_test.dart -- hand-computed workload metrics against a mixed manual/meal/auto fixture (avgAutoBolusUnits=0.6, avgAutoCorrectionCount=1.5, loopBolusFraction=1.2/8.2), verified per-day autoBolusUnits/autoBolusCount on the two active days, plus a no-automatic-boluses zero-not-NaN case. Rigor-checked both avgAutoBolusUnits and loopBolusFraction (temp-bug each to a hardcoded 0.0, confirmed the corresponding assertions fail with the predicted actual values, reverted cleanly -- confirmed via flutter analyze returning clean afterward, since the stub versions triggered unused-variable warnings that would have been visible otherwise). Full pipeline green: analyze clean, 1368 tests passing, coverage 68.64% (floor 65%), apk build succeeded. No native Kotlin changed. Integration test: Reports screens already have integration_test coverage; could not run it live (the emulator's known VM-service WebSocket limitation, same as TASK-141/143) -- the new section is additive to an existing screen.
created: 2026-07-10 10:45
---
Coordination fix: code complete and pushed (commit 67a56a3 on branch task-151) -- status/branch previously only committed on that branch, invisible on main. Implementation details recorded in the comment history on that branch's copy of this task file.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
