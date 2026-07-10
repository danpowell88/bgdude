---
id: TASK-152
title: 'Infusion-site insights: learned set lifetime from siteFailure + site age'
status: Review
assignee:
  - Claude
created_date: '2026-07-06 08:43'
updated_date: '2026-07-10 10:42'
labels:
  - feature
  - insights
milestone: m-7
dependencies:
  - TASK-149
priority: medium
ordinal: 702200
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `deviceStateProvider` tracks `DeviceKind.site` age (used at `lib/state/providers.dart:1531`) and `AnnotationKind.siteFailure` annotations are stored (produced by Explain-this-reading `lib/insights/reading_explainer.dart:317-334`, plus the new StubbornHigh producer). Correlating failures and TIR against site age learns this users effective set lifetime ("failures cluster after ~2.6 days").

**Value.** Turns scattered failure annotations into a personal set-lifetime estimate and an actionable change-day nudge.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 siteFailure annotations plus site-change events are aggregated by site age
- [x] #2 Median failure age and a TIR-by-set-day curve appear in the Therapy or Events report
- [x] #3 An optional deviceReminder nudge tuned to the learned lifetime is implemented or explicitly deferred
- [x] #4 Tests cover the aggregation
- [x] #5 The user guide is updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Aggregate siteFailure annotations and site-change events by site age.
- Compute median failure age and the TIR-by-set-day curve; render in the Therapy or Events report.
- Decide on the deviceReminder nudge tuned to the learned lifetime (implement or defer).
- Add tests.
- Update `doc/user-guide.html`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/state/providers.dart:1531`, `lib/insights/reading_explainer.dart:317-334`)
- Effort: M
- Where: report layer, `lib/insights/`, `doc/user-guide.html`
- Related: TASK-77 for the nudge
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-10 10:31
---
branch: task-152
---

author: Claude
created: 2026-07-10 10:31
---
Started: reading deviceStateProvider (site age), siteFailure annotation producers, and the Therapy/Events report structures to design the age-at-failure aggregation.
---

author: Claude
created: 2026-07-10 10:42
---
implemented-by: Claude (Sonnet 5, session 5ecb6b72-c69b-4afb-b36c-af3d04f85cad) -- new lib/reports/site_lifetime_report.dart (SiteLifetimeReportBuilder: for each siteFailure annotation, finds the most recent DeviceKind.site DeviceChange before it and records the age; median requires >=3 data points to avoid calling noise a pattern; TIR-by-set-day buckets in-range CGM samples by day-of-wear relative to the preceding site change, reusing MetricsCalculator for the TIR math per bucket, capped at 14 tracked days since anything older almost certainly means a missed change-log entry, not a genuinely 14-day-old set). New siteLifetimeReportProvider (providers.dart) wires ReportDataset (annotations, cgmInRange) + deviceStateProvider's site-kind changes. UI: new 'Infusion-site lifetime' section on the Therapy report screen (median-age headline + a TIR-by-day bar chart via fl_chart, mirroring the existing TDD/sensitivity chart styles on the same screen). AC#3 (device-reminder nudge): DEFERRED -- filed TASK-308. Reasoning: tuning checkDeviceReminders to the learned median needs it computed/cached cheaply and refreshed periodically (like sensitivityCensusProvider/forecastDriftProvider's pattern), not the on-demand full-history scan this report does when its screen opens -- materially different infrastructure than the reporting feature. Tests: test/reports/site_lifetime_report_test.dart -- failure-age computation, no-preceding-change skip (not counted as age zero), median's >=3 floor, out-of-range exclusion, TIR-by-day bucketing (including a same-day in-range vs next-day-high case), pre-first-change exclusion, and the 14-day tracking cap. Rigor-checked the day-bucketing math (temp-bug forcing every sample into day 1, confirmed the TIR-by-day test fails with 0.5 instead of the predicted 1.0/0.0 split, reverted cleanly). Full pipeline green: analyze clean, 1374 tests passing, coverage 68.52% (floor 65%), apk build succeeded. No native Kotlin changed. Integration test: Therapy report already has integration_test coverage; could not run it live (same emulator VM-service limitation as TASK-141/143/151) -- the new section is additive and conditionally hidden (siteLifetime.hasData) so existing assertions are unaffected.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
