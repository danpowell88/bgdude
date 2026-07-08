---
id: TASK-303
title: >-
  AlertThresholds restore must enforce the urgentLow<low<high ordering --
  per-field range alone can still suppress a hypo alert
status: Done
assignee:
  - Claude
created_date: '2026-07-08 09:26'
updated_date: '2026-07-08 09:46'
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
- [x] #1 AlertThresholds.fromJson enforces urgentLow < low < high after per-field sanitising -- a triple that violates ordering is rejected to the safe defaults (or normalised) rather than accepted as-is, top-level and per-segment
- [x] #2 The accepted threshold band is tightened toward a clinical range (e.g. ~40-400) rather than the 20-600 reading band, so an implausible threshold is rejected
- [x] #3 Defense-in-depth: AlertMonitor evaluates urgentLow independently so a mis-ordered config (low <= urgentLow) can never make urgentLow unreachable
- [x] #4 The hostile-input corpus asserts the ordering invariant (a mis-ordered stored triple decodes to safe, correctly-ordered defaults), not just per-field range
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 verifying the TASK-302 fix (2c0e4f7)
- Files: lib/insights/alert_thresholds.dart:37 _sanitizeMgdl (no ordering), lib/insights/alert_monitor.dart:67-68 (whole low branch gated on lowMgdl); test/pump/hostile_input_corpus_test.dart (add ordering assertion)
- TASK-302 delivered per-field rejection correctly; this is the ordering/firing-semantics half it did not cover
- Safety: AlertThresholds drives real-time hypo alerting
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 09:37
---
Started -- this is a real, serious follow-up to my own TASK-302 work; taking it immediately given the safety impact (a corrupt-but-individually-in-range threshold triple can make AlertMonitor.evaluates urgentLow branch unreachable, silently suppressing a genuine hypo alert). Plan: (1) alert_thresholds.dart -- tighten the per-field band from 20-600 (a plausible-BG-reading band) to 40-400 (AC number 2), and add a whole-triple ordering check (urgentLow < low < high) AFTER per-field sanitising that rejects the ENTIRE triple back to the fallback/default when violated, not just the one out-of-range field, since a mix of one sanitised field and two untouched defaults could still violate ordering on its own (AC number 1), applied at both the top-level AlertThresholds.fromJson and per-segment AlertBand.fromJson. (2) alert_monitor.dart -- defense in depth (AC number 3): restructure evaluate() so urgentLow is checked on its OWN threshold independently of the low branchs gate, not nested inside it, so a mis-ordered config can never make it unreachable regardless of what layer 1 does or does not catch -- verified this preserves identical behaviour for a correctly-ordered config (the urgent check naturally short-circuits the low check first when ordering holds, same cascade-avoidance as before). (3) corpus: assert the ordering invariant on a mis-ordered hostile input (AC number 4).
---

author: Claude
created: 2026-07-08 09:46
---
Done. AC number 2: _sanitizeMgdls per-field band tightened from 20-600 (a plausible-BG-READING band borrowed from pump_snapshot.darts cgmMgdl bound) to 40-400 -- a threshold is a deliberately-configured value, not a raw sensor reading. AC number 1: new _sanitizeThresholdTriple checks urgentLow < low < high on the FULLY-sanitised triple (not per-field, since a mix of one sanitised value and two untouched defaults could itself violate ordering) and rejects the WHOLE triple back to the fallback/default when it does not hold -- wired into both AlertThresholds.fromJson (top-level) and AlertBand.fromJson (per-segment). AC number 3: AlertMonitor.evaluate now checks urgentLow FIRST and independently of the predictedLow branch, instead of nesting it inside a minF.mgdl < lowMgdl gate a corrupted/too-low lowMgdl could already fail -- deliberately kept the exact same currentMgdl > lowMgdl outer gate the old nested check used (not currentMgdl > urgentLowMgdl alone) so a correctly-ordered config fires in EXACTLY the same cases as before; only a mis-ordered configs behaviour changes, from silently firing nothing to firing the urgent alert it should. AC number 4: 6 new dedicated hostile-corpus cases (3 mis-order shapes x top-level + per-segment) assert a mis-ordered-but-individually-in-range triple decodes to the safe, correctly-ordered defaults; the existing generic per-field corpus loop also now asserts the ordering invariant on every successfully-parsed triple, not just isFinite/range. Plus 3 new AlertMonitor tests pinning the exact bug scenario (low=40 corrupted below urgentLow=55, a predicted 50 mg/dL now correctly fires urgentLow instead of nothing) and confirming normal-config behaviour is byte-identical to before the restructure. Rigor-checked both layers independently: removed the ordering check in _sanitizeThresholdTriple (6 corpus tests failed with the predicted symptom), and reverted AlertMonitor to the old nested structure (the new defense-in-depth test failed, reproducing the original suppress-a-hypo bug exactly). Both reverted cleanly. Pipeline green: analyze clean, 1343/1343 tests pass (11 new), coverage 68.64% (floor 65%), apk debug build succeeds. No native Kotlin touched, no user-visible UI change (internal safety hardening).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test --coverage test/ green
- [x] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [x] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [x] #9 backlog item updated with comments
<!-- DOD:END -->
