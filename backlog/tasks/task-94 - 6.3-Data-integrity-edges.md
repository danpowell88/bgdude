---
id: TASK-94
title: Data integrity edges
status: To Do
assignee:
  - Claude
created_date: '2026-07-06 03:10'
updated_date: '2026-07-07 11:02'
labels:
  - roadmap
  - data-integrity
  - detail-needed
milestone: m-7
dependencies: []
priority: medium
ordinal: 104900
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Real-world data has messy edges: gaps in the CGM stream, the noisy sensor warm-up period, a compression low, time-zone/daylight-saving shifts across your history, and a meter whose clock has drifted.

**Reason for change.** Handling these edges prevents corrupted statistics and misplaced events — the kind of subtle bugs that only show up on real data over time.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 CGM gaps handled without corrupting metrics
- [x] #2 Warm-up/compression readings robustly excluded
- [ ] #3 Timezone/DST correct across historical data
- [x] #4 Meter clock-skew detected and surfaced
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- CGM gap handling.
- Sensor warm-up/compression robustness.
- Timezone/DST across history.
- Meter clock-drift detection (`PumpSnapshot.fromJson` falls back to `DateTime.now()` with no skew detection).
- Unit tests per edge (gaps, warm-up, DST boundary, clock skew); add/extend under `test/`.
- Verify: `flutter analyze` clean, `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 6
- Effort: M
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:30
---
detail-needed (2026-07-06, goal triage): Data-integrity edges span several sub-fixes, some needing real-history verification (DST across history, meter clock drift); wants scoping into concrete sub-tickets.
---

author: Claude
created: 2026-07-06 19:05
---
AC#4 delivered (commit above): meter clock-skew detection (future-stamped newest reading vs phone, 15-min tolerance) surfaced as a controller warning + tests. AC#2 (warm-up/compression robustly excluded) is already in place — MetricsCalculator and the ml/reports exclusion predicates skip sensorWarmup, isCalibration (TASK-9) and compressionLow. AC#1 (CGM gaps don't corrupt metrics) is handled by design — metrics compute TIR/mean over valid readings and report a separate active-time fraction, so a gap lowers coverage rather than skewing TIR; happy to add a targeted gap test if a specific corruption case is in mind. AC#3 (timezone/DST correct across historical data) is the remaining real work and needs focused attention: day-bucketing uses local DateTime, so a DST boundary can mis-bucket a day's readings — fixing it well needs deciding on a canonical time basis (store/compare in UTC vs local-with-DST-aware bucketing) and a DST-boundary test corpus; flagged for a focused pass.
---

author: Claude
created: 2026-07-07 11:02
---
Verified AC#1 and closed the gap: re-checked the prior comment's claim against the actual code (GlucoseMetrics.activeFraction/expectedReadings/sufficient in metrics.dart) — it holds: TIR is a fraction over readings actually present, so a CGM gap reduces activeFraction/marks sufficient=false (coverage caveat) rather than skewing the TIR ratio itself. Added the missing test: 12 real days spread across a 19-day span (8-day gap) — TIR stays exactly 1.0 while activeFraction drops below 0.70 and sufficient flips false (test/metrics_test.dart). AC#3 (timezone/DST) remains the real open item — flagged in the prior comment as needing a canonical-time-basis decision (UTC vs local-with-DST-aware bucketing). Pipeline green: analyze clean, 759 tests passed (test-only change, no apk rebuild needed).
---
<!-- COMMENTS:END -->
