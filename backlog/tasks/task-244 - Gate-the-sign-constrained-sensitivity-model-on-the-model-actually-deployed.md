---
id: TASK-244
title: Gate the sign-constrained sensitivity model on the model actually deployed
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 13:28'
labels: []
milestone: m-5
dependencies: []
priority: high
ordinal: 180000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
In sensitivity_model.dart the adoption gate (bestMse >= heuristicMse) and the reported cvSkill are both computed from the unconstrained ridge fit leave-one-out MSE, but the model stored is the sign-constrained fit (wrong-signed coefficients zeroed). So the deployed model is not the one whose skill cleared the gate: a fit can pass the beats-heuristic bar with its full coefficient set, then have coefficients zeroed, leaving a different model no longer guaranteed to beat the heuristic. contextFor() then scales confidence by a cvSkill that overstates the constrained model true skill. Bounded (mult clamped 0.6 to 1.5, confidence <= 0.9) but a real silent-regression path.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Adoption gate compares the sign-constrained model CV MSE (the deployed model) against the heuristic, not the unconstrained fit
- [ ] #2 Reported cvSkill / confidence reflects the deployed constrained model
- [ ] #3 Test: a fit that passes the gate unconstrained but loses after constraining is not adopted
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-07 (follow-up to TASK-21)
- File: lib/ml/sensitivity_model.dart around the adoption gate and _signConstrained store
- Decision: GBM-not-neural / honest intervals — a confidence that overstates skill violates the honest-intervals principle
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
