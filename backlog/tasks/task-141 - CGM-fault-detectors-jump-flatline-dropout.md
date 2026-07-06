---
id: TASK-141
title: 'CGM fault detectors: jump, flatline, dropout'
status: To Do
assignee: []
created_date: '2026-07-06 08:40'
labels:
  - feature
  - ml
  - data-integrity
milestone: m-5
dependencies: []
priority: medium
ordinal: 141000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Training excludes warm-up and compression lows but nothing detects impossible jumps between consecutive readings, stuck/flatline values, or dropout-edge readings (`lib/ml/event_detectors.dart` has only `CompressionLowDetector`; exclusion hook at `lib/ml/forecaster_training.dart:85`) — faults enter training labels and live features unfiltered.

**Value.** Cleaner training labels and a live data-quality flag the rest of the app can trust.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A jump detector (delta beyond physiologic per-minute), a flatline detector (identical values across a window), and dropout-edge marking exist
- [ ] #2 Exclusion windows are consumed by the retraining pipeline
- [ ] #3 A live data-quality flag is exposed
- [ ] #4 Unit tests sit beside the compression-low tests
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
