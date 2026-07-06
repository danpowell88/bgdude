---
id: TASK-104
title: Add Mgdl.inUnit() and delta helpers; dedupe per-chart unit conversion
status: Done
assignee: []
created_date: '2026-07-06 04:53'
updated_date: '2026-07-06 05:01'
labels:
  - code-health
  - cleanup
  - ui
dependencies: []
priority: medium
ordinal: 104000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The `Mgdl` extension type (`lib/core/units.dart:25`) offers `.mmol` and `.display()` (a String) but no numeric in-display-unit accessor and no delta helper. So every chart re-implements the ternary:

- `lib/ui/reports/glucose_report_screen.dart:250`
- `lib/ui/reports/meals_report_screen.dart:154`
- `lib/ui/widgets/prediction_chart.dart:50`
- `lib/insights/reading_explainer.dart:580-583` converts deltas with a raw `mgdl / kMgdlPerMmol`

**Reason for change.** Duplicated conversion logic is a correctness hazard (easy to get one chart wrong) and blocks consistent unit-switch behaviour.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Mgdl gains a numeric `inUnit(GlucoseUnit)` accessor and a delta-display helper in core/units.dart
- [ ] #2 The four call sites are migrated and their private helpers deleted
- [ ] #3 Unit tests cover both units and delta formatting
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add `double inUnit(GlucoseUnit)` and `String deltaDisplay(GlucoseUnit)` (signed, unit-correct rounding) to `core/units.dart`.
- Replace the `_d`/`toDisplay` helpers in the three charts and the explainer delta.
- Unit tests in test/units_test.dart (extend if it exists).
- `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: code-health survey 2026-07-06 (lib finding 3)
- Effort: S
- Where: core/units.dart:25 + the four call sites above
<!-- SECTION:NOTES:END -->
