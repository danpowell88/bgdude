---
id: TASK-21
title: >-
  P2-5 Sensitivity model validation: sign-constrained coefficients; only adopt
  if beats heuristic
status: In Progress
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:43'
labels:
  - roadmap
  - §1-P2
  - ml
dependencies: []
priority: medium
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude learns how your insulin sensitivity shifts (for example by time of day). Recent work made that learning statistically sounder, but two guardrails are missing: the learned coefficients can take physically impossible directions, and the app will use the learned model even when a simple rule-of-thumb would predict better.

**Reason for change.** Without those guardrails the learned model can be confidently wrong. Constraining the directions and only adopting the model when it genuinely beats the simple baseline makes it safe to trust.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Coefficients sign-constrained
- [ ] #2 Learned model adopted only when it beats the heuristic
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** In sensitivity_model.dart constrain coefficient signs (physiology); only adopt the learned model when it beats the heuristic on held-out skill.

**Testing.** Test that wrong-sign coefficients are rejected/clamped and that the heuristic wins when it should. ML-honesty tests first (coverage + bias, synthetic-data recovery); `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P2-5
Effort: M
Roadmap status: partial
<!-- SECTION:NOTES:END -->
