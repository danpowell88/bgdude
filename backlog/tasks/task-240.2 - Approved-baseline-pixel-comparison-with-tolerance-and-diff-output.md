---
id: TASK-240.2
title: Approved-baseline pixel comparison with tolerance and diff output
status: To Do
assignee: []
created_date: '2026-07-07 12:53'
labels:
  - garmin
  - testing
milestone: m-4
dependencies:
  - TASK-240.1
parent_task_id: TASK-240
priority: medium
ordinal: 111200
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Outcome.** A comparison step that diffs each freshly captured PNG (from the capture harness) against a committed 'approved' baseline image for that same product×device, with a configurable tolerance, and reports pass/fail per image plus an overall exit code.

**Why.** Capturing images only helps if a regression is detected automatically. We need pixel comparison with leeway so anti-aliasing / harmless sub-pixel noise doesn't cause false failures, while real moves/resizes/breaks do fail.

**Comparison behaviour.**
- Per-pixel channel tolerance (a pixel counts as different only if it exceeds a delta) plus an overall threshold (max percentage of differing pixels) — both configurable.
- On mismatch, write a diff image (e.g. changed pixels highlighted) next to the capture so a human can see what moved.
- Non-zero exit on any failure so it can gate a test run; clear per-image PASS/FAIL summary.

**Baseline management.**
- Approved images live in a committed directory, one per product×device (e.g. `garmin/screenshots/approved/<device>-<product>.png`).
- An 'approve/update' mode promotes the current captures to approved (for intentional changes / new devices) so updating baselines is a single deliberate command, not hand-copying.
- Missing baseline for a device = explicit 'new, needs approval' result, not a silent pass.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Compares each capture against its committed approved baseline with configurable per-pixel and overall-percentage tolerance
- [ ] #2 Produces a diff image highlighting changed regions on any mismatch
- [ ] #3 Returns non-zero exit and a per-image PASS/FAIL summary when any image regresses
- [ ] #4 Approved baselines are committed per product×device; an approve/update command promotes current captures to approved
- [ ] #5 A missing baseline is reported as 'new/unapproved', not a pass
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: user request 2026-07-07 (pixel-like comparison with leeway; aware when something breaks or moves)
- Effort: M
- Depends on TASK-240.1 (needs deterministic captures)
- Baselines committed under `garmin/screenshots/approved/` (path illustrative)
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
