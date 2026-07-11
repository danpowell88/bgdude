# Release checklist

Steps to run before any release build (Play internal track or a sideloaded APK for a
real device) — see the "Release path" issue (old TASK-99; find it via
`doc/backlog-migration-map.md` or `gh issue list --search "Release path in:title"`) for the
still-undecided distribution/signing question this checklist doesn't cover yet.

## 16 KB page-size native-library alignment (TASK-229)

Android 15+ devices with a 16 KB memory page size refuse to load a native library
(`.so`) whose ELF `LOAD` segments aren't aligned to a 16 KB boundary — the app fails to
launch at all on that hardware. `targetSdk` is already 37, so this is a live
compatibility risk, not a future one. Two independent checks, both against the actual
built APK (not the SDK/AAR sources, since packaging can still misalign an
already-aligned `.so`):

**1. ZIP-entry alignment** (`zipalign`, Android SDK build-tools):

```bash
# Windows path shown; adjust for the build-tools version installed
"$ANDROID_HOME/build-tools/<version>/zipalign.exe" -c -v -P 16 4 build/app/outputs/flutter-apk/app-debug.apk
```

Every `lib/**/*.so` entry must report `(OK)`, and the run must end with
`Verification successful`. A `(BAD ...)` entry means that library's zip offset isn't
16 KB-aligned even though the `.so` itself might be — usually fixable by bumping AGP or
the offending plugin.

**2. ELF segment alignment** (`llvm-readelf`, bundled with the Android NDK) — the
deeper check; a library can pass step 1 (correct zip placement) while still being
compiled without 16 KB-aligned `LOAD` segments:

```bash
unzip -o app-debug.apk "lib/arm64-v8a/<name>.so" -d /tmp/apk_extract
"$ANDROID_NDK/toolchains/llvm/prebuilt/<host>/bin/llvm-readelf.exe" -l /tmp/apk_extract/lib/arm64-v8a/<name>.so | grep "^  LOAD"
```

Every `LOAD` line's trailing `Align` column must be `0x4000` (16384) or a multiple of
it — `0x1000` (4 KB, the old default) means that specific `.so` needs a newer build of
the library (recompiled with 16 KB page support) or a replacement.

**Audited 2026-07-08** (debug APK, all four architectures' `.so`s via `zipalign`; ELF
segments spot-checked on `arm64-v8a`, the architecture real Android 15+ hardware
actually ships): every bundled library — including the two previously unverified ones
named in TASK-229 (`sqlcipher_flutter_libs`'s `libsqlcipher.so`, and
`flutter_gemma`/mediapipe's `libmediapipe_tasks_vision_jni.so`,
`libllm_inference_engine_jni.so`, `libimagegenerator_gpu.so`) — passed both checks
(`zipalign`: `Verification successful`; `llvm-readelf`: every `LOAD` segment
`Align 0x4000`). `mobile_scanner`'s `libbarhopper_v3.so` (already deliberately pinned
to 7.x for alignment per the `pubspec.yaml` comment) and Flutter's own `libflutter.so`
also passed. No dependency bump needed at this time.

**Re-run before every release**, and whenever a native-dependency version bumps
(`mobile_scanner`, `flutter_gemma`/mediapipe, `sqlcipher_flutter_libs`, or any new
plugin that bundles a `.so`) — a passing audit today doesn't guarantee a passing one
after the next `flutter pub upgrade`.
