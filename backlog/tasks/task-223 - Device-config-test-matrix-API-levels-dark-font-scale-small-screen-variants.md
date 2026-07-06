---
id: TASK-223
title: 'Device-config test matrix: API levels + dark/font-scale/small-screen variants'
status: To Do
assignee: []
created_date: '2026-07-06 22:14'
updated_date: '2026-07-06 22:15'
labels:
  - testing
  - infra
milestone: m-8
dependencies:
  - TASK-219
priority: medium
ordinal: 113700
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The axes that exercise real code in THIS app are: API level (permission model changes at 31/33/34, Health Connect preinstalled 34+), dark mode (`glucose_colors.dart` has a fixed palette with no brightness handling — contrast risk), font scale (overflow risk across StatTile/list layouts), and small screens. Locale/24h axes have near-zero payoff (no intl usage — dropped).

- API boundaries that matter: the minSdk floor (26 if the lowering ticket lands, else 29), 31 (BLE runtime-permission split), 33 (POST_NOTIFICATIONS prompt), 35 (edge-to-edge + 16 KB), 36/37 (target).
- Pragmatic matrix: baseline API-34 light 1.0x; API-34 dark + textScale 1.6 and small-screen as CHEAP in-process MediaQuery variants on the same runner (+6-8 min, no extra boot); a floor-API config; API-36 optional nightly — total ~35-40 CI min nightly.

**Reason for change.** Rendering and permission regressions on real device configurations are currently invisible; a small, targeted matrix catches them for a bounded nightly cost.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 An in-process variant wrapper exists in the harness (textScaler 1.6, dark, compact Size)
- [ ] #2 The nightly workflow runs baseline + floor API images
- [ ] #3 The supported/tested API matrix is documented in SETUP.md with the boundary rationale
- [ ] #4 At least one overflow/contrast assertion exists per variant
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add an in-process variant wrapper to `integration_test/harness.dart` (MediaQuery textScaler 1.6, dark theme, compact Size).
- Extend the nightly emulator workflow with a floor-API configuration alongside the API-34 baseline; make API-36 optional.
- Add at least one overflow/contrast assertion per variant.
- Document the supported/tested API matrix and boundary rationale in SETUP.md.
- Verify: `flutter analyze` clean, `flutter test` green.
- Verify: run the variant tests on an emulator and confirm the nightly workflow matrix passes.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: device-testing sweep 2026-07-07 (version audit)
- Effort: S-M
- Where: `integration_test/harness.dart`, `.github/workflows/`, `SETUP.md`, `glucose_colors.dart`
- Related: TASK-150, TASK-98, TASK-195, TASK-227 (minSdk lowering)
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
