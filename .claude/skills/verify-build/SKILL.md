---
name: verify-build
description: Run bgdude's CI-equivalent verification pipeline locally before committing or opening/updating a PR. Use after finishing ANY code change. `flutter analyze` + `flutter test` passing is NOT sufficient — CI also runs code generation, builds the APK, and runs native Kotlin tests, so a change can be green locally yet break CI. Covers the exact steps, order, and the `dart run` dev-env gotcha.
---

# Verify the build (must match CI — CI is the source of truth)

`.github/workflows/ci.yml` decides whether `main` is green, and **it must never be left
red**. After finishing any task, run the **same pipeline CI runs, in this order**, and only
commit when it all passes:

1. `flutter pub get`
2. `dart run build_runner build --delete-conflicting-outputs` — **required**. Generated files
   (`*.g.dart`, drift) are not committed except `lib/data/database.g.dart`, so analyze/test/
   build all depend on this. It's the step most likely to break CI if you changed codegen
   deps (drift / build_runner).
3. `flutter analyze --fatal-infos` — must be clean. CI fails on **info**-level lints too, so
   anything analyze reports fails the gate.
4. `flutter test --coverage test/` — green, and **line coverage must not drop** (see the
   `coverage-ratchet` skill). This is the scope CI uses; the `integration_test/` suite needs
   an emulator and is separate (see `integration_test/harness.dart`).
5. `flutter build apk --debug` — **required**. Catches Android/Gradle/manifest breakage that
   analyze and unit tests miss. Do not skip it.
6. When native Kotlin changed: `cd android && ./gradlew :app:testDebugUnitTest` — the native
   suite is BLOCKING in CI (`ProtocolProbeTest` guards the read-only-pump charter,
   `PumpResponseMapperTest` guards the mU→U conversions).

If any step fails, fix it before committing — do not push a change that turns CI red. If CI
is already red on `main`, treat getting it green as part of the current task.

## The 16 KB native-library alignment audit is automated now
The former manual release checklist is the `native-lib-alignment` CI job (zipalign + readelf
over the 64-bit ABIs of the built APK). No local step needed — it runs on every PR.

## Native code is buildable/testable here
JDK + Android SDK are present. When writing against pumpx2, verify the API via `javap` on the
cached jar first (see `pumpx2-native-bridge`).

## Dev-env gotcha — don't use `dart run` for throwaway probe scripts
`dart run <script>` crashes on this package (an FFI/kernel-transform exception) **even for
pure-Dart, Flutter-independent files**. To sanity-check a pure-Dart function in isolation,
write a throwaway file under `test/` and run it with `flutter test <file>` instead.
