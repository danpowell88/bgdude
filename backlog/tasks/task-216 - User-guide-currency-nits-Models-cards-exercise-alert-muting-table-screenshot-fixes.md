---
id: TASK-216
title: >-
  User-guide currency nits (Models cards, exercise alert muting,
  table/screenshot fixes)
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:32'
updated_date: '2026-07-08 02:23'
labels:
  - docs
  - cleanup
milestone: m-8
dependencies: []
priority: low
ordinal: 113000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The user guide is otherwise current (verified against the last ~40 landed commits: developer menu, diagnostics log, pump limits, trust chip, clinic prep, backstop, clock-skew all documented; notification table matches the 19-category enum; all 26 screenshots map to live screens). Remaining gaps:

- Insights section omits the Models block (BG forecaster + sensitivity model status cards, `insights_screen.dart:143-163`)
- Exercise section omits that predicted-high alerts are muted during a workout while lows are never suppressed (`alert_monitor.dart:46-48,78`)
- Table row says "Missed bolus?" vs enum label "Missed bolus" (`notification_prefs.dart:36` vs `user-guide.html:367`)
- Backstop wording: guide says <=55 mg/dL; code fires strictly below 55 (`PumpService.kt:222`)
- Orphan screenshot `doc/screenshots/06-meal-add.png` referenced by neither doc — wire into the Meals section or remove

**Reason for change.** Keeps the source-of-truth guide exactly right; each item is a one-line fix.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 All five items fixed
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Apply the five edits; verify anchors still resolve.
- Verify: guide renders; no broken image refs.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: docs sweep 2026-07-06 (user-doc audit tickets 2+3)
- Effort: S
- Where: doc/user-guide.html, doc/screenshots/
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 02:21
---
Started: applying the 5 documented doc/user-guide.html fixes (Models cards, exercise-alert muting, notification-table label, backstop wording, orphan screenshot).
---

author: Claude
created: 2026-07-08 02:23
---
Fixed all 5 items in doc/user-guide.html:
- Added the Models subsection to Insights (BG forecaster + Sensitivity model status cards, matching insights_screen.dart:143-163)
- Exercise mode section now documents that predicted-high alerts are muted during a workout while lows are never suppressed (alert_monitor.dart:46-48)
- Notification table: 'Missed bolus?' -> 'Missed bolus' (matches notification_prefs.dart's enum label exactly)
- Backstop wording: '<= 55 mg/dL' -> 'below 55 mg/dL' (PumpService.kt's maybeFireUrgentLowBackstop fires strictly below 55, at-or-above returns early)
- Wired the orphan doc/screenshots/06-meal-add.png into the Meals section, between the add-meal field list and the meal-detail screenshot

No Dart/Kotlin files touched (doc-only), so analyze/test/build are unaffected -- verified via git diff --stat.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
