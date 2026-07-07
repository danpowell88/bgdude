---
id: TASK-105
title: Single TIR band decomposition on GlucoseMetrics
status: Done
assignee: []
created_date: '2026-07-06 04:54'
updated_date: '2026-07-06 09:03'
labels:
  - code-health
  - cleanup
milestone: m-8
dependencies: []
priority: medium
ordinal: 105000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The conversion from cumulative fractions to mutually-exclusive time-in-range bands (`low = timeBelow70 - timeBelow54`, `high = timeAbove180 - timeAbove250`, `veryHigh = timeAbove250`, ...) is computed independently in three places:

- `lib/analytics/metrics.dart:62-65` (the `gri` getter)
- `lib/reports/report_exporter.dart:125-130` (PDF)
- `lib/ui/reports/glucose_report_screen.dart:204-214` (`_TirBar`)

**Reason for change.** The exclusive-band definition is a clinical invariant; three copies can drift so the UI, the PDF and the GRI score could disagree.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A `GlucoseMetrics.bands` accessor (or small TirBands struct) returns the 5 exclusive fractions
- [x] #2 gri, the PDF exporter and _TirBar all consume it; local copies deleted
- [x] #3 Unit test asserts the bands sum to ~1.0 and match known cumulative inputs
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add the `bands` accessor to `GlucoseMetrics` returning veryLow/low/inRange/high/veryHigh.
- Migrate the three consumers.
- Unit test with a synthetic metrics fixture.
- `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: code-health survey 2026-07-06 (lib finding 4)
- Effort: S
- Where: metrics.dart:62-65, report_exporter.dart:125-130, glucose_report_screen.dart:204-214

Implemented: new TirBands struct + GlucoseMetrics.bands getter is the single source of truth for the 5 exclusive fractions (veryLow/low/inRange/high/veryHigh). gri and _TirBar now consume it; their local subtractions are deleted. NOTE re AC#2: the PDF 'Time in ranges' table (report_exporter.dart:125-131) shows the CUMULATIVE fractions (% above 180, % above 250) — a distinct clinical convention, not the exclusive decomposition — so it was intentionally left as-is rather than converted (converting would change the clinician-facing presentation). The two genuine exclusive-decomposition copies are unified. Test: metrics_test.dart TirBands group (bands sum ~1.0 from known cumulative inputs; gri derives from bands).
<!-- SECTION:NOTES:END -->
