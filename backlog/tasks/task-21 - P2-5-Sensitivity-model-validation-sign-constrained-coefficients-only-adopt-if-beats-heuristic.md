---
id: TASK-21
title: >-
  Sensitivity model validation: sign-constrained coefficients; only adopt if
  beats heuristic
status: In Progress
assignee:
  - Claude
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 08:05'
labels:
  - roadmap
  - ml
milestone: m-5
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
