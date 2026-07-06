---
id: TASK-4
title: P0-4 Advisor/predictor honour configured DIA & insulin peak
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:43'
labels:
  - roadmap
  - §1-P0
  - phase-0
  - dosing-math
dependencies: []
priority: high
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Insulin keeps working in the body for a set time after a dose — its "duration of insulin action" (DIA), peaking partway through. bgdude lets you configure your DIA and peak, and its "care detectors" already use those settings — but the bolus calculator ("advisor") and the glucose forecast ignore them and assume fixed values (360 minutes / 75-minute peak).

**Reason for change.** Anyone whose insulin acts faster or slower than the default gets inconsistent numbers between screens, because the advisor and forecast use the wrong action curve. They should read your configured values like everything else.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Advisor uses configured DIA & peak
- [ ] #2 Predictor uses configured DIA & peak
- [ ] #3 No hardcoded 360/75 remain in these paths
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** In bolus_advisor.dart:102-103 and predictor.dart:177-178, read the configured DIA & peak (same source the care detectors use) instead of the 360/75 literals.

**Testing.** Unit test with a non-default DIA/peak: advisor + predictor IOB match the care-detector curve. Add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able). `flutter analyze` clean and `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P0-4
Effort: S
Where: bolus_advisor.dart:102-103, predictor.dart:177-178
Roadmap status: open
<!-- SECTION:NOTES:END -->
