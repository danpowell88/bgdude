---
id: TASK-105
title: Single TIR band decomposition on GlucoseMetrics
status: To Do
assignee: []
created_date: '2026-07-06 04:54'
updated_date: '2026-07-06 08:07'
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
- [ ] #1 A `GlucoseMetrics.bands` accessor (or small TirBands struct) returns the 5 exclusive fractions
- [ ] #2 gri, the PDF exporter and _TirBar all consume it; local copies deleted
- [ ] #3 Unit test asserts the bands sum to ~1.0 and match known cumulative inputs
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
<!-- SECTION:NOTES:END -->
