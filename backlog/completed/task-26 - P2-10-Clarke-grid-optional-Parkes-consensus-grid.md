---
id: TASK-26
title: 'Clarke grid: optional Parkes/consensus grid'
status: Done
assignee:
  - Claude
created_date: '2026-07-06 03:10'
updated_date: '2026-07-07 12:39'
labels:
  - roadmap
  - ml
milestone: m-5
dependencies: []
priority: low
ordinal: 109300
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** To grade forecast accuracy against actual outcomes, bgdude plots errors on a "Clarke error grid" — a clinical chart that sorts prediction errors by how dangerous they'd be. The "Parkes" (consensus) grid is a newer, more widely-accepted version of the same idea.

**Reason for change.** This is an optional modernisation: moving to the Parkes grid reflects current clinical consensus on which errors matter most.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Parkes/consensus grid zones implemented
- [x] #2 Per-zone reference tests (as done for Clarke)
- [x] #3 ModelAccuracyScreen uses/offers the chosen grid
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Implement Parkes/consensus grid zones alongside Clarke.
- Make `ModelAccuracyScreen` use/offer the chosen grid.
- Reuse the existing zone reference-test pattern: per-zone reference tests (as already done for Clarke) against published boundary points.
- Run ML-honesty tests first (coverage + bias, synthetic-data recovery).
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1 P2-10
- Effort: M
- Roadmap status: partial
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 12:39
---
Done. Verified boundary coordinates against a reliable, citable source rather than guessing at a clinical grid — the published papers' own tables rendered inconsistently through automated extraction, so I pulled the exact Type 1 diabetes zone polygons from the peer-reviewed 'ega' CRAN package's getParkesZones (github.com/cran/ega, R source), which itself cites Parkes et al. 2000 (Diabetes Care) and Pfützner et al. 2013 (JDST). New lib/ml/parkes_error_grid.dart: point-in-polygon classification (ray-casting) over the same B/C/D/E polygons as that reference implementation, extended to a fixed 1000 mg/dL bound (well past any real CGM/meter reading) instead of a data-dependent plot limit. AC#2: 6 reference tests in test/parkes_error_grid_test.dart, each hand-verified against the polygon geometry (one initial test point turned out to sit in an overlapping B+C+D region and had to be relocated once the implementation correctly resolved it to the more-severe D — a good sign the check-order-overwrite logic, matching the reference implementation exactly, is working). AC#3: BandEvaluation (accuracy_report.dart) now also carries parkesAbFraction/parkesDangerousFraction computed from the same pairs as the Clarke eval, and ModelAccuracyScreen shows both A+B figures side by side per horizon — the model-promotion gate is untouched and stays pinned to Clarke. doc/user-guide.html updated. Pipeline green: analyze clean, 771 tests passed, apk debug build succeeds.
---
<!-- COMMENTS:END -->
