---
id: TASK-244
title: Gate the sign-constrained sensitivity model on the model actually deployed
status: Done
assignee:
  - Claude
created_date: '2026-07-07 13:28'
updated_date: '2026-07-07 21:04'
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
- [x] #1 Adoption gate compares the sign-constrained model CV MSE (the deployed model) against the heuristic, not the unconstrained fit
- [x] #2 Reported cvSkill / confidence reflects the deployed constrained model
- [x] #3 Test: a fit that passes the gate unconstrained but loses after constraining is not adopted
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-07 (follow-up to TASK-21)
- File: lib/ml/sensitivity_model.dart around the adoption gate and _signConstrained store
- Decision: GBM-not-neural / honest intervals — a confidence that overstates skill violates the honest-intervals principle
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 20:54
---
Started: investigating sensitivity_model.dart's adoption gate/cvSkill computation to fix the unconstrained-vs-sign-constrained mismatch.
---

author: Claude
created: 2026-07-07 21:04
---
Done. lib/ml/sensitivity_model.dart's _looMse now applies _signConstrained to EACH LOO fold's fit before scoring it (previously fit unconstrained), so the adoption gate (bestMse >= heuristicMse) and the resulting cvSkill both measure the sign-constrained model that actually gets deployed, not a different, unconstrained model that only ever existed during CV. Updated the train()/_looMse doc comments -- the original 'constraining every fold would be far more expensive' rationale for skipping this was itself mistaken (constraining is a cheap O(features) post-processing step, negligible next to the O(n^3) ridge solve).

Test (AC#3): test/sensitivity_training_test.dart's TASK-21 guardrails group gained a case engineered so a wrongly-signed SpO2-delta confound (chosen because heuristicSensitivity doesn't read SpO2 at all, so the heuristic baseline stays uncontaminated) lets an UNCONSTRAINED fit exploit it to a near-perfect (cvSkill ~0.89) fit that clears the gate, while the small remaining sleep-only signal that survives sign-constraining is genuinely worse than the heuristic's own tuned thresholds.

Verification process was itself iterative and worth recording: constructing a dataset where 'unconstrained passes, constrained fails' isn't trivial -- several earlier attempts either had the constrained model still winning (the confound wasn't wrong-signed strongly enough relative to noise), or had the confound overwhelm the heuristic's own baseline so much that neither variant could beat it. Settled on confounding a feature the heuristic ignores (SpO2) with labels matching the heuristic's OWN sleep-bucket structure plus a small wrong-signed SpO2 offset. Confirmed the final data set by temporarily reverting _looMse to unconstrained and checking it DID pass (isTrained/beatsHeuristic true, cvSkill 0.89) before restoring the fix and confirming it now correctly declines (isTrained/beatsHeuristic/cvSkill/model all null-or-false). Reverted the temp change immediately after each check (git diff clean).

Pipeline: flutter analyze clean, flutter test test/ 1051/1051, flutter build apk --debug succeeded. No native Kotlin, no user-visible change (internal model-quality fix, per the honest-intervals decision).
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
