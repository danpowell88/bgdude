---
id: TASK-245
title: Add Parkes lower-zone under-prediction reference-point tests
status: Blocked
assignee:
  - Claude
created_date: '2026-07-07 13:28'
updated_date: '2026-07-08 03:47'
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
- [x] #1 Reference points pinned in Parkes B-lower, C-lower and D-lower zones
- [ ] #2 Points chosen from or checked against the ega getParkesZones reference
- [x] #3 Test fails if a lower-zone boundary coefficient is perturbed
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-07 (follow-up to TASK-26)
- File: test/parkes_error_grid_test.dart
- The upper-half port is already confirmed faithful; this only closes the untested lower half
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 03:44
---
Started: pinning B-lower/C-lower/D-lower reference points chosen directly from the same Table 1 polygon vertices already cited/verified for the upper half (no internet/R/ega access in this environment, so full independent re-verification against getParkesZones isn't possible here -- documenting that honestly), each justified by explicit boundary-distance math matching the existing upper-zone test style.
---

author: Claude
created: 2026-07-08 03:47
---
Pinned all 3 lower-half zones (B/C/D-lower) in test/parkes_error_grid_test.dart, mirroring the existing upper-half style exactly: an explicit boundary-distance justification comment for each point.

AC#1: done -- classify(100,20)=B, classify(200,50)=C, classify(300,20)=D.

AC#2: partially -- no R/ega access in this environment (no internet), so I could not independently re-run getParkesZones for cross-verification. Instead, chose points directly from the SAME Table 1 polygon vertices already cited/verified for the upper half (the exact numeric literals in _zoneBLower/_zoneCLower/_zoneDLower), which is the strongest verification achievable here -- this pins the port's internal consistency using the same authoritative source, not independently re-derived data. Leaving AC#2 unchecked since it specifically asks for a check against the live reference, which I could not do.

AC#3: done and empirically confirmed via rigor check -- temporarily perturbed _zoneCLower's (260,130) vertex to (260,30), reran: the new C-lower test correctly failed (classified B instead of C). Reverted; git diff clean.

Verified: flutter analyze clean, flutter test --coverage green (1161 tests, 67.54% >= 65% floor), flutter build apk --debug succeeds. No native/user-guide changes (pure test addition).
---

author: Claude
created: 2026-07-08 03:47
---
Status correction: leaving Blocked rather than Done since AC#2 (checked against the ega getParkesZones reference) is explicitly unmet -- no R/ega access in this environment -- matching this project's convention for a genuinely unverifiable AC (TASK-127/31/33/220/226) rather than marking Done with an unmet AC. AC#1/#3 and all applicable DoD items are complete; only AC#2's external reference check remains, and it needs a session with internet/R access, not further code changes.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
