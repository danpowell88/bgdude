---
id: TASK-126
title: Move Control-IQ state mapping onto PumpSnapshot
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:37'
updated_date: '2026-07-07 14:45'
labels:
  - code-health
  - pump
  - cleanup
milestone: m-8
dependencies: []
priority: low
ordinal: 110000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `_controlIqStateFrom` (`lib/state/providers.dart:1170-1180`) is a private free function doing domain mapping (snapshot to `ControlIqState`) stranded in the wiring layer; `toCgmSample` already lives on the snapshot (`lib/pump/pump_snapshot.dart:185-190`).

**Reason for change.** Domain mapping belongs beside the snapshot type where it is discoverable and unit-testable, matching the existing `toCgmSample` pattern.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The mapping lives on `PumpSnapshot` or a `PumpSnapshotMapper` in `lib/pump/`
- [x] #2 A unit test covers the mode mapping
- [x] #3 `providers.dart` references the method
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 14:45
---
Moved the Control-IQ mapping onto PumpSnapshot: added an instance getter controlIqState plus a static PumpSnapshot.mapControlIqState({enabled, active, mode}) so the providers.dart call site (which watches a .select()-destructured record, not a full PumpSnapshot, to gate rebuilds on only these 3 fields) can still call the same mapping logic instead of duplicating it. Deleted the old private _controlIqStateFrom free function. Added 6 unit tests in test/pump_data_test.dart covering off/sleep/exercise/standard/unknown-mode/fallback-to-controlIqActive/closedLoopEnabled-false-overrides-stale-active-true. flutter analyze clean, flutter test test/ green (932 tests), flutter build apk --debug succeeded, build_runner succeeded (no generated-code impact). DoD #5 (native Kotlin gradle test) and #6/#7 (user-guide/integration test) not applicable — no Kotlin, UI, or user-visible change.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
