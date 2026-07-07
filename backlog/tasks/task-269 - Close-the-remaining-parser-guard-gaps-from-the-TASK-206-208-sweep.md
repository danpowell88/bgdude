---
id: TASK-269
title: Close the remaining parser-guard gaps from the TASK-206/208 sweep
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 18:33'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 527000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two gaps remain after the guarding sweep. First, the weather parsers guard a valid-JSON-but-wrong-shape body (the is not Map check) but jsonDecode(body) runs BEFORE that check at weather.dart:86 and :105, so a non-JSON body (captive-portal HTML, truncated or empty body returned with HTTP 200) still throws FormatException straight out of parseGeocode/parseCurrent — the exact throws-out-of-a-parser-at-the-source case the commit claims to fix. Not a live crash because both callers catch, so this is a gap against the sweep stated guard-at-source contract. Second, ConfirmationDecisionStore.record() decodes the raw blob directly (not via the per-entry-guarded load()) and its greater-than-1000-entry cap sorts with (b.value as Map)[t] as String; a valid-JSON blob containing one entry whose value is not a Map or lacks t throws out of record() once the store exceeds 1000 entries (narrow, pre-existing edge the sweep did not cover).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Weather parsers wrap jsonDecode itself so a non-JSON body degrades to null rather than throwing
- [ ] #2 ConfirmationDecisionStore.record() cap-sort tolerates a malformed-but-valid-JSON entry (guard the cast, or route record through the guarded load path)
- [ ] #3 Tests cover a non-JSON weather body and a malformed over-cap confirmation entry
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-206/208)
- Files: lib/weather/weather.dart:86,105; lib/feedback/pending_confirmation.dart:101-120
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
