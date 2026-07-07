---
id: TASK-243
title: >-
  Strengthen read-only pump guard to catch fully-qualified and sendCommand
  writes
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 13:28'
labels: []
milestone: m-0
dependencies: []
priority: high
ordinal: 110000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The architecture guard added in TASK-41 only flags lines matching an import of com.jwoglom.pumpx2.pump.messages.request.control.* . Native pump writes actually happen via sendCommand(p, SomeRequest()) (see PumpCommHandler.kt). A control/write request invoked by fully-qualified name (sendCommand(p, com.jwoglom.pumpx2.pump.messages.request.control.InitiateBolusRequest())) has no matching import line and passes the guard. The self-test only asserts the regex matches a literal import string; it never exercises a real write call. The guard therefore cannot catch the very thing the read-only charter needs it to catch.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Guard detects control/write requests referenced by fully-qualified name, not only via import lines
- [ ] #2 Guard detects sendCommand(...) calls carrying a control-package request type
- [ ] #3 Test includes a positive fixture (a simulated write call) that the guard actually flags, not just an import-string match
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-07 (follow-up to TASK-41)
- Charter: decision-1 read-only pump — this guard is the automated backstop for it
- Reference: PumpCommHandler.kt sendCommand path is the real write mechanism
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
