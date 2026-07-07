---
id: TASK-240.3
title: >-
  Wire Garmin visual-regression into the test run + document, and grow the
  device matrix
status: To Do
assignee: []
created_date: '2026-07-07 12:54'
labels:
  - garmin
  - testing
milestone: m-4
dependencies:
  - TASK-240.2
parent_task_id: TASK-240
priority: medium
ordinal: 111300
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Outcome.** Make the capture+compare pipeline a first-class, repeatable check: a single documented command that runs the whole matrix and fails on any regression, referenced from the Garmin README and the project docs, plus an evaluation of CI wiring.

**Why.** The harness (240.1) and comparison (240.2) only pay off if they're actually run when the Garmin code changes and the workflow is documented for the next person.

**Work.**
- One entry-point (e.g. `garmin/tools/visual_test.ps1`) that runs capture then compare across the full matrix and exits non-zero on any regression or unapproved image.
- Document the command, prerequisites (CIQ SDK + Windows, developer key), how to review diffs, and how to approve intentional changes — in `garmin/README.md` and referenced from the repo test docs.
- Expand the covered device matrix toward the full supported set (fenix/epix/venu/forerunner/vivoactive families in the manifests), coordinating with TASK-32 which is adding current-gen devices. Where a product doesn't support a device, skip it cleanly.
- Evaluate CI: the CIQ simulator is Windows-only and needs the SDK, so a standard Linux GH Actions runner can't run it. Decide and record (self-hosted/Windows runner, nightly, or documented-manual) — mirror decision-5's 'integration tests are manual-only' stance if that's the outcome, and note it rather than leaving it implied.

**Guide.** Per CLAUDE.md, if this changes how screenshots/tests are run, update `doc/user-guide.html`/developer docs accordingly.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A single documented command runs capture+compare across the full device matrix and exits non-zero on any regression or unapproved image
- [ ] #2 garmin/README.md documents prerequisites, how to run, how to review diffs, and how to approve intentional baseline changes
- [ ] #3 Device matrix covers the supported product×device set in the manifests (skipping unsupported product/device combos cleanly), coordinated with TASK-32
- [ ] #4 CI approach is decided and recorded (self-hosted/Windows/nightly vs documented-manual), consistent with decision-5
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: user request 2026-07-07 (as part of test runs; support as many devices as we can)
- Effort: S–M
- Depends on TASK-240.2
- Related: TASK-32 (current-gen devices in manifests), decision-5 (integration tests manual-only), TASK-219 (nightly emulator CI job — precedent for nightly/self-hosted)
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
