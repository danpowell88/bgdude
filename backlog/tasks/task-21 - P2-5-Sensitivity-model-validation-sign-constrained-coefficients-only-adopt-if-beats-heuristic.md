---
id: TASK-21
title: >-
  Sensitivity model validation: sign-constrained coefficients; only adopt if
  beats heuristic
status: Done
assignee:
  - Claude
created_date: '2026-07-06 03:10'
updated_date: '2026-07-07 10:44'
labels:
  - roadmap
  - ml
milestone: m-5
dependencies: []
priority: medium
ordinal: 103600
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude learns how your insulin sensitivity shifts (for example by time of day). Recent work made that learning statistically sounder, but two guardrails are missing: the learned coefficients can take physically impossible directions, and the app will use the learned model even when a simple rule-of-thumb would predict better.

**Reason for change.** Without those guardrails the learned model can be confidently wrong. Constraining the directions and only adopting the model when it genuinely beats the simple baseline makes it safe to trust.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Coefficients sign-constrained
- [x] #2 Learned model adopted only when it beats the heuristic
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- In `sensitivity_model.dart`, constrain coefficient signs to physiologically valid directions.
- Only adopt the learned model when it beats the heuristic on held-out skill.
- Run ML-honesty tests first (coverage + bias, synthetic-data recovery).
- Test: wrong-sign coefficients are rejected/clamped; the heuristic wins when it should.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1 P2-5
- Effort: M
- Roadmap status: partial
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 10:44
---
Done: SensitivityModel.train() now (1) sign-constrains coefficients post-fit against a physiologically-motivated expected-sign table (e.g. illness/luteal/elevated-HR/elevated-temp must be >=0; more sleep/exercise/HRV/SpO2 must be <=0), zeroing any coefficient that fit the wrong sign — applied to the final model, not inside the LOO-CV search (constraining every fold would be much more expensive for no real benefit at this data scale); (2) only adopts the fit when its weighted LOO-CV MSE beats heuristicSensitivity's weighted in-sample MSE on the same examples, else declines (model stays null) and callers already fall back to the heuristic via effectiveSensitivityProvider's existing confidence==0 check — no caller changes needed. Added SensitivityModel.beatsHeuristic for introspection. Tests in test/sensitivity_training_test.dart: a confounded-sign scenario (illness co-occurs with long sleep) proves the wrong-signed coefficient gets clamped to exactly 0 while the model still trains off sleep's real signal; a scenario where labels are exactly the heuristic's own step-function output proves a linear fit can't beat it and the model is declined. Pipeline green: analyze clean, 750 tests passed, apk debug build succeeds.
---
<!-- COMMENTS:END -->
