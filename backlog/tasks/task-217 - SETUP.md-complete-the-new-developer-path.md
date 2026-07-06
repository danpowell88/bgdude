---
id: TASK-217
title: 'SETUP.md: complete the new-developer path'
status: To Do
assignee: []
created_date: '2026-07-06 21:32'
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
- [ ] #1 Verify-like-CI section pointing at the CLAUDE.md pipeline
- [ ] #2 Emulator + integration-test how-to
- [ ] #3 pumpx2/javap and backlog CLI onboarding covered
- [ ] #4 Troubleshooting section added; database.g.dart exception resolved or documented
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
