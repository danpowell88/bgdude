---
id: TASK-218
title: 'CI: cache Gradle dependencies'
status: To Do
assignee: []
created_date: '2026-07-06 21:32'
labels:
  - infra
  - cleanup
milestone: m-8
dependencies: []
priority: medium
ordinal: 113200
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `subosito/flutter-action@v2` with `cache: true` caches the Flutter SDK and pub packages but not `~/.gradle` — every run re-resolves AGP/Kotlin/JitPack dependencies and the wrapper distribution for the APK build and the native test step. The last 10 runs sit at 8m42s-13m21s with the Gradle phase as the consistent tail.

**Reason for change.** ~2-4 minutes saved per run once warm; less JitPack network flakiness exposure.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Gradle caches (caches + wrapper) keyed on gradle files, via gradle/actions/setup-gradle@v4 or actions/cache
- [ ] #2 A warm run is measurably faster than the current baseline (record before/after in the task)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add the cache step before the APK build.
- Compare two consecutive run durations; note them on the task.
- Verify: CI green on the change.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: docs sweep 2026-07-06 (dev-doc audit ticket 5)
- Effort: S–M
- Where: .github/workflows/ci.yml
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
