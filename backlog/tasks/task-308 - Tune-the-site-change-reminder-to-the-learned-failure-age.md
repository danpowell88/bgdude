---
id: TASK-308
title: Tune the site-change reminder to the learned failure age
status: To Do
assignee: []
created_date: '2026-07-10 10:38'
labels: []
milestone: m-7
dependencies:
  - TASK-152
ordinal: 722000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-152 added SiteLifetimeReport.medianFailureAgeHours (the personal median siteFailure age relative to the last site change), but checkDeviceReminders (lib/state/providers.dart) still uses the static DeviceKind.site.typicalLife (3 days) for the overdue threshold. Tuning it to the learned median would need that median computed cheaply and cached somewhere accessible from the reminder-check hot path (a periodic background job, similar to sensitivityCensusProvider/forecastDriftProvider's pattern), not the on-demand full-history report scan SiteLifetimeReportBuilder currently does when a report screen opens -- a materially different piece of infrastructure than the reporting feature itself, so deferred out of TASK-152.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The site-change reminder threshold uses a cached learned median failure age when enough data exists (>= SiteLifetimeReportBuilder.minFailuresForMedian), falling back to the static 3-day typicalLife otherwise
- [ ] #2 The learned median is refreshed periodically (e.g. alongside another existing startup job), not recomputed on every reminder check
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test --coverage test/ green
- [ ] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [ ] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
- [ ] #10 Reviewed by a different agent than the implementer -- a reviewed-by comment is present and the task passed through Review before Done
<!-- DOD:END -->
