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
- [ ] #1 The insulin report is extended with `autoBolusUnits/day`, `autoCorrectionCount/day`, loop-bolus fraction and a per-day sparkline
- [ ] #2 The optional mode-log decision is documented (do or defer)
- [ ] #3 Tests cover the new metrics
- [ ] #4 The user guide is updated
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
created: 2026-07-10 10:45
---
branch: task-151
---

author: Claude
created: 2026-07-10 10:45
---
Coordination fix: code complete and pushed (commit 67a56a3 on branch task-151) -- status/branch previously only committed on that branch, invisible on main. Implementation details recorded in the comment history on that branch's copy of this task file.
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
