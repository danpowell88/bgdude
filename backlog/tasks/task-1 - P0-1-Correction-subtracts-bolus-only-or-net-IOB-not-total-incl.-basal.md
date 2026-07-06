---
id: TASK-1
title: 'P0-1 Correction subtracts bolus-only (or net) IOB, not total incl. basal'
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:59'
labels:
  - roadmap
  - §1-P0
  - phase-0
  - dosing-math
dependencies: []
priority: high
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** When bgdude suggests a "correction" (extra insulin to bring down a high reading), it first subtracts the insulin still working from earlier shots — called "insulin on board" or IOB — so it does not stack insulin and cause a low. The bug: its IOB figure lumps in "basal" insulin (the slow background drip the pump runs all day) together with "bolus" doses (the shots you give for meals and corrections). On a Tandem pump with Control-IQ (the pump's built-in automation) the basal is already accounted for, so counting it again makes bgdude believe far more insulin is active than really is.

**Reason for change.** The correction therefore shrinks toward zero and the app quietly advises less insulin than a high actually needs. It also feeds distorted numbers into the parts of the app that learn from your data. This is a safety-relevant under-dosing bug.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Correction uses bolus-only/net IOB for the subtraction
- [ ] #2 Forward prediction still uses full IOB
- [ ] #3 Regression test on a fasting scenario
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** In bolus_advisor.dart:191 and 293-294 use `_iob.fromBoluses(...)` (bolus-only, or net) for the amount subtracted from the correction; keep full IOB only for the forward BG prediction. Mirrors the rescue-carb fix (P0-5).

**Testing.** Unit test: with only basal IOB the correction is unchanged; with recent bolus IOB it is subtracted. Add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able). `flutter analyze` clean and `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P0-1
Effort: S
Where: bolus_advisor.dart:191,293-294
Roadmap status: open
<!-- SECTION:NOTES:END -->
