---
id: TASK-247
title: Guard the reading-explainer ISF division with safeDivide
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 13:32'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 150000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-190 added safeDivide / finite guards to the ISF/CR dose chain in bolus_advisor.dart, predictor.dart and carb_math.dart, but left a fourth sibling division unguarded: reading_explainer.dart line 316, final absorbedUnits = expectedDrop / seg.isf. If seg.isf == 0 the absorbedUnits becomes Infinity and the site-failure Explanation detail renders literally roughly Infinity U of insulin was absorbed in the Explain this reading UI — the exact NaN/Infinity-reaches-the-UI failure TASK-190 set out to kill. seg.isf is guarded at the UI dialog and TherapySegment.fromJson, but a segment built via the const constructor, placeholder or copyWith still reaches this line unguarded, and TASK-190 own philosophy is defense-in-depth. This is the recurring same-window spot-fix pattern: the fix patched three sites and missed the fourth.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 reading_explainer.dart absorbedUnits uses safeDivide (or equivalent finite guard), never emitting Infinity/NaN
- [ ] #2 Site-failure explanation text is suppressed or falls back gracefully when ISF is zero/degenerate
- [ ] #3 Test: a zero-ISF in-memory segment does not produce an Infinity/NaN in the explanation string
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-07 (follow-up to TASK-190)
- File: lib/insights/reading_explainer.dart:316
- Sibling sites reading_explainer.dart:470 and predictor.dart:306 route through carbSensitivityFactor and already inherit the guard; only this direct division was missed
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
