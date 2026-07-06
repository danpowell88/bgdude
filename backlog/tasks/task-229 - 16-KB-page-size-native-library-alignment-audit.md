---
id: TASK-229
title: 16 KB page-size native-library alignment audit
status: To Do
assignee: []
created_date: '2026-07-06 22:15'
labels:
  - native
  - infra
milestone: m-8
dependencies: []
priority: medium
ordinal: 113270
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Android 15+ on 16 KB-page devices refuses to load unaligned native libs. `mobile_scanner 7.x` was deliberately chosen for alignment (pubspec comment), but the `flutter_gemma`/mediapipe `.so`s and `sqlcipher_flutter_libs` are unverified — with targetSdk already 37 this is a live compatibility risk on new hardware.

**Reason for change.** An unaligned `.so` means the app fails to run at all on 16 KB-page devices; a one-off audit plus a repeatable check removes the risk.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The merged APK `.so` alignment is audited (zipalign/llvm-readelf check documented)
- [ ] #2 Any unaligned dependency is bumped, or the finding is recorded with a plan
- [ ] #3 The check is added as a CI step or documented in the release checklist
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Build the debug/release APK and audit every bundled `.so` for 16 KB alignment (zipalign -c -P 16 and/or llvm-readelf segment alignment).
- Document the exact check commands.
- Bump any unaligned dependency (`flutter_gemma`/mediapipe, `sqlcipher_flutter_libs`) or record the finding with a follow-up plan.
- Add the check as a CI step or to the release checklist.
- Verify: `flutter analyze` clean, `flutter test` green.
- Verify: `flutter build apk --debug` succeeds and the alignment check passes on the built APK.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: device-testing sweep 2026-07-07 (version audit)
- Effort: S-M
- Where: `pubspec.yaml`, `android/`, CI workflow or release checklist
- Related: TASK-99, TASK-218
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
