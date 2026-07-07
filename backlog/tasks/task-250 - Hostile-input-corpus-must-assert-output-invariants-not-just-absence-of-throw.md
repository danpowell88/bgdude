---
id: TASK-250
title: 'Hostile-input corpus must assert output invariants, not just absence of throw'
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 14:28'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 152000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
In hostile_input_corpus_test.dart the PumpSnapshot and SavedMeal cases are expect with an inner try/catch that swallows any throw, so the outer closure always returns normally. The assertion passes if the parser throws, passes if it returns garbage, and can only fail on a hard isolate crash. PumpSnapshot.fromJson does no clamping, so a hostile batteryPercent -81 or reservoirUnits 1.79e308 produces a nonsensical snapshot that flows into the app unchecked. The TherapySegment block in the same file is the correct pattern: it asserts isf greater than 0 and carbRatio greater than 0 on success. The other targets should likewise assert output invariants or a clean rejection.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 PumpSnapshot and SavedMeal corpus cases assert either a clean rejection or a safe clamped output invariant, not merely returnsNormally
- [ ] #2 No corpus case swallows the exception and then asserts on the swallowing closure
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-193)
- File: test/hostile_input_corpus_test.dart PumpSnapshot and SavedMeal blocks
- Model the fix on the TherapySegment block already in the file
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
