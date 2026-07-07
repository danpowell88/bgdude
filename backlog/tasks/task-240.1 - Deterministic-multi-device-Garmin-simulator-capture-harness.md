---
id: TASK-240.1
title: Deterministic multi-device Garmin simulator capture harness
status: To Do
assignee: []
created_date: '2026-07-07 12:53'
labels:
  - garmin
  - testing
milestone: m-4
dependencies: []
parent_task_id: TASK-240
priority: medium
ordinal: 111100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Outcome.** A capture tool that builds each Connect IQ product (widget, watch face, data field) and runs it in the CIQ simulator for every device in a configured matrix, capturing one PNG per (product × device) into a working output directory. Rendering must be byte-identical run-to-run so downstream comparison is stable.

**Why.** The current `garmin/tools/screenshots.ps1` only handles one device with hard-coded crop coordinates and re-seeds data ad hoc. A visual-regression suite needs deterministic, per-device captures for the whole matrix.

**Determinism requirements.**
- Seed fixed sample BG data (as the existing script does) so every device shows the same reading.
- Freeze the clock / any time-of-day or 'age since reading' rendering to a fixed value so captures don't drift between runs (relates to TASK-39 'Inject the clock').
- Handle per-device screen geometry (round/rectangular, differing resolutions) instead of one hard-coded crop — capture the device's actual screen region so each device's baseline is correctly framed.
- Restore committed source/manifests afterwards (byte-accurate), as the current script already does.

**Device matrix.** Drive the device list from a single config (or the manifests' `<iq:product>` list) so 'add a device' is one edit. Support running the full list or a single `-Device`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Builds and captures all three products (widget, watch face, data field) for each device in a configured matrix, one PNG per product×device
- [ ] #2 Capture output is deterministic run-to-run: fixed seeded data and a frozen clock, verified by two consecutive runs producing identical PNGs for the same device
- [ ] #3 Per-device screen geometry handled (no single hard-coded crop); round and rectangular devices both framed correctly
- [ ] #4 Device matrix is defined in one place and supports both full-matrix and single-device runs
- [ ] #5 Committed Garmin source and manifests are restored byte-accurately after a run (even on failure)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: user request 2026-07-07
- Effort: M
- Build on / generalize `garmin/tools/screenshots.ps1`
- Depends on nothing; feeds the comparison subtask
- Related: TASK-39 (inject the clock), TASK-220 (deterministic demo seam)
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
