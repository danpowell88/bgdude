---
id: TASK-243
title: >-
  Strengthen read-only pump guard to catch fully-qualified and sendCommand
  writes
status: Done
assignee:
  - Claude
created_date: '2026-07-07 13:28'
updated_date: '2026-07-07 15:06'
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
- [x] #1 Guard detects control/write requests referenced by fully-qualified name, not only via import lines
- [x] #2 Guard detects sendCommand(...) calls carrying a control-package request type
- [x] #3 Test includes a positive fixture (a simulated write call) that the guard actually flags, not just an import-string match
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-07 (follow-up to TASK-41)
- Charter: decision-1 read-only pump — this guard is the automated backstop for it
- Reference: PumpCommHandler.kt sendCommand path is the real write mechanism
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 14:59
---
Started: reviewing test/architecture_test.dart's TASK-41 guard + PumpCommHandler.kt's sendCommand path to close the fully-qualified-name and sendCommand(...) gaps.
---

author: Claude
created: 2026-07-07 15:06
---
Verified the pumpx2-messages request.control package's full class list (54 classes) against the cached jar via unzip -l -- confirmed every one is a write/command request (bolus, factory reset, IDP edits, temp rates, cartridge/tubing modes, etc.), never a read, so flagging bare construction of any of these names anywhere in a .kt file is safe with zero false positives. Added _controlRequestClassNames (the full verified list) + _controlConstructionsIn/_controlConstructionViolations to test/architecture_test.dart: a \b<name>( match catches an import, a star-import + bare construction, AND a fully-qualified inline construction (sendCommand(p, com.jwoglom....control.InitiateBolusRequest())) that the original import-line-only regex had no import line to match. Grepped the real android/app/src/main/kotlin tree for all 54 names first to confirm zero existing hits (guard passes clean today). Added 3 new sanity tests: a fully-qualified sendCommand call with NO import line (AC#3's 'simulated write call', explicitly asserts the OLD guard would have missed it), a star-import + bare-name sendCommand call (AC#2), and a real read-request name (InsulinStatusRequest) asserting no false positive. flutter analyze clean, flutter test test/ green (942 tests), flutter build apk --debug succeeded. Test-only change; no native Kotlin/user-visible/screen changes, so DoD #5/#6/#7 n/a.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
