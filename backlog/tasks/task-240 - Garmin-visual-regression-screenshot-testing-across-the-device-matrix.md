---
id: TASK-240
title: Garmin visual-regression screenshot testing across the device matrix
status: To Do
assignee: []
created_date: '2026-07-07 12:52'
labels:
  - garmin
  - testing
milestone: m-4
dependencies: []
priority: medium
ordinal: 111000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The Garmin Connect IQ apps (widget, watch face, data field) render in Garmin's own simulator, not Flutter, so the app's golden/screenshot tests (TASK-98) don't cover them. Today only `garmin/tools/screenshots.ps1` captures a single device (`fenix847mm`) for the user guide, with hard-coded crop coordinates and no comparison.

**Goal.** Stand up a visual-regression harness for the Garmin products: build + run each product in the Connect IQ simulator for as many supported devices as we can, capture the simulator view, and compare each capture against a committed approved image with a pixel diff (with tolerance/leeway). A regression — anything moving, resizing, or breaking on any device/product — should fail the test run and produce a visible diff.

**Why it matters.** We want to support many Garmin devices (the manifests already list ~45 products across fenix/epix/venu/forerunner/vivoactive families with different screen shapes and sizes). Each new device or layout change can silently break rendering on shapes we don't hand-check. Automated per-device visual comparison is the only scalable way to know when something breaks or moves.

**Scope note.** This is Garmin-simulator-specific and separate from TASK-98 (Flutter goldens) and from the doc-screenshot script's single-device purpose. Determinism (fixed clock + seeded sample data so every run renders identically) is a hard requirement — see subtasks.

**Constraint.** The Connect IQ simulator + `System.Drawing` capture are Windows-only and need the CIQ SDK installed, so full CI on Linux runners is not straightforward — the delivery target is a documented, repeatable local/self-hosted run, with CI wiring evaluated in the integration subtask.
<!-- SECTION:DESCRIPTION:END -->

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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: user request 2026-07-07 (support many Garmin devices; capture simulator view per device; pixel-compare vs approved image with leeway; deterministic render)
- Effort: L (umbrella)
- Existing seam: `garmin/tools/screenshots.ps1` (single-device capture), `garmin/manifest*.xml` (device matrix), `garmin/tools/run_tests.ps1` (CIQ unit-test runner)
- Related: TASK-98 (Flutter goldens, different harness), TASK-32 (adds current-gen devices to the manifests)
<!-- SECTION:NOTES:END -->
