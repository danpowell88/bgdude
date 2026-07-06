---
id: TASK-208
title: >-
  Plugin-call guard sweep: health sync tap, home-widget hot path, Garmin unit
  push, weather casts, OCR placement
status: To Do
assignee: []
created_date: '2026-07-06 21:11'
labels:
  - code-health
  - cleanup
milestone: m-8
dependencies: []
priority: medium
ordinal: 112200
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Five unguarded plugin/parse sites degrade noisily or fragilely:

- (a) manual Sync-health-now tap (`lib/settings/settings_screen.dart:306-311`) awaits unguarded plugin calls (`lib/health_sync.dart:78-79,97-101`) — PlatformException escapes with no user feedback
- (b) `HomeWidgetService` (`lib/home_widget_service.dart:61-70,96`) calls `HomeWidget.saveWidgetData/updateWidget` unguarded on the per-reading path and a 1-minute timer — MissingPluginException after engine restart re-throws every minute
- (c) `setGarminUnit` fire-and-forget in the unit listener (`lib/app.dart:44`) while `PumpClient._invoke` rethrows PlatformException (`lib/pump/pump_client.dart:166-168`)
- (d) weather parsers hard-cast `jsonDecode(body) as Map` / `results.first as Map` (`lib/weather/weather.dart:83,86,98`) — contained today but one refactor from escaping
- (e) `PanelScanService.scan` calls `ocr.readText` OUTSIDE its try (`lib/panel_scan_service.dart:52`) — safe only because the sole caller wraps it

**Reason for change.** Each site should be guarded at the source so plugin failures degrade gracefully instead of escaping or relying on distant callers.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each site is guarded at the source: snackbar for the manual tap; log-and-continue for widget/garmin; is-Map guards for weather; readText moved inside the guarded block
- [ ] #2 A test per site with a throwing stub
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- (a) Wrap the manual health-sync tap with try/catch and show a snackbar on failure
- (b) Guard `HomeWidgetService` saveWidgetData/updateWidget calls with log-and-continue
- (c) Guard the `setGarminUnit` call in the unit listener with log-and-continue
- (d) Add is-Map guards around the weather JSON casts
- (e) Move `ocr.readText` inside the guarded block in `PanelScanService.scan`
- Add one test per site using a throwing stub
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (dart finding 13)
- Effort: S-M
- Where: `lib/settings/settings_screen.dart`, `lib/health_sync.dart`, `lib/home_widget_service.dart`, `lib/app.dart`, `lib/weather/weather.dart`, `lib/panel_scan_service.dart`
- Related: TASK-125, TASK-190
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
