---
id: TASK-17
title: 'P2-1 Honest intervals: bias correction + coverage reporting + quantile tails'
status: In Progress
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:43'
labels:
  - roadmap
  - §1-P2
  - phase-5
  - ml
dependencies: []
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
**Technical notes.** Add bias correction (mean signed error) and per-horizon coverage reporting on ModelAccuracyScreen from stored lower/upperMgdl; implement quantile tails via §4-1.1 (TASK-46). Prerequisite: P0-2.

**Testing.** Per-horizon coverage + mean-signed-error surfaced and asserted on synthetic data; quantile recovery test in gbm_test. ML-honesty tests first (coverage + bias, synthetic-data recovery); `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §1 P2-1 → §4-1.1/1.2
- Effort: M
- Roadmap status: partial
<!-- SECTION:NOTES:END -->
