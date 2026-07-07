---
id: TASK-229
title: 16 KB page-size native-library alignment audit
status: Done
assignee:
  - Claude
created_date: '2026-07-06 22:15'
updated_date: '2026-07-07 23:47'
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
- [x] #1 The merged APK `.so` alignment is audited (zipalign/llvm-readelf check documented)
- [x] #2 Any unaligned dependency is bumped, or the finding is recorded with a plan
- [x] #3 The check is added as a CI step or documented in the release checklist
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 23:42
---
Started: audit the built debug APK's .so alignment for 16 KB page-size compatibility (zipalign -c -P 16), bump/document any unaligned dependency, add the check as a documented release-checklist step.
---

author: Claude
created: 2026-07-07 23:47
---
All 3 ACs done -- and good news: nothing needed bumping.

AC#1: audited the built debug APK with TWO independent checks (both real commands, both actually run, verified against a JDK/NDK/build-tools that are genuinely on this machine, not guessed): zipalign -c -P 16 (ZIP-entry alignment, every lib/**/*.so across all 4 ABIs) and llvm-readelf -l (ELF LOAD-segment alignment, spot-checked on arm64-v8a -- the ABI real Android 15+ hardware ships).

AC#2: both previously-unverified dependencies named in the ticket -- sqlcipher_flutter_libs' libsqlcipher.so and flutter_gemma/mediapipe's 3 .so files (libmediapipe_tasks_vision_jni, libllm_inference_engine_jni, libimagegenerator_gpu) -- are already 16 KB-aligned (zipalign: Verification successful; llvm-readelf: every LOAD segment Align 0x4000). Also independently re-confirmed mobile_scanner's libbarhopper_v3.so (already believed aligned per the pubspec.yaml comment) rather than taking that comment on faith. No dependency bump needed; finding recorded in doc/release-checklist.md with the exact commands and per-library results so a future session doesn't have to re-derive the check.

AC#3: added doc/release-checklist.md (new -- no release checklist existed) rather than a CI step: wiring NDK/build-tools alignment tooling into GitHub Actions' runner is real added complexity/risk for a check that only matters right before a release build, not every commit, and this is a personal single-developer project (decision-2) without an active release cadence yet (TASK-99 -- distribution/signing -- is still undecided). The doc explicitly says to re-run before every release and after any native-dependency bump.

Pipeline: flutter analyze clean (docs-only change; no Dart/native code touched, so test/build_runner/apk build are unaffected by this specific change -- already re-verified fresh in this session via TASK-236's pipeline run moments earlier).
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
