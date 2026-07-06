---
id: TASK-131
title: Local-time contract for time-of-day features (UTC/DST skew)
status: To Do
assignee: []
created_date: '2026-07-06 08:38'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - ml
  - data-integrity
milestone: m-5
dependencies: []
priority: medium
ordinal: 106300
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `hour_sin/hour_cos` (`lib/ml/forecast_features.dart:57,63-64`), the TOD bucket index (`lib/ml/time_of_day_sensitivity.dart:154,303-314`) and `settings.segmentAt` (`lib/ml/autotune.dart:122`) read `DateTime.hour/.minute` with no local-vs-UTC contract; Nightscout ingest produces UTC (`lib/integrations/nightscout.dart:122`). UTC samples shift every TOD feature and basal-segment lookup; DST shifts fixed buckets.

**Reason for change.** A UTC timestamp silently lands every time-of-day feature in the wrong bucket, corrupting training data and basal-segment lookups without any error.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A documented and asserted contract (local wall-clock) exists at the ml boundary, converted once at ingest
- [ ] #2 A debug assertion catches feature times that are UTC
- [ ] #3 Tests cover a DST boundary and a UTC-vs-local sample
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Document the local wall-clock contract at the ml boundary.
- Convert Nightscout-ingested timestamps to local once at ingest.
- Add a debug assertion that feature timestamps are not UTC.
- Add tests around a DST boundary and a UTC-vs-local sample.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ml/forecast_features.dart:57-64`)
- Effort: M
- Where: `lib/ml/forecast_features.dart`, `lib/ml/time_of_day_sensitivity.dart`, `lib/ml/autotune.dart`, `lib/integrations/nightscout.dart`
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
