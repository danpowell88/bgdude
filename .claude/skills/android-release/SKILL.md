---
name: android-release
description: Build and version bgdude's Android APK, and understand what's decided vs open about release. Use when preparing a release build, bumping the version, or touching build types / signing / R8 keep rules. IMPORTANT — the distribution and real signing path (Play internal track vs sideload) is still UNDECIDED (issue #113); do not invent a signing/store flow.
---

# Android release

bgdude is Android-only. What's currently configured (`android/app/build.gradle`):

- **Versioning** comes from `android/local.properties`: `flutter.versionCode` (default `1`)
  and `flutter.versionName` (default `0.1.0`). Bump these to version a build.
- **SDK levels**: `minSdk 29`, `targetSdk 37`.
- **`release` build type**: `minifyEnabled = true` + `shrinkResources = true` (R8 shrinking is
  on), and `signingConfig = signingConfigs.debug` — i.e. it is currently signed with the
  **debug** key as a placeholder, NOT a real release key.

## The release path is still an open decision — don't invent it
Whether bgdude ships via the Play internal track or a sideloaded APK, and how it's signed
(keystore, key management), is **undecided** — tracked in issue #113 ("Release path"). Do not
fabricate a signing config, keystore, or store-listing flow. If a task needs it, surface the
open decision rather than guessing.

## 16 KB native-library alignment is automated (no manual step)
The former manual release checklist is enforced by the `native-lib-alignment` CI job on every
PR: `zipalign -c -P 16` over all `.so` ZIP entries, plus a `readelf` LOAD-segment check on the
64-bit ABIs (arm64-v8a required, x86_64 when present; 32-bit armeabi-v7a excluded — 4 KB
pages by design). No local pre-release step needed; a native-dependency bump that regresses
alignment reds the build when it lands.

## R8 / keep rules
With `minifyEnabled` on, ProGuard/R8 keep rules matter for anything reached only via
reflection (e.g. pumpx2 message classes, JSON models). If release stripping breaks a
reflective path, add a targeted keep rule rather than disabling shrinking. Google's official
`android/skills` `performance/r8-analyzer` is a good opt-in for auditing keep rules.

## Building
- Debug APK (what CI builds): `flutter build apk --debug`.
- A real release build is blocked on the signing decision above; until then, treat
  `flutter build apk --release` output as debug-signed and not distributable.
