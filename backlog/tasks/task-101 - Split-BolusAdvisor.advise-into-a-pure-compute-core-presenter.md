---
id: TASK-101
title: Split BolusAdvisor.advise() into a pure compute core + presenter
status: To Do
assignee: []
created_date: '2026-07-06 04:53'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - dosing-math
  - "\U0001F512 safety"
  - testing
  - detail-needed
milestone: m-8
dependencies: []
priority: high
ordinal: 100300
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `advise()` in `lib/analytics/bolus_advisor.dart:137-324` is a ~187-line method that interleaves the clinical dose math (meal dose, FPU/extended bolus, correction, Control-IQ adjustment, predicted-low guard, capping, rounding) with building the human-readable working list as formatted strings, inline as it computes.

Clinical constants are embedded mid-method:

- FPU calorie split `(fat*9 + protein*4) / 100`
- extend-hours heuristic `(fpu.ceil() + 2).clamp(3, 8)`
- Control-IQ correction halving `*= 0.5`
- the `0.05 U` action threshold
- pump-increment rounding `roundToDouble()/100`

**Reason for change.** The numeric decisions cannot be unit-tested without parsing display strings, and any wording or localisation change forces edits inside safety-critical calculation code. The magic numbers are not reachable or testable in isolation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pure compute step returns a numeric result object (meal/correction/FPU units, modifiers applied, cap and guard flags) with zero string formatting
- [ ] #2 A separate presenter builds the AdviceStep working list from that result; advice output is unchanged (existing tests pass)
- [ ] #3 Clinical constants hoisted to named static consts with doc comments
- [ ] #4 New unit tests assert on the numeric fields directly, not on strings
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Introduce a `BolusComputation` value object carrying every number and flag the working list needs.
- Move the math from `advise()` into a pure `compute()`; keep inputs explicit.
- Write a presenter that renders the `AdviceStep` list and notes from the computation; diff its output against current strings before/after.
- Hoist the FPU split, extend-hours clamp, Control-IQ 0.5 factor, 0.05 U threshold and rounding increment to named constants.
- Add numeric unit tests: correction with/without Control-IQ, FPU extension, cap hit, low-guard trip.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: code-health survey 2026-07-06 (lib finding 1)
- Effort: M
- Where: `lib/analytics/bolus_advisor.dart:137-324`
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:25
---
detail-needed (2026-07-06, goal triage): an invasive refactor of the safety-critical BolusAdvisor.advise() — splitting compute from presentation. Want the core return shape / core-vs-presenter boundary confirmed before restructuring dosing code (high blast radius; the advise() path was just modified by P0-1/4/6).
---
<!-- COMMENTS:END -->
