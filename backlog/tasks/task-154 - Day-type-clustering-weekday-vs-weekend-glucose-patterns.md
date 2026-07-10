---
id: TASK-154
title: 'Day-type clustering: weekday vs weekend glucose patterns'
status: Review
assignee:
  - Claude
created_date: '2026-07-06 08:44'
updated_date: '2026-07-10 11:17'
labels:
  - feature
  - insights
  - ml
milestone: m-7
dependencies: []
priority: medium
ordinal: 702400
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Full CGM history is available via `repo.cgm`, `MetricsCalculator` computes per-window TIR/mean/LBGI, and AGP bucketing exists in the report exporter — but a flat AGP hides routine-driven patterns. An on-device unsupervised split (weekday class, optional k-means k=2-3 on per-day feature vectors) surfaces "weekend mornings run higher".

**Value.** Routine-driven patterns are invisible in a single pooled AGP; clustering makes them a first-class insight.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Per-day feature vectors exist (mean, TIR, TBR, peak hour)
- [ ] #2 Weekday/weekend grouping plus optional k-means is implemented
- [ ] #3 A Patterns report section shows per-cluster AGP overlays
- [ ] #4 Tests cover the clustering
- [ ] #5 The user guide is updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Build per-day feature vectors (mean, TIR, TBR, peak hour) from `repo.cgm` via `MetricsCalculator`.
- Implement weekday/weekend grouping and optional k-means (k=2-3).
- Add a Patterns report section with per-cluster AGP overlays reusing the exporter bucketing.
- Add tests.
- Update `doc/user-guide.html`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (report exporter AGP bucketing, `MetricsCalculator`)
- Effort: M
- Where: new ml/insights code, Patterns report section, `doc/user-guide.html`
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-10 11:02
---
branch: task-154
---

author: Claude
created: 2026-07-10 11:17
---
implemented-by: Claude (Sonnet 5, session 5ecb6b72-c69b-4afb-b36c-af3d04f85cad) -- code complete and pushed to branch task-154 (commit 2d10619). Full implementation details, rigor-check notes, and pipeline results recorded on that branch's copy of this task file.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
