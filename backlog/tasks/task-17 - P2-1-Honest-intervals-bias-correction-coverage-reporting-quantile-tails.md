---
id: TASK-17
title: 'Honest intervals: bias correction + coverage reporting + quantile tails'
status: In Progress
assignee:
  - Claude
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 08:10'
labels:
  - roadmap
  - ml
milestone: m-5
dependencies:
  - TASK-46
  - TASK-47
priority: medium
ordinal: 17000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** When bgdude forecasts your glucose, it also draws a shaded band showing how uncertain that forecast is. Recently the band's width was put on a proper statistical footing, but it is still symmetric (equal room above and below) and its real-world accuracy isn't measured or shown. Glucose risk isn't symmetric — the chance of dropping vs rising differs by situation.

**Reason for change.** A band you can trust — asymmetric, calibrated, and with its track record visible — is what makes the forecast and any forecast-based alerts believable rather than just plausible. The detailed build is split into two follow-on tasks (quantile bands and calibration).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Per-horizon coverage reported
- [ ] #2 Mean signed error (bias) reported
- [ ] #3 Quantile tails implemented
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add bias correction (mean signed error).
- Add per-horizon coverage reporting on `ModelAccuracyScreen` from stored `lower/upperMgdl`.
- Implement quantile tails via TASK-46 (section 4-1.1).
- Prerequisite: P0-2.
- ML-honesty tests first: per-horizon coverage + mean-signed-error surfaced and asserted on synthetic data; quantile recovery test in `gbm_test`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1, P2-1 → TASK-46/TASK-47 (sections 4-1.1/4-1.2)
- Effort: M
- Roadmap status: partial
<!-- SECTION:NOTES:END -->
