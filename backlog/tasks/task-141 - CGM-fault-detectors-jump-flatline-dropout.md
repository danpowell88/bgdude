---
id: TASK-141
title: 'CGM fault detectors: jump, flatline, dropout'
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:40'
updated_date: '2026-07-10 09:26'
labels:
  - feature
  - ml
  - data-integrity
milestone: m-5
dependencies: []
priority: medium
ordinal: 701800
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Training excludes warm-up and compression lows but nothing detects impossible jumps between consecutive readings, stuck/flatline values, or dropout-edge readings (`lib/ml/event_detectors.dart` has only `CompressionLowDetector`; exclusion hook at `lib/ml/forecaster_training.dart:85`) — faults enter training labels and live features unfiltered.

**Value.** Cleaner training labels and a live data-quality flag the rest of the app can trust.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A jump detector (delta beyond physiologic per-minute), a flatline detector (identical values across a window), and dropout-edge marking exist
- [x] #2 Exclusion windows are consumed by the retraining pipeline
- [x] #3 A live data-quality flag is exposed
- [x] #4 Unit tests sit beside the compression-low tests
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add jump, flatline and dropout-edge detectors beside `CompressionLowDetector` in `lib/ml/event_detectors.dart`.
- Feed their exclusion windows into the retraining pipeline hook.
- Expose a live data-quality flag.
- Add unit tests beside the compression-low tests.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ml/event_detectors.dart`)
- Effort: M
- Where: `lib/ml/event_detectors.dart`, `lib/ml/forecaster_training.dart`
- Related: TASK-53 (sensor-age weighting), TASK-94
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 11:18
---
Started: reading lib/ml/event_detectors.dart's existing CompressionLowDetector and lib/ml/forecaster_training.dart's exclusion hook to match the established pattern before adding jump/flatline/dropout.
---

author: Claude
created: 2026-07-10 09:26
---
Done: CgmFaultDetector (lib/ml/event_detectors.dart, beside CompressionLowDetector) covers jump (delta beyond a 4 mg/dL/min physiologic ceiling between consecutive readings), flatline (readings within tolerance of a run's start value for >=20 min), and dropoutEdge (readings bracketing a gap >=20 min, +-10 min margin). Kept separate from AnnotationKind on purpose -- these are algorithmic, never user-visible/persisted/confirmable, unlike compressionLow which IS surfaced for confirmation. RetrainingPipeline.buildTrainingSet gained an optional cgmFaults param excluded the same way as annotation windows; ForecasterTrainer.train() computes CgmFaultDetector().detect(samples) once and passes it through. Live flag: cgmDataQualityProvider (providers.dart) checks whether the day's MOST RECENT reading falls inside a detected fault window; surfaced as a new 'CGM data quality' card at the top of the Advanced screen. REAL BUG FOUND AND FIXED during rigor-checking: the first flatline implementation flagged the ENTIRE span of a qualifying run with no upper bound -- on any long genuinely-flat trace (a multi-hour real stuck sensor, or the flat CGM fixtures used throughout the existing ml/ test suite) this excluded the whole run from training, not just the fault, and broke ~5 pre-existing tests (dose-truncation, TASK-140's census tests) whose trainCount dropped below the 150-sample floor. Fixed by bounding each flagged flatline event to its first ~flatlineWindow (20 min) regardless of how much further the run continues -- a stuck sensor is caught at its onset, not excluded for its entire duration. Added a dedicated test pinning this (4h flat run -> flagged span < 1h) and rigor-checked it (reverted to unbounded, confirmed the new test fails with 3:55:00 actual vs <1:00:00 expected, restored). Tests: event_detectors_test.dart (jump/flatline/dropout-edge positive+negative cases, degenerate-input safety, the bounded-window regression pin), insights_and_ml_test.dart (RetrainingPipeline cgmFaults exclusion), forecaster_training_test.dart (end-to-end: an inserted spike shrinks trainSamples, proving the detector->pipeline wiring engages for real, not just in isolation), cgm_data_quality_provider_test.dart (live flag null/flagged/degenerate). All three fixes individually rigor-checked (temp-bug + revert). doc/user-guide.html: new CGM data quality bullet on the Advanced section. Full pipeline green: analyze clean, 1379 tests passing, coverage 68.82% (floor 65%), apk build succeeded (fresh worktree gradle build, 215s). No native Kotlin changed.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
