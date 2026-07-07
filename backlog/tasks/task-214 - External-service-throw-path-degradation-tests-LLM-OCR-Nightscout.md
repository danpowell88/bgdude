---
id: TASK-214
title: 'External-service throw-path degradation tests (LLM, OCR, Nightscout)'
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:13'
updated_date: '2026-07-07 19:28'
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
- [x] #1 LLM extract throws: scan returns the parser result, usedLlm false, no throw
- [x] #2 OCR throws: contained
- [x] #3 Throwing http.Client: uploadEntries/uploadDeviceStatus/testConnection never throw
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 19:25
---
Started: checking existing coverage first -- TASK-208 already added an OCR-throw test to panel_scan_service_test.dart (AC#2 may already be satisfied); need to check LLM-throw coverage and build the Nightscout throwing-client tests.
---

author: Claude
created: 2026-07-07 19:28
---
Done. AC#2 (OCR throws contained) was already covered by TASK-208's test in panel_scan_service_test.dart, so this landed the remaining 2:

AC#1: test/panel_scan_service_test.dart gained a _ThrowingLlm double + test asserting a carbs-only OCR text (below the LLM threshold, so the LLM runs and throws) falls back to the deterministic parser's own result -- usedLlm false, no throw. Caught a mistake while writing it: the bare 'Carbohydrate 64.0g' input has no per-100g table structure, so the parser puts the value in perServe, not per100g -- fixed the assertion to match what the parser actually extracts (verified via a throwaway debug test), rather than asserting on a field the real code never populates for this shape.

AC#3: test/nightscout_test.dart's existing 'network errors never throw' group only covered uploadEntries with a throwing http.Client. Added uploadDeviceStatus (also routes through the same guarded _postJson) and testConnection (its own try/catch, returns false rather than swallowing silently) with the same _ThrowingClient.

Pipeline: flutter analyze clean, flutter test test/ 1025/1025, flutter build apk --debug succeeded. No native Kotlin, no user-visible change -- no user-guide update.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
