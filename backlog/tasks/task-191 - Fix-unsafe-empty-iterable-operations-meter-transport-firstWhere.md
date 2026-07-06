---
id: TASK-191
title: Fix unsafe empty-iterable operations (meter transport firstWhere)
status: To Do
assignee: []
created_date: '2026-07-06 12:56'
labels:
  - code-health
  - cleanup
milestone: m-8
dependencies: []
priority: medium
ordinal: 191000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/integrations/glucose_meter_transport_fbp.dart:90` calls `services.firstWhere(...)` with no `orElse` — pairing against a BLE device that lacks the Glucose service throws an uncaught `StateError` mid-connect. Audit of the other `.reduce(`/`.first` sites shows most are guarded (`alert_monitor.dart:47` checks isEmpty; `predictor.dart:33-35` ternary) but the sweep should confirm each remaining site.

**Reason for change.** A user pairing the wrong device should get a clean "not a glucose meter" failure, not a crash.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 firstWhere has orElse and the connect flow surfaces a clean incompatible-device error
- [ ] #2 Remaining reduce/first/single sites in lib/ audited; each unguarded one fixed or proven unreachable-empty with a comment
- [ ] #3 Test: service list without Glucose service → typed failure, no throw
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Fix the transport site with orElse + typed error.
- Grep-audit the ~10 remaining sites; fix or annotate.
- Add the wrong-device unit test.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep 2026-07-06 (verified: one unguarded firstWhere)
- Effort: S
- Where: lib/integrations/glucose_meter_transport_fbp.dart:90 + audited sites
- Related: TASK-30 (meter field test)
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
