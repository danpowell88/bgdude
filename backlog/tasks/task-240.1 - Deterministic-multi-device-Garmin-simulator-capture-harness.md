---
id: TASK-240.1
title: Deterministic multi-device Garmin simulator capture harness
status: To Do
assignee: []
created_date: '2026-07-07 12:53'
updated_date: '2026-07-07 16:37'
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 16:37
---
Feasibility spike (2026-07-08): confirmed the core pipeline actually works in this environment -- ran the existing garmin/tools/screenshots.ps1 end-to-end (builds widget/watchface/datafield via monkeyc, launches simulator.exe, captures via System.Drawing.CopyFromScreen, restores source) and got a correctly-rendered watchface PNG back (fenix847mm, seeded BG data visible). So this is NOT blocked by an environment limitation the way the Android emulator integration tests are (see memory integration-test-emulator-limitation) -- CIQ SDK 9.2.0 is installed and the simulator renders and captures cleanly here.

Found the real open technical question for AC#2 (byte-identical determinism): BgData.mc's save() always stamps receivedAt = Time.now().value() at the moment the seed is injected -- the displayed 'age' is Time.now() - receivedAt computed fresh at RENDER time, so it drifts with however long the build+launch+capture pipeline takes (observed '99m (stale)' in the smoke test instead of the intended ~2min). monkeydo.bat / monkeyc.bat / simulator.exe have no CLI flag for setting/freezing simulator time (checked monkeydo's usage text; simulator.exe is a GUI-only app with no --help). Achieving true byte-identical runs likely needs one of: (a) a Monkey C source change to accept an explicit receivedAt in the seed payload AND a way to freeze Time.now() itself (no obvious public API for that), or (b) UI-automating the simulator's Settings menu if it exposes a fixed-time option (unconfirmed), or (c) relaxing AC#2 to a pixel-diff tolerance instead of true byte-identity (which is what subtask 240.2 already builds anyway) and rendering the SAME instant across devices in one run rather than matching bit-for-bit across separate runs.

This is a legitimate, sizeable (multi-hour) build-out (~45-device matrix, per-device geometry handling, device-driven config) that deserves focused, uninterrupted implementation time rather than being squeezed between smaller fixes. Deferring to a dedicated pass; not detail-needed (nothing here is ambiguous -- it just needs the time budget).
---
<!-- COMMENTS:END -->

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
