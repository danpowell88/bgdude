---
id: TASK-217
title: 'SETUP.md: complete the new-developer path'
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:32'
updated_date: '2026-07-07 21:25'
labels:
  - docs
  - infra
milestone: m-8
dependencies: []
priority: medium
ordinal: 113100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Walking SETUP.md cold leaves gaps a new developer hits immediately:

- No pointer to the CI-equivalent verification pipeline (the authoritative 6-step order lives in `CLAUDE.md`) — a dev passes locally and breaks CI
- No emulator creation/launch guidance for `integration_test/` (`avdmanager` / `flutter emulators --launch`, `-d emulator-5554`)
- pumpx2 acquisition under-documented: JitPack default needs nothing extra; how to locate the cached jar for the `javap` API-verification step is unstated
- No backlog CLI install/onboarding despite the workflow requiring it
- No troubleshooting section (build_runner conflicts, JitPack network, Pigeon leftovers)
- SETUP claims generated `*.g.dart` files are not committed, but `lib/data/database.g.dart` IS committed (the one exception) — note it or gitignore it

**Reason for change.** SETUP is the on-ramp; every gap above is a real first-day stall.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Verify-like-CI section pointing at the CLAUDE.md pipeline
- [x] #2 Emulator + integration-test how-to
- [x] #3 pumpx2/javap and backlog CLI onboarding covered
- [x] #4 Troubleshooting section added; database.g.dart exception resolved or documented
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Draft each section; validate commands on this machine.
- Decide the database.g.dart question (gitignore vs document) and apply.
- Verify: follow the doc end-to-end once.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: docs sweep 2026-07-06 (dev-doc audit ticket 2)
- Effort: M
- Where: SETUP.md
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 21:22
---
Started: fill the 4 new-developer gaps in SETUP.md (CI-equivalent pipeline pointer, emulator/integration-test how-to, pumpx2/javap + backlog CLI onboarding, troubleshooting section) and document (not gitignore) the database.g.dart committed-generated-file exception -- deleting a tracked generated file is a bigger, less reversible change than documenting it, and the AC allows either.
---

author: Claude
created: 2026-07-07 21:25
---
Fixed all 4 ACs in SETUP.md:

- Added step 6 'Verify like CI before committing anything', pointing at the CLAUDE.md pipeline (pub get -> build_runner -> analyze -> test -> apk debug -> gradlew unit tests when native changed).
- Added step 7: emulator create/list/launch commands (avdmanager, flutter emulators) and how to run a single functional integration_test/ file against it, plus the screenshots/walkthrough-need-flutter-drive caveat.
- Added step 8: pumpx2/javap onboarding -- verified against this machine's actual Gradle caches that pumpx2-messages/pumpx2-shared are plain jars under caches/modules-2 while pumpx2-android is an AAR whose classes.jar only appears under caches/*/transforms/*/transformed/ (confirmed TandemBluetoothHandler is really in there via unzip -l before writing the doc). Also added backlog CLI (npm install -g backlog.md) to the prerequisites list.
- Added step 9 troubleshooting (build_runner conflicts, JitPack lazy-build flakiness, stale Pigeon output, flutter create clobbering the two customised Android files).
- Resolved the database.g.dart discrepancy by documenting it (chose documenting over gitignoring/untracking: confirmed via git ls-files it's the only committed *.g.dart in the repo, and removing a tracked generated file is a bigger, less reversible change than noting the exception -- the AC allows either).

Verified every command/path against this machine before writing it (javap against a real class, the two Gradle cache find patterns, backlog --version). Docs-only change; flutter analyze still clean.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
