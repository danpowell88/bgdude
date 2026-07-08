---
id: TASK-303
title: >-
  AlertThresholds restore must enforce the urgentLow<low<high ordering --
  per-field range alone can still suppress a hypo alert
status: To Do
assignee:
  - Claude
created_date: '2026-07-08 09:26'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 120500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-302 added per-field range rejection to AlertThresholds.fromJson (_sanitizeMgdl rejects low/high/urgentLow outside 20-600 to defaults). That is correct for its literal scope, but it validates each field INDEPENDENTLY with no ordering check, and 20-600 is a plausible-BG-reading band, not a plausible-threshold band -- so a corrupt-but-individually-in-range triple survives restore and can suppress a genuine low alert. Concrete: a persisted low corrupted to 40 is within 20-600 so _sanitizeMgdl passes it unchanged; it is now below the fixed urgentLow=55. AlertMonitor.evaluate (alert_monitor.dart:67) gates the ENTIRE low branch on minF.mgdl < lowMgdl, and urgentLow (:68) is only evaluated inside that branch -- so a genuine predicted hypo at ~50 mg/dL matches neither (50 < 40 is false) and fires NOTHING: both predictedLow and urgentLow are suppressed. This is exactly the suppress-a-genuine-low failure TASK-302 set out to prevent. Legitimate values can't mis-order (the UI stepper clamps low to 60-110, high to 140-300, urgentLow is not user-editable) so ordering only ever breaks via the corrupt/tampered restore path this hardening targets. Related in-band mis-orders also slip through (urgentLow=20 suppresses urgent across 20-55; high=50 fires predicted-high constantly).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 AlertThresholds.fromJson enforces urgentLow < low < high after per-field sanitising -- a triple that violates ordering is rejected to the safe defaults (or normalised) rather than accepted as-is, top-level and per-segment
- [ ] #2 The accepted threshold band is tightened toward a clinical range (e.g. ~40-400) rather than the 20-600 reading band, so an implausible threshold is rejected
- [ ] #3 Defense-in-depth: AlertMonitor evaluates urgentLow independently so a mis-ordered config (low <= urgentLow) can never make urgentLow unreachable
- [ ] #4 The hostile-input corpus asserts the ordering invariant (a mis-ordered stored triple decodes to safe, correctly-ordered defaults), not just per-field range
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 verifying the TASK-302 fix (2c0e4f7)
- Files: lib/insights/alert_thresholds.dart:37 _sanitizeMgdl (no ordering), lib/insights/alert_monitor.dart:67-68 (whole low branch gated on lowMgdl); test/pump/hostile_input_corpus_test.dart (add ordering assertion)
- TASK-302 delivered per-field rejection correctly; this is the ordering/firing-semantics half it did not cover
- Safety: AlertThresholds drives real-time hypo alerting
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test --coverage test/ green
- [ ] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [ ] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->
