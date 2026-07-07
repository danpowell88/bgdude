---
id: TASK-245
title: Add Parkes lower-zone under-prediction reference-point tests
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 13:28'
labels: []
milestone: m-5
dependencies: []
priority: medium
ordinal: 185000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Parkes (Consensus) error grid port added in TASK-26 was verified faithful against the ega R package for the upper half, but every pinned reference point has predicted >= reference (over-prediction). Zones B-lower, C-lower, D-lower (dangerous under-reads — predicting a low when the actual is high, i.e. missed hyperglycemia) have zero pinned points. That lower region includes the subtlest extrapolated boundary and is exactly where a future edit would silently break with no test catching it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Reference points pinned in Parkes B-lower, C-lower and D-lower zones
- [ ] #2 Points chosen from or checked against the ega getParkesZones reference
- [ ] #3 Test fails if a lower-zone boundary coefficient is perturbed
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-07 (follow-up to TASK-26)
- File: test/parkes_error_grid_test.dart
- The upper-half port is already confirmed faithful; this only closes the untested lower half
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
