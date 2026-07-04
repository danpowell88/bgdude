# Setup & build guide

This repo was authored without Flutter installed on the build machine, so the
**standard Flutter platform scaffolding** that `flutter create` normally generates
(Gradle wrapper JAR/scripts, launcher icons, `MainActivity` embedding boilerplate,
generated `*.g.dart` files) is intentionally **not** committed. The hand-written
application code, native bridge, Android manifest/Gradle, and resources **are** here.

Follow these steps on a machine with Flutter to get to a running app.

## 1. Install prerequisites

- Flutter 3.24+ (`flutter --version`)
- Android SDK with **compileSdk 36 / build-tools** and an Android 14+ device or emulator
- JDK 17+ (a JDK 21 is already on this machine)

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

## What to verify (from the plan's verification strategy)

- `flutter test` passes (IOB curve, TIR/GMI/CV, bolus math edge cases, error grid,
  morning-summary logic, retraining robustness, model-promotion gate).
- Foreground service survives swiping the app away (pump stays connected).
- Health Connect rows appear after a Garmin sync.
- The bolus advisor's suggestion matches a hand calculation and never renders a control
  command.
