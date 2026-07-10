---
id: TASK-242
title: GitHub Actions workflow to build and publish Connect IQ packages
status: In Progress
assignee:
  - Claude
created_date: '2026-07-07 12:56'
updated_date: '2026-07-10 12:22'
labels:
  - garmin
  - ci
milestone: m-4
dependencies: []
priority: medium
ordinal: 500500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** CI (`.github/workflows/ci.yml`) is Flutter/Android-only — it never builds the Garmin Connect IQ products. The watch apps are built ad hoc on a developer's machine (`garmin/tools/build_all.ps1` with a local `developer_key.der`), so there's no automated, reproducible way to produce or ship a store-ready package.

**Outcome.** A GitHub Actions workflow that builds signed, release Connect IQ export packages (`.iq`) for all three products — widget (`monkey.jungle`), watch face (`watchface.jungle`), data field (`datafield.jungle`) — across the manifest device set, and publishes them (attach to a GitHub Release; document the Connect IQ Store upload step).

**Why it matters.** We want the Garmin apps to be reliably shippable to real users across many devices. A one-command/tag-driven build removes the 'works on my machine' signing/packaging risk and gives every release a reproducible, downloadable artifact.

**Approach / notes.**
- The Monkey C compiler builds on Linux runners (only the *simulator* needs a display), so install the CIQ SDK in the job (community SDK-setup action or scripted SDK-manager download) and run `monkeyc -e` to produce release `.iq` exports.
- Sign with the developer key supplied as an encrypted GitHub **secret**, not the key committed at `garmin/developer_key.der` — CI should not depend on a committed private key (flag this for the maintainer).
- Trigger on a version tag (and `workflow_dispatch`); attach each `.iq` to the GitHub Release.
- Garmin has no fully public automated store-submission API — if no reliable path exists, **document the manual Connect IQ Store upload** as the final step rather than faking automation (mirror decision-5's honesty about manual steps).
- Build the manifest device/product matrix; coordinate with TASK-32 (which is expanding the manifests) so packages cover current-gen devices.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Workflow builds signed release .iq export packages for all three products (widget, watch face, data field) on a GitHub runner
- [ ] #2 Developer key is provided via an encrypted GitHub secret, not the committed developer_key.der
- [ ] #3 Triggers on a version tag and manual dispatch; the built .iq packages are attached to a GitHub Release as artifacts
- [ ] #4 Connect IQ Store submission is either automated or, if no reliable API exists, documented as a manual step in garmin/README.md
- [ ] #5 garmin/README.md documents how the publish workflow is triggered and what secrets it needs
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: user request 2026-07-07 (Connect IQ publish workflows in GitHub)
- Effort: M
- Existing seam: `garmin/tools/build_all.ps1` (local build), `garmin/manifest*.xml` (device matrix), `.github/workflows/ci.yml` (existing CI conventions)
- Related: TASK-32 (current-gen devices in manifests), decision-5 (be explicit about manual-only steps)
- Note: Monkey C compiles on Linux; only the CIQ simulator needs a display, so packaging (unlike the visual-test harness TASK-240) can run on hosted Linux runners
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-10 12:22
---
branch: task-242
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
