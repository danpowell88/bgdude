---
id: TASK-193
title: Hostile-input corpus tests for persisted and external parsers
status: To Do
assignee: []
created_date: '2026-07-06 12:56'
updated_date: '2026-07-06 12:58'
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
- [ ] #1 A shared hostile-input table (truncated JSON, wrong types, missing keys, huge numbers, negative timestamps, empty strings) applied per parser
- [ ] #2 PumpSnapshot.fromJson, each KV decoder, Nightscout entry/treatment parsing, and the panel parser each survive the full table (typed failure or default, never a throw that escapes)
- [ ] #3 Corpus lives in test/support/ so new parsers adopt it
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
