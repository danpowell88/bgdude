---
id: TASK-152
title: 'Infusion-site insights: learned set lifetime from siteFailure + site age'
status: To Do
assignee: []
created_date: '2026-07-06 08:43'
updated_date: '2026-07-06 12:58'
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
- [ ] #1 siteFailure annotations plus site-change events are aggregated by site age
- [ ] #2 Median failure age and a TIR-by-set-day curve appear in the Therapy or Events report
- [ ] #3 An optional deviceReminder nudge tuned to the learned lifetime is implemented or explicitly deferred
- [ ] #4 Tests cover the aggregation
- [ ] #5 The user guide is updated
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
