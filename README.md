# bgdude

A **personal** Tandem t:slim X2 companion app for Android. It syncs pump + CGM data
read-only over BLE (via [pumpx2](https://github.com/jwoglom/pumpX2)), pulls contextual
health data from Health Connect, and runs an on-device engine that predicts blood
glucose, simulates insulin/carb "what-ifs", and surfaces daily insulin-sensitivity
insights.

> **This is a personal research tool, not a product.** It reads from the pump and gives
> dosing *suggestions* you enter yourself on the pump — it never sends insulin commands.
> It does not replace your CGM/pump alarms. Its predictions can be wrong. You are the
> informed diabetic in the loop.

## Status

Greenfield implementation, built from the plan in
`~/.claude/plans/come-up-with-a-gentle-feather.md`. Flutter is **not** installed on the
build machine used to author this code, so the codebase is complete and internally
consistent but has not been compiled here — see **Building** below.

## Architecture

```
Flutter (Dart)  ── UI · analytics · ML · insights · encrypted storage
     ▲   │  Pigeon (commands) + EventChannel (state stream)
     │   ▼
Native Kotlin plugin ── PumpService (connectedDevice FGS) owns TandemPump (pumpx2)
     │
     ▼  BLE GATT
t:slim X2  (+ connected Dexcom CGM)
```

Layered Dart modules under `lib/`:

| Module | Responsibility |
|---|---|
| `pump/` | Dart client for the native bridge, connection state, pump models |
| `data/` | drift schema (SQLCipher-encrypted), DAOs, Health Connect sync, units |
| `analytics/` | TIR/GMI/CV/AGP metrics, IOB/COB curves, what-if + bolus advisor |
| `ml/` | sensitivity index, model registry, BG forecaster, event detectors, error grid |
| `feedback/` | annotations → robust retraining pipeline |
| `insights/` | morning summary, reading explainer, illness mode, notifications |
| `timeline/` | day event-stream model + builder (meals, highs/lows, detected events) |
| `meals/` | meal library (learned absorption curves) + pre-bolus coach |
| `dev/` | simulated t:slim X2 + CGM day, for dev mode |
| `ui/` | tab shell (Today · Predict · Insights · Meals), screens, onboarding |

## Dev mode (no hardware needed)

Settings → **Dev mode** runs the app against an in-app simulated t:slim X2 + Dexcom
(`lib/dev/sim_data.dart`), generating a physiologically-consistent day (meals, boluses,
a post-lunch exercise dip, a nocturnal compression low, dawn phenomenon) using the app's
own insulin/carb math. The whole app — timeline, predictions, insights, bolus advisor,
meal coach — becomes usable and demoable without a pump. Integration tests
(`integration_test/app_test.dart`) drive every tab through dev mode on an emulator.

## The day event-stream

The **Today** tab shows a single stream of the day's events — logged meals/boluses,
detected unannounced rises, sustained highs/lows, and compression lows. Each event can be
**tagged** for how the models should treat it: *use for model*, or *ignore* because of a
compression low, a new sensor, a new infusion site, illness, etc. Ignoring writes an
[`Annotation`](lib/feedback/annotations.dart) the retraining pipeline already knows how to
exclude or relabel — closing the feedback loop from the UI.

The pure-Dart domain logic (`analytics/`, `ml/`, `feedback/`) is deterministic and unit
tested (`test/`), so it can be validated off-device with the replay harness even before
a pump is connected.

## Building

Prerequisites: Flutter 3.24+, Android SDK (compileSdk 36, targetSdk 37), JDK 17+.

```bash
flutter pub get
dart run pigeon --input pigeons/pump_api.dart      # regenerate the native bridge
dart run build_runner build --delete-conflicting-outputs   # drift/freezed/riverpod codegen
flutter run                                        # on a real device (BLE needs hardware)
```

### pumpx2 dependency

`android/app/build.gradle` pulls pumpx2 from JitPack by default. To build against a local
checkout, set `use_local_pumpx2=true` in `android/local.properties` and
`./gradlew publishToMavenLocal` inside a pumpx2 clone (see ControlX2 for the pattern).

## Safety model

- **Read-only comms** enforced at the bridge: the native layer exposes no control/bolus
  request path. This is a physiological safety boundary — the pump stays the actuator.
- The **bolus advisor** always shows its working (BG, target, ISF, CR, IOB, context
  multiplier) and leans conservative near predicted lows.
- A retrained model is only promoted after passing an **error-grid safety gate**.

## Tests

```bash
flutter test
```

Domain tests cover: IOB curve shape, TIR/GMI/CV formulas, bolus math edge cases
(high IOB, predicted low, noisy CGM), sensitivity-index bounds, and the error-grid
classifier.
