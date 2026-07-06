---
id: TASK-126
title: Move Control-IQ state mapping onto PumpSnapshot
status: To Do
assignee: []
created_date: '2026-07-06 08:37'
labels:
  - code-health
  - pump
  - cleanup
milestone: m-8
dependencies: []
priority: low
ordinal: 126000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `_controlIqStateFrom` (`lib/state/providers.dart:1170-1180`) is a private free function doing domain mapping (snapshot to `ControlIqState`) stranded in the wiring layer; `toCgmSample` already lives on the snapshot (`lib/pump/pump_snapshot.dart:185-190`).

**Reason for change.** Domain mapping belongs beside the snapshot type where it is discoverable and unit-testable, matching the existing `toCgmSample` pattern.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The mapping lives on `PumpSnapshot` or a `PumpSnapshotMapper` in `lib/pump/`
- [ ] #2 A unit test covers the mode mapping
- [ ] #3 `providers.dart` references the method
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Move `_controlIqStateFrom` onto `PumpSnapshot` (or a `PumpSnapshotMapper`) in `lib/pump/`.
- Update `providers.dart` to call the method.
- Add a unit test for the mode mapping.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/state/providers.dart:1170-1180`)
- Effort: S
- Where: `lib/state/providers.dart`, `lib/pump/pump_snapshot.dart`
- Related: TASK-43
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
