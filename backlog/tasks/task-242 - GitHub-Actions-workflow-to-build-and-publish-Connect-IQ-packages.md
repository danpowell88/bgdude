---
id: TASK-242
title: GitHub Actions workflow to build and publish Connect IQ packages
status: Review
assignee:
  - Claude
created_date: '2026-07-07 12:56'
updated_date: '2026-07-10 12:34'
status: Needs Review
assignee:
  - Claude
created_date: '2026-07-07 12:56'
updated_date: '2026-07-10 14:03'
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
- [x] #1 Workflow builds signed release .iq export packages for all three products (widget, watch face, data field) on a GitHub runner
- [x] #2 Developer key is provided via an encrypted GitHub secret, not the committed developer_key.der
- [x] #3 Triggers on a version tag and manual dispatch; the built .iq packages are attached to a GitHub Release as artifacts
- [x] #4 Connect IQ Store submission is either automated or, if no reliable API exists, documented as a manual step in garmin/README.md
- [x] #5 garmin/README.md documents how the publish workflow is triggered and what secrets it needs
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

author: Claude
created: 2026-07-10 12:34
---
implemented-by: Claude (Sonnet 5, session 5ecb6b72-c69b-4afb-b36c-af3d04f85cad) -- code complete and pushed to branch task-242 (commit 00e434d).
created: 2026-07-10 12:36
---
implemented-by: Claude (Sonnet 5, session 5ecb6b72-c69b-4afb-b36c-af3d04f85cad) -- code complete and pushed to branch task-242 (commit 9196b92).

IMPORTANT CAVEAT FOR THE REVIEWER (read before merging): this is a CI-workflow-only ticket -- the deliverable IS the .github/workflows/garmin-release.yml file, and I have NO way to execute or observe a GitHub Actions run from this environment (no network access to Garmin's SDK servers, no developer key, no repo-admin access to trigger workflow_dispatch and watch it). Unlike every other task this session, none of the standard verification pipeline (flutter analyze/test/build) touches this file's actual correctness -- it's Dart/Kotlin-independent. I wrote it carefully against Garmin's documented CI guidance and this repo's existing ci.yml conventions, but the SDK Manager headless-install step (curl + sdkmanager --headless --accept-licenses --install-latest sdk) is UNVERIFIED and is the piece most likely to need a fix if Garmin's download URL/CLI flags have moved. Both the workflow's own header comment and garmin/README.md's new section 6 flag this explicitly and ask for one real workflow_dispatch smoke-test before this is trusted for an actual release.

Given that, please don't treat 'analyze/test/build all green' as evidence this workflow works -- it only proves I didn't break the Flutter app while adding it (I didn't touch any Dart/Kotlin file).

What's implemented: builds all 3 products' release .iq via monkeyc -e (no -d, so each .iq covers every device in that product's manifest); signing key read from a new GARMIN_DEVELOPER_KEY_BASE64 repo secret (never committed -- developer_key.der/.pem were already gitignored, so there was no committed key to migrate away from, only a convention to formalize) and deleted at job end; triggers on garmin-v* tag or workflow_dispatch only (dormant otherwise, cannot affect ci.yml); .iq files attached to a GitHub Release via softprops/action-gh-release. Connect IQ Store submission has no public API, so per decision-5 it's documented as a manual step (README section 6, upload via the Developer Portal by UUID).

friction:tooling -- could not validate the new workflow's YAML syntax with a linter in this sandbox (no js-yaml/PyYAML/actionlint available, and npx was blocked by the auto-mode classifier as an undeclared external package fetch) -- hand-reviewed indentation/structure against the existing ci.yml instead. A GitHub-side YAML syntax check on the actual PR would be a good first-line catch if I made a formatting mistake.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [x] #8 backlog item updated with comments
<!-- DOD:END -->
