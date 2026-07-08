---
id: TASK-269
title: Close the remaining parser-guard gaps from the TASK-206/208 sweep
status: Done
assignee:
  - Claude
created_date: '2026-07-07 18:33'
updated_date: '2026-07-08 05:20'
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
- [x] #1 Weather parsers wrap jsonDecode itself so a non-JSON body degrades to null rather than throwing
- [x] #2 ConfirmationDecisionStore.record() cap-sort tolerates a malformed-but-valid-JSON entry (guard the cast, or route record through the guarded load path)
- [x] #3 Tests cover a non-JSON weather body and a malformed over-cap confirmation entry
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-206/208)
- Files: lib/weather/weather.dart:86,105; lib/feedback/pending_confirmation.dart:101-120
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 05:14
---
Started: fixing weather.dart's jsonDecode-before-guard gap and ConfirmationDecisionStore.record()'s unguarded cap-sort cast.
---

author: Claude
created: 2026-07-08 05:20
---
Fixed both gaps.

AC#1: added a _tryDecode(body) helper in weather.dart that wraps jsonDecode in a try/on FormatException, returning null. parseGeocode and parseCurrent now call it instead of the raw jsonDecode -- a non-JSON body (captive-portal HTML, truncated/empty response) degrades to null instead of throwing straight out of the parser, closing the gap the TASK-208(d) is-Map check never actually reached.

AC#2: pending_confirmation.dart's record() cap-sort comparator now goes through a new _timestampOf(value) helper that returns null for a non-Map value or one missing/wrong-typed t, instead of a hard cast. A malformed entry sorts as oldest (reasonable -- no reliable data to prioritise keeping) rather than throwing once the store exceeds 1000 entries.

AC#3: added tests -- weather_test.dart (non-JSON body for both parseGeocode and parseCurrent: HTML, empty string, truncated JSON), confirmation_inbox_test.dart (seeds 1000 valid entries plus 2 malformed ones directly via KvStore, then calls record() to trigger the cap-sort and confirms it does not throw and the cap still holds).

Rigor check: reverted both fixes to their old unguarded forms -- all 3 corresponding new tests correctly failed (2 weather, 1 confirmation-store). Reverted; git diff clean.

Verified: flutter analyze clean, flutter test --coverage green (1178 tests, 67.84% >= 65% floor). flutter build apk --debug succeeds. No native Kotlin, no user-guide update (internal robustness fix, no user-visible surface).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
