---
id: TASK-214
title: 'External-service throw-path degradation tests (LLM, OCR, Nightscout)'
status: To Do
assignee: []
created_date: '2026-07-06 21:13'
labels:
  - code-health
  - testing
milestone: m-8
dependencies: []
priority: medium
ordinal: 112800
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The designed fallbacks are untested on their THROW paths: the `PanelScanService` catch at `lib/panel_scan_service.dart:71` (LLM extract throwing falls back to parser-only) has no test; OCR throwing is untested; `NightscoutClient._postJson` swallows (`lib/nightscout.dart:228`) but no test injects a throwing http.Client (the ctor seam at `lib/nightscout.dart:95` exists — note `nightscoutClientProvider` at `lib/providers.dart:1294` does not pass a client, so tests override the provider).

**Reason for change.** The graceful-degradation contracts for LLM, OCR, and Nightscout exist only by inspection; a regression would go unnoticed until a real outage.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 LLM extract throws: scan returns the parser result, usedLlm false, no throw
- [ ] #2 OCR throws: contained
- [ ] #3 Throwing http.Client: uploadEntries/uploadDeviceStatus/testConnection never throw
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a PanelScanService test with a throwing PanelLlm stub: scan returns the parser result, usedLlm false, no throw
- Add an OCR-throwing case and assert it is contained
- Construct NightscoutClient with a throwing http.Client via the ctor seam (`lib/nightscout.dart:95`); assert uploadEntries/uploadDeviceStatus/testConnection never throw (tests override `nightscoutClientProvider` since it does not pass a client)
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (injection finding 19)
- Effort: S
- Where: `lib/panel_scan_service.dart:52-71`, `lib/nightscout.dart:95,228`, new tests
- Related: TASK-27, TASK-61, TASK-85
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
