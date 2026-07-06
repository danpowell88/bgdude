---
id: TASK-2
title: P0-2 Predictor models insulin effect from net insulin (EGP baseline)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 04:13'
labels:
  - roadmap
  - §1-P0
  - phase-1
  - dosing-math
  - detail-needed
dependencies: []
priority: high
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude predicts where your glucose is heading and helps size insulin, which needs a model of how insulin lowers blood sugar. That model has two flaws today: it treats insulin as a force that only ever pushes glucose down (ignoring the sugar your liver steadily releases — "endogenous glucose production", EGP), and it counts all of your background "basal" insulin as active drug. As a result, someone whose pump settings are actually well-tuned looks, to the app, extremely insulin-resistant.

**Reason for change.** This is the single highest-value fix. It cancels correction doses to nearly zero (under-treating highs), and it corrupts every figure the app learns about your body until fixed — so no other prediction work should begin before it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Insulin effect computed from net insulin or explicit EGP term
- [ ] #2 Constants re-tuned with tests
- [ ] #3 A well-tuned fasting user no longer reads as maximally insulin-resistant
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** In predictor.dart:290-291 / insulin_math.dart:107-145, model insulin effect from NET insulin (boluses + delivered−scheduled basal), treating scheduled basal as EGP-neutral — or add an explicit EGP term. Re-tune the model constants afterward.

**Testing.** A well-tuned fasting user must score ≈1.0 (not maximally resistant). Re-tune constants with tests; regression-test corrections no longer collapse. Add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able). `flutter analyze` clean and `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §1 P0-2 (headline issue #1)
- Effort: M
- Where: predictor.dart:290-291, insulin_math.dart:107-145
- Roadmap status: open

- detail-needed (2026-07-06): the structural net-insulin change is clear, but the AC 'constants re-tuned with tests' and 'well-tuned fasting user scores ~1.0' need decisions I can't make autonomously: (1) net-insulin (boluses + delivered-scheduled basal) vs an explicit EGP term — which approach? (2) what data validates the re-tune — the demo SimulatedDay (circular) or real pump/fasting history (needs the live link)? (3) target values for the re-tuned constants. Safety-critical (changes every dose/forecast), so not auto-tuning without a validation target.
<!-- SECTION:NOTES:END -->
