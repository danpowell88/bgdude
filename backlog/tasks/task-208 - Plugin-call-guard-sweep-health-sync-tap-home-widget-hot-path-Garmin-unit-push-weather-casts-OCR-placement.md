---
id: TASK-208
title: >-
  Plugin-call guard sweep: health sync tap, home-widget hot path, Garmin unit
  push, weather casts, OCR placement
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:11'
updated_date: '2026-07-07 18:05'
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
- [x] #1 Each site is guarded at the source: snackbar for the manual tap; log-and-continue for widget/garmin; is-Map guards for weather; readText moved inside the guarded block
- [x] #2 A test per site with a throwing stub
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 18:05
---
Started: guard all 5 sites at the source (settings tap try/catch+snackbar, HomeWidgetService log-and-continue, setGarminUnit via unawaitedLogged, weather is-Map guards, PanelScanService.scan wraps ocr.readText internally) rather than relying on distant callers.
---

author: Claude
created: 2026-07-07 18:05
---
Done. (a) lib/ui/settings_screen.dart: manual sync tap wrapped in try/catch, shows 'Health sync failed: $e' snackbar. (b) lib/widget/home_widget_service.dart: pushUpdate's Future.wait and _renderWidget each guarded with appLog.error + return, so a MissingPluginException degrades to a logged skip instead of throwing out of the per-reading listener or the 1-min staleness ticker. (c) lib/app.dart: setGarminUnit call wrapped with the existing unawaitedLogged helper (tag 'garmin'). (d) lib/weather/weather.dart: parseGeocode/parseCurrent now check 'is Map' before casting (both the top-level body and results.first/current), returning null instead of throwing a TypeError on an unexpected shape. (e) lib/food/panel_scan_service.dart: ocr.readText() moved inside its own try/catch inside scan() itself, returning an empty-text PanelScanResult on failure -- no longer relies on the sole caller's wrapper. Tests: test/settings_screen_health_sync_test.dart (new), test/home_widget_service_glue_test.dart (2 new cases using a throwing MethodChannel mock), test/snapshot_chain_test.dart (new 'garmin' tag case), test/weather_test.dart (4 new non-Map-shape cases), test/panel_scan_service_test.dart (new throwing-OCR case). Full pipeline green: analyze clean, flutter test test/ 1005/1005, flutter build apk --debug succeeded. No native Kotlin touched. doc/user-guide.html: one-line addition noting the sync-now failure snackbar.
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
