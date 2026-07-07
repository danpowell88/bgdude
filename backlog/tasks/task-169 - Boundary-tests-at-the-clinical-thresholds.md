---
id: TASK-169
title: Boundary tests at the clinical thresholds
status: Done
assignee:
  - Claude
created_date: '2026-07-06 09:16'
updated_date: '2026-07-07 03:11'
labels:
  - code-health
  - testing
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: medium
ordinal: 103000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Detectors and metrics are only tested well inside/outside their cut points — `test/metrics_test.dart:81-93` uses 100/260 for TIR (never 69.9/70.0/70.1 or 179.9/180.0), `test/care_detectors_test.dart:203-218` never probes the exact high threshold, and `test/bolus_advisor_test.dart:110` low-guards at 60 but never at the 70 boundary.

**Reason for change.** Off-by-comparison errors at 70/54/180/250 are the most common clinical-logic bug class and are currently invisible to the suite.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Parameterized boundary cases at 69.9/70.0/70.1, 53.9/54.0, 179.9/180.0, 249.9/250.0 for TIR bands, low-guard, stubborn-high and urgent-low detectors
- [x] #2 Each boundary test documents the intended inclusivity (which side the exact threshold belongs to)
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 03:08
---
Started: parameterized boundary cases at 69.9/70/70.1, 53.9/54, 179.9/180, 249.9/250 across TIR bands, the advisor low-guard, stubborn-high and urgent-low (AlertMonitor) with inclusivity documented per case.
---

author: Claude
created: 2026-07-07 03:11
---
Done (commit bb16d9d). Note: AlertMonitor's default urgent line is 55 (its own constructor default); the boundary suite pins the 54 clinical line by passing urgentLowMgdl: 54 explicitly, matching the AC.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
New test/clinical_boundaries_test.dart: parameterized probes at 53.9/54.0, 69.9/70.0/70.1, 179.9/180.0/180.1, 249.9/250.0/250.1 across the TIR bands (MetricsCalculator), the advisor low-guard (P0-6), the stubborn-high run threshold, and the urgent-low forecast line (AlertMonitor with the 54 mg/dL urgent line the AC names). Inclusivity documented in the library header and each test name: in-range is [70,180] inclusive, lows are strict <, highs are strict >, the low-guard blocks strictly below 70, urgent requires strictly below the line. 9 tests. Verified: analyze clean, 701 tests green, debug APK builds. Commit bb16d9d.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [x] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
