---
id: TASK-169
title: Boundary tests at the clinical thresholds
status: To Do
assignee: []
created_date: '2026-07-06 09:16'
labels:
  - code-health
  - testing
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: medium
ordinal: 169000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Detectors and metrics are only tested well inside/outside their cut points — `test/metrics_test.dart:81-93` uses 100/260 for TIR (never 69.9/70.0/70.1 or 179.9/180.0), `test/care_detectors_test.dart:203-218` never probes the exact high threshold, and `test/bolus_advisor_test.dart:110` low-guards at 60 but never at the 70 boundary.

**Reason for change.** Off-by-comparison errors at 70/54/180/250 are the most common clinical-logic bug class and are currently invisible to the suite.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Parameterized boundary cases at 69.9/70.0/70.1, 53.9/54.0, 179.9/180.0, 249.9/250.0 for TIR bands, low-guard, stubborn-high and urgent-low detectors
- [ ] #2 Each boundary test documents the intended inclusivity (which side the exact threshold belongs to)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Build a parameterized boundary-case helper over the threshold constants.
- Add cases at 69.9/70.0/70.1, 53.9/54.0, 179.9/180.0, 249.9/250.0 for TIR bands, the advisor low-guard, and the stubborn-high and urgent-low detectors.
- Document intended inclusivity per threshold in the test names/comments.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (test-quality finding 7)
- Effort: S
- Where: `test/metrics_test.dart`, `test/care_detectors_test.dart`, `test/bolus_advisor_test.dart`
- Related: TASK-103 (constants), companion to the TASK-102 boundary-test gap
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
