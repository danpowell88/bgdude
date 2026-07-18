# Setup & build guide

This repo was authored without Flutter installed on the build machine, so the
**standard Flutter platform scaffolding** that `flutter create` normally generates
(Gradle wrapper JAR/scripts, launcher icons, `MainActivity` embedding boilerplate,
generated `*.g.dart` files) is intentionally **not** committed, with **one exception**:
`lib/data/database.g.dart` (drift's generated schema/query code) *is* committed, so a
fresh checkout analyzes/builds before you've run codegen even once. Regenerating it
(step 3 below) is still required whenever the drift schema changes — just re-commit
the result along with your change rather than expecting `.gitignore` to hide it.
The hand-written application code, native bridge, Android manifest/Gradle, and
resources **are** here.

Follow these steps on a machine with Flutter to get to a running app.

## 1. Install prerequisites

- Flutter 3.27+ (`flutter --version`; CI builds on pinned stable 3.44.4)
- Android SDK with **compileSdk 36 / build-tools** and an Android 10+ (minSdk 29) device or emulator

### Android version matrix (issue #237)

| API | Android | Role | Tested |
|---|---|---|---|
| **29** | 10 | **Floor** — the lowest version the app claims to run on | Nightly emulator run (non-blocking) |
| **34** | 14 | **Baseline** — the version development targets | Nightly emulator run (blocking) |
| 36 | 16 | compileSdk | Built against; not run in CI |

**Why 29 is the floor.** It is what `minSdk` declares, and the version-gated paths only
execute down there: the pre-31 BLE permission flow (`ACCESS_FINE_LOCATION` for scanning)
and the untyped `startForeground` fallback. A floor that is declared but never exercised
is a guess, so the nightly runs it — marked non-blocking, because a flake on an old, slow
AVD should be a signal rather than something that reds the nightly and trains everyone to
ignore it.

**Note:** issues #241 (lower the floor to 26) and #398 (raise it to 31) both propose
moving this boundary, in opposite directions, and are unresolved. Update this table
whenever `minSdk` in `android/app/build.gradle` changes — it is the human-readable copy
of that number.

**Display variants** are covered in-process by `flutter test`, not only on device: see
`test/support/display_variants.dart` (large text at 1.6×, dark mode, a compact screen,
and the compact + large-text combination, which is where layouts actually break).
- JDK 17+
- [GitHub CLI](https://cli.github.com/) (`gh`), authenticated with `repo` + `project` scopes
  (`gh auth login`) — all task/milestone planning lives in GitHub Issues + the `bgdude`
  project board; see `CLAUDE.md` for the workflow and `doc/process.html` for the pipeline.

## 2. Fill in the generated platform scaffolding

From the repo root, let Flutter add the missing wrapper/icons **without clobbering the
committed source** (it only fills gaps):

```bash
flutter create --org com.bgdude --project-name bgdude --platforms=android .
```

Then restore the two files `flutter create` overwrites with defaults, if it does:
`android/app/src/main/AndroidManifest.xml` and `android/app/build.gradle` are the
customised ones in this repo — re-check them against git after running the command
(`git diff`) and revert any unwanted overwrite.

Create `android/local.properties`:

```
sdk.dir=/path/to/Android/sdk
flutter.sdk=/path/to/flutter
pumpx2_version=1.9.0
# use_local_pumpx2=true   # only if building pumpx2 from a local ~/.m2 publish
```

## 3. Fetch packages & run code generation

```bash
flutter pub get

# Native bridge (generates lib/pump/pigeon/pump_api.g.dart + android .../PumpApi.g.kt)
dart run pigeon --input pigeons/pump_api.dart

# drift + freezed + json + riverpod codegen (generates *.g.dart / *.freezed.dart)
dart run build_runner build --delete-conflicting-outputs
```

After Pigeon runs, wire the generated host API in two spots (marked with TODO-style
comments in the code):
- `android/.../pump/PumpHostApiImpl.kt` — change the class to implement the generated
  `PumpHostApi` and map the native types onto the generated data classes.
- `android/.../pump/PumpBridge.kt` (`PumpHostApiRegistrar.register`) — replace the
  placeholder with `PumpHostApi.setUp(messenger, impl)`.

The read path (EventChannel `bgdude/pump_events`) works without Pigeon, so you can see
live pump data before finishing the command-surface wiring.

## 4. Run

```bash
flutter test          # domain unit tests (no device needed)
flutter run           # on a real device — BLE + Health Connect need hardware
```

## 5. First-run on device

1. Grant Bluetooth + notification permissions.
2. Grant Health Connect access (sleep, HRV, resting HR, steps, workouts). Garmin data
   must already be syncing into Health Connect via Garmin Connect → Google Health.
3. On the pump: Bluetooth Settings → enable Mobile Connection → Pair Device, then enter
   the shown code in the app. **This unpairs the official t:connect app.**

## 6. Verify like CI before committing anything

`.github/workflows/ci.yml` is the source of truth for whether `main` is green — it does
more than `flutter analyze`/`flutter test`, so "green locally" can still fail CI. Before
every commit, run the same pipeline **in this order** (the full rationale for each step
lives in `CLAUDE.md`):

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # required; generated files aren't committed (except database.g.dart, see above)
flutter analyze                                             # must be clean
flutter test test/                                          # must be green — this is CI's scope; integration_test/ is separate
flutter build apk --debug                                   # required; catches Android/Gradle/manifest breakage the two steps above miss
```

If you touched native Kotlin, also run `cd android && ./gradlew :app:testDebugUnitTest`.
Fix any failure before committing — never push a change that would turn CI red.

## 7. Emulator setup for integration_test/

Every user-facing screen has coverage under `integration_test/` (run in demo mode; see
`integration_test/harness.dart`), which needs a device — `flutter test test/` does not
exercise it.

```bash
# One-time: create an AVD (adjust API level/type to what you need to cover)
avdmanager create avd -n Pixel_7_Pro -k "system-images;android-34;google_apis;x86_64"

# List / launch
flutter emulators
flutter emulators --launch Pixel_7_Pro
adb devices                                                  # confirm it's up, e.g. emulator-5554

# Run one functional integration test file against it
flutter test integration_test/<file>_test.dart -d emulator-5554
```

Run the functional `*_test.dart` files explicitly rather than the whole `integration_test/`
folder — `screenshots_test.dart` and `walkthrough_test.dart` need `flutter drive`
(`tools/gen_docs.ps1`), not `flutter test`, and will fail/hang if picked up by a plain
folder run.

## 8. pumpx2 API verification (javap)

Native pump code calls into the reverse-engineered [pumpx2](https://github.com/jwoglom/pumpX2)
library (`com.github.jwoglom.pumpX2`, pulled from JitPack by default — see
`README.md`'s "pumpx2 dependency" section for building against a local checkout instead).
Before writing code against an unfamiliar pumpx2 class/method, verify it exists with the
signature you expect by disassembling the cached jar rather than guessing from memory or
the upstream repo's possibly-different version:

```bash
# pumpx2-messages / pumpx2-shared (plain jars, request/response message classes):
# the path segment after files-2.1/<group>/<artifact>/<version>/ is a content hash
# and varies per machine.
find ~/.gradle/caches/modules-2/files-2.1/com.github.jwoglom.pumpX2 -name "*.jar"

# pumpx2-android (an AAR — the BLE/pairing classes, e.g. TandemBluetoothHandler):
# Gradle extracts its classes.jar into the transforms cache after AAR processing.
find ~/.gradle/caches -path "*transforms*" -iname "pumpx2-android*runtime.jar"

# Disassemble a class's public API
javap -c -classpath <jar path> com.jwoglom.pumpx2.pump.messages.request.currentStatus.AlertStatusRequest
```

JDK's `javap` must be on `PATH` (or invoke it with a full path, e.g.
`"/c/Program Files/Eclipse Adoptium/jdk-21.../bin/javap"` on Windows).

## 9. Troubleshooting

- **`build_runner` reports conflicting outputs / stale generated files** — re-run with
  `--delete-conflicting-outputs` (already the documented command above); if that alone
  doesn't clear it, delete `.dart_tool/build` and retry.
- **JitPack pumpx2 dependency fails to resolve** — JitPack builds the artifact lazily on
  first request and can time out or 404 briefly after a new tag is pushed upstream; retry
  after a minute, or fall back to `use_local_pumpx2=true` (see step 2) if it's persistent.
- **Pigeon-generated leftovers after changing `pigeons/pump_api.dart`** — re-run
  `dart run pigeon --input pigeons/pump_api.dart`; if the generated Kotlin/Dart look stale
  or inconsistent, delete `lib/pump/pigeon/pump_api.g.dart` and the generated
  `android/.../PumpApi.g.kt` first and regenerate from a clean slate.
- **`flutter create` (step 2) overwrote a customised file** — check `git diff` for
  `android/app/src/main/AndroidManifest.xml` and `android/app/build.gradle` specifically
  (the two files known to differ from the Flutter template) and revert unwanted changes.

## What to verify (from the plan's verification strategy)

- `flutter test` passes (IOB curve, TIR/GMI/CV, bolus math edge cases, error grid,
  morning-summary logic, retraining robustness, model-promotion gate).
- Foreground service survives swiping the app away (pump stays connected).
- Health Connect rows appear after a Garmin sync.
- The bolus advisor's suggestion matches a hand calculation and never renders a control
  command.
