---
id: TASK-132
title: Fix residual future-leak in HR feature lookup
status: To Do
assignee: []
created_date: '2026-07-06 08:38'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - ml
milestone: m-5
dependencies: []
priority: medium
ordinal: 106400
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `_hrRelAt` (`lib/ml/health_features.dart:98-114`) picks the nearest heart-rate sample within ±15 min bidirectionally, so historical training rows can read a future reading — train/serve skew (live serving only has the past). This is the residual sibling of the fixed look-ahead leak in TASK-23 (Done).

**Reason for change.** Training on information unavailable at serve time inflates offline accuracy and degrades live forecasts.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The lookup is backward-only (or forward window = 0) for training-row construction
- [ ] #2 The feature version is bumped if semantics change
- [ ] #3 A test asserts a future-only HR sample is not used
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Restrict `_hrRelAt` to backward-only lookup (forward window = 0) for training rows.
- Bump the feature version if the semantics change.
- Add a test where the only HR sample is in the future and assert it is not used.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ml/health_features.dart:98-114`)
- Effort: S
- Where: `lib/ml/health_features.dart`
- Related: TASK-23
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
