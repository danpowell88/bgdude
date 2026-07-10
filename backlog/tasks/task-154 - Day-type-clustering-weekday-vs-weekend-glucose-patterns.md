---
id: TASK-154
title: 'Day-type clustering: weekday vs weekend glucose patterns'
status: Needs Review
assignee:
  - Claude
created_date: '2026-07-06 08:44'
updated_date: '2026-07-10 14:03'
labels:
  - feature
  - insights
  - ml
milestone: m-7
dependencies: []
priority: medium
ordinal: 702400
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Full CGM history is available via `repo.cgm`, `MetricsCalculator` computes per-window TIR/mean/LBGI, and AGP bucketing exists in the report exporter — but a flat AGP hides routine-driven patterns. An on-device unsupervised split (weekday class, optional k-means k=2-3 on per-day feature vectors) surfaces "weekend mornings run higher".

**Value.** Routine-driven patterns are invisible in a single pooled AGP; clustering makes them a first-class insight.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Per-day feature vectors exist (mean, TIR, TBR, peak hour)
- [x] #2 Weekday/weekend grouping plus optional k-means is implemented
- [x] #3 A Patterns report section shows per-cluster AGP overlays
- [x] #4 Tests cover the clustering
- [x] #5 The user guide is updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Build per-day feature vectors (mean, TIR, TBR, peak hour) from `repo.cgm` via `MetricsCalculator`.
- Implement weekday/weekend grouping and optional k-means (k=2-3).
- Add a Patterns report section with per-cluster AGP overlays reusing the exporter bucketing.
- Add tests.
- Update `doc/user-guide.html`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (report exporter AGP bucketing, `MetricsCalculator`)
- Effort: M
- Where: new ml/insights code, Patterns report section, `doc/user-guide.html`
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-10 11:02
---
branch: task-154
---

author: Claude
created: 2026-07-10 11:04
---
Started: designing DayFeatures (mean/TIR/TBR/peakHour per day) + weekday/weekend split (always computed) + optional deterministic k-means (k=2, seeded from min/max mean-glucose days, no RNG -- matches this codebase's ml/ no-hidden-randomness convention) once there are enough days. Per-cluster AGP via the existing AgpCalculator (reused, not reimplemented) over each cluster's pooled CGM samples. New 'Patterns' report screen with overlaid median AGP lines per cluster (full 5-band overlay for 2+ clusters would be visually cluttered; median-only overlay directly shows the 'weekend mornings run higher' style insight).
---

author: Claude
created: 2026-07-10 11:16
---
implemented-by: Claude (Sonnet 5, session 5ecb6b72-c69b-4afb-b36c-af3d04f85cad) -- new lib/reports/day_pattern_report.dart: DayFeatures (mean/TIR/TBR/peakHour per day, days with <12 readings excluded as too sparse to trust). Weekday/weekend split is ALWAYS computed (calendar-based, DateTime.weekday). Optional k-means (k=2) once there are >= minDaysForKMeans(14) days: deterministic Lloyd's algorithm over z-scored feature vectors, seeded from the min/max-mean-glucose days (NOT a random draw -- matches this codebase's ml/ no-hidden-randomness convention, see gbm.dart's own stated design principle), max 20 iterations or convergence. Per-cluster AGP reuses the EXISTING AgpCalculator (not reimplemented) over each cluster's pooled CGM samples. New provider dayPatternReportProvider + new screen lib/ui/reports/day_pattern_report_screen.dart (overlaid MEDIAN-only AGP lines per cluster -- full percentile bands per cluster would be visually cluttered with 2+ overlaid; median alone shows 'weekend mornings run higher'-style shape differences), wired into the Reports hub as the 8th report card ('Patterns'). Tests: test/reports/day_pattern_report_test.dart -- per-day feature computation (hand-verified TIR/TBR/peakHour against a synthetic spike day), sparse-day exclusion, weekday/weekend split with an empty-group safety case, k-means staying null below the day threshold, a synthetic two-distinct-glucose-regime dataset that the k-means correctly separates (verified NO cluster mixes the two regimes, and the two cluster means are exactly the two distinct input means), and a determinism check (same input -> same clustering across repeated builds, proving the no-RNG design actually holds). Rigor-checked the weekday/weekend split (temp-bug forcing isWeekend=false always, confirmed the split test fails 2-vs-1 instead of 1-vs-1) and the k-means assignment step (temp-bug disabling the distance-comparison update, confirmed only 1 cluster forms instead of 2) -- both reverted cleanly. Full pipeline green: analyze clean, 1373 tests passing, coverage 68.42% (floor 65%), apk build succeeded. No native Kotlin changed. doc/user-guide.html updated (new Patterns report row). Integration test: extended integration_test/features_reports_test.dart's existing 'reports hub opens each of the N reports' test (7->8) to include 'Patterns', matching the established per-report convention -- could not run it live (the same emulator VM-service WebSocket limitation confirmed on TASK-141/143/151/152/153 this session), but the source change itself follows the codebase's exact existing pattern for adding a new report to that shared list.
created: 2026-07-10 11:17
---
implemented-by: Claude (Sonnet 5, session 5ecb6b72-c69b-4afb-b36c-af3d04f85cad) -- code complete and pushed to branch task-154 (commit 2d10619). Full implementation details, rigor-check notes, and pipeline results recorded on that branch's copy of this task file.
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
- [x] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
