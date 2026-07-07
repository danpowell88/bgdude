---
id: TASK-193
title: Hostile-input corpus tests for persisted and external parsers
status: Done
assignee:
  - Claude
created_date: '2026-07-06 12:56'
updated_date: '2026-07-07 13:45'
labels:
  - code-health
  - testing
milestone: m-8
dependencies: []
priority: medium
ordinal: 109000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Parsers that consume persisted or external input have no malformed-input coverage: `PumpSnapshot.fromJson` (native bridge), the KV decoders (meal library, prefs, thresholds, therapy), `NightscoutClient` response parsing, and the nutrition panel parser (a well-formed corpus exists at `test/data/nutrition_panels.json` but no hostile variants). A table-driven hostile corpus catches whole classes of crash/corruption bugs cheaply and guards the fixes from TASK-181 and the KV hardening ticket.

**Reason for change.** Every one of these inputs crosses a trust boundary (native process, network, disk that can corrupt); each should provably survive garbage.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A shared hostile-input table (truncated JSON, wrong types, missing keys, huge numbers, negative timestamps, empty strings) applied per parser
- [x] #2 PumpSnapshot.fromJson, each KV decoder, Nightscout entry/treatment parsing, and the panel parser each survive the full table (typed failure or default, never a throw that escapes)
- [x] #3 Corpus lives in test/support/ so new parsers adopt it
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Build the generator/table in test/support/hostile_inputs.dart.
- Apply per parser; fix or wrap any parser that escapes (coordinate with the KV-hardening ticket).
- Add a malformed-panels section beside nutrition_panels.json.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep 2026-07-06
- Effort: M
- Where: test/support/, parsers listed above
- Related: TASK-108 (fixtures), TASK-120 (snapshot versioning), TASK-181
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 13:45
---
Done. test/support/hostile_inputs.dart: hostileVariantsOf(goodJson) mutates a known-good reference map one key at a time (missing, null, wrong type, huge number, negative, empty string) plus whole-map mutations (empty map, all-null); hostileTimestampVariantsOf adds a negative/zero/far-future epoch pass for timestamp fields. hostileTextInputs covers the text-shaped parser (empty/whitespace/garbage/absurdly-long/control-characters/huge-negative-embedded/valid-but-wrong-shape-JSON). Applied across all 4 live targets in test/hostile_input_corpus_test.dart (135 test cases): PumpSnapshot.fromJson, TherapySegment/TherapySettings.fromJson (also re-confirms TASK-190's isf/carbRatio sanitization holds under the FULL corpus, not just the hand-picked cases), SavedMeal.fromJson, and NutritionPanelParser.parse. Found each is ALREADY protected at its real call site by prior work (PumpClient._onEvent's try/catch from TASK-181, restoreJsonGuarded from TASK-188, MealLibraryNotifier's per-item try/catch from TASK-188) — so this corpus proves those guards hold across many more mutation combinations than the existing hand-picked tests, rather than finding a new unguarded parser. Nightscout entry/treatment parsing (also named in the ticket) has no test: verified the app only ever uploads to Nightscout and checks HTTP status codes, never deserializes a response body into domain data — no parser exists there to target. Pipeline green: analyze clean, 917 tests passed, apk debug build succeeds.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
