# Architecture & design review — recommended changes

_Drafted 2026-07-06 from a fresh structural survey (162 Dart files / ~33.9k lines in
`lib/`, plus native Kotlin and Monkey C). Companion docs:
[../REVIEW-recommendations.md](../REVIEW-recommendations.md) (correctness/security
fix list — referenced as P0/P1/P2 below) and
[feature-ideas.md](feature-ideas.md) (new capabilities). This doc is about *shape*:
module boundaries, state management, background execution, and the disciplines that
keep a solo-maintained safety-adjacent app honest._

## Verdict

The middle and bottom of the stack are in good shape and should not be churned:
`lib/core` is genuinely foundational (imported by 67 files, imports nothing),
`analytics/` is fully pure, `ml/` is pure except one file, the `PumpSource`
interface cleanly swaps real pump ↔ simulator, screens get everything through
Riverpod (no service locator), and there are no circular or upward dependencies
(`data/` never imports `state/`/`ui/`; `insights/` never imports `ui/`).

The debt is concentrated in exactly three places, and they compound each other:

1. **`lib/state/providers.dart` is the app.** 2,239 lines, 85 providers, 20 inline
   `StateNotifier` classes, plus two non-provider engines (`AlertService` ~358
   lines, `AppJobs` ~520 lines). It also holds **33 of the codebase's 43 silent
   `catch (_) {}`** and **45 of its 78 raw `DateTime.now()`** calls.
2. **Global static state bypasses the DI story.** `KvStore` is a static class, so
   demo mode's "never touch real data" guarantee holds for the repository but not
   for anything KV-backed.
3. **Aliveness is tied to the widget tree.** Alert evaluation runs off a
   `ref.listen` in `app.dart` — if the Flutter engine dies, alerts die (P1-7). For
   an app whose most important output is "you're going low", this is the biggest
   *architectural* risk in the repo.

Everything below is ranked by (risk reduced × how much later work it unblocks).

---

## A. Split `providers.dart` and standardise the notifier pattern (L — the anchor refactor)

**Target structure** (new files; no behavior change, moves only):

```
lib/state/
  persisted_state_notifier.dart   // the new base class (below)
  settings_providers.dart         // units, profile, thresholds, therapy, A1c, notification prefs
  mode_providers.dart             // illness / medication / weather / exercise-mode state
  meal_providers.dart             // meal library, meal log, barcode, panel-model controller
  pump_providers.dart             // pump source swap, streams, connection state, device changes
  forecast_providers.dart         // forecaster/model/accuracy/sensitivity/TOD providers
  integration_providers.dart      // Nightscout, meter, health-sync config
lib/services/
  alert_service.dart              // AlertService + ConnectionAlertService, extracted whole
  app_jobs.dart                   // AppJobs, extracted whole
```

Rules that make the split stick:

- **Extract `PersistedStateNotifier<T>` first** (P2-12). ~12 notifiers repeat the
  same `_restore()` fired un-awaited from the constructor; a `save()` racing an
  in-flight restore gets clobbered and early readers see placeholders. The base
  class: `Future<void> _ready` completed by `restore()`; `set state` queues behind
  `_ready`; subclasses implement `encode/decode/kvKey`. Migrate two notifiers
  (therapy, thresholds), assert behavior with a race test (`save()` issued before
  restore completes must win), then sweep the rest mechanically.
- **`AlertService` and `AppJobs` take explicit dependencies, not `Ref`.** Both
  currently reach into ~15 providers via `_ref.read`, which is why they have no
  unit tests. Constructor-inject the handful of interfaces they actually use
  (repository, notification service, thresholds snapshot, clock) and keep a thin
  provider that wires them. `test/jobs_test.dart` then stops needing a full
  `ProviderContainer`.
- **One pattern per kind of state:** persisted settings → `PersistedStateNotifier`;
  ephemeral flags → `StateProvider`; derived/read-only → `Provider`/`FutureProvider`;
  device streams → `StreamProvider`. Today's mix is workable but each new feature
  guesses; write the rule down in this file's header comment.
- Do **not** adopt riverpod codegen mid-flight — hand-written providers are fine,
  the codegen deps are currently dead weight (see §J), and the split shouldn't be
  entangled with a framework migration.

*Sequencing note:* land this split **before** the alert-service rework (§C) and the
logging sweep (§D) — both become small PRs against extracted files instead of
surgery inside the god file.

## B. Put `KvStore` behind the DI seam (M)

`KvStore` is all-static (`static AppDatabase? _db`, static getters/setters); so is
`PumpEventLog`'s backing store. Consequences: demo mode can silently write into the
same KV rows as real mode; tests share hidden state unless they remember
`KvStore.useMemory()`; nothing can observe/react to KV writes.

- Introduce `abstract interface class KeyValueStore` with `DbKeyValueStore` and
  `MemoryKeyValueStore` impls; expose via `kvStoreProvider`. Demo mode overrides to
  a namespaced store (`demo/` key prefix or pure-memory) — making the "demo never
  touches real data" guarantee *structural*.
- Migration is mechanical but wide (~40 call sites): keep the static facade
  delegating to the provider-resolved instance during the transition, then delete
  it. `PersistedStateNotifier` (§A) should take the interface from day one so
  migrated notifiers never touch the static.

## C. Decouple aliveness from the widget tree (L, safety-relevant — P1-7)

Today: `app.dart` runs persistence + alert evaluation + Nightscout upload inside a
widget-tree `ref.listen`. The native `PumpService` foreground service keeps BLE
alive, but the *decision* to alert lives in Dart above a killable engine.

Recommended shape (staged):

1. **Extract the pure alert-decision core** out of `AlertService`: a function
   `List<AlertDecision> evaluate(AlertInputs inputs)` with no Riverpod, no
   notifications, no clock reads — inputs in, decisions out. Unit-test the matrix
   (thresholds × trend × quiet hours × dedup windows). This is worth doing even if
   step 2/3 never happen.
2. **Native low-glucose backstop (S–M):** `PumpService` already sees every CGM
   value to forward it; add a dumb native threshold check (urgent-low only,
   hysteresis, respects a "Flutter is alive" heartbeat) so the worst case is
   covered even with the engine dead. Keep it deliberately simpler than the Dart
   engine — it's a backstop, not a port.
3. **Headless Dart evaluation (M–L):** run the full engine via a background
   isolate/WorkManager callback (the `background_summary.dart` pattern) fed by the
   repository, with the same inputs type from step 1. Note the review's warning
   about the background isolate opening a **second SQLCipher connection** — solve
   that first (single connection owner or drift isolate port), or step 3 corrupts
   more than it saves.
4. Meanwhile: document the limitation in the user guide's safety section (honesty
   over silence).

## D. Error-handling and logging discipline (S–M — P1-8)

43 bare `catch (_) {}` (33 in `providers.dart`, dense in `AppJobs.runStartup` and
every notification path). `lib/logging/` exists but only holds `device_changes.dart`.

- Add `lib/logging/app_log.dart`: an on-device ring buffer (KV- or table-backed,
  ~500 entries, no network per the charter) with `AppLog.warn(scope, error, stack)`,
  surfaced read-only on the Advanced screen ("Recent internal errors"). This is the
  ROADMAP Part 4 "on-device-only crash/error logging" item — do it as part of the
  sweep, not separately.
- Sweep rule, applied during the §A split: a swallow is only legal when the
  operation is genuinely optional *and* it logs (`catch (e, s) { AppLog.warn(...); }`).
  Two behavioral bugs to fix during the sweep, not after: a failed urgent-low
  notification must **not** advance the alert's `_lastFired` dedup state, and
  `runStartup` should record per-job failures so a permanently-failing job is
  visible instead of silently skipped for months.

## E. Inject the clock (S–M)

78 raw `DateTime.now()` in `lib/` (45 in `providers.dart`). Every time-relative
behavior (morning-summary windows, exercise-hypo warning, retrain-due check,
overnight features from feature-ideas §1.4) is untestable at the boundary.

- Add `clockProvider` (`DateTime Function() now`), default `DateTime.now`.
  `AppJobs`, `AlertService`, and all `PersistedStateNotifier` subclasses take it via
  constructor (per §A). Pure `analytics/`/`ml/` code already receives explicit
  `DateTime` arguments — keep that style; the provider is for the orchestration layer
  only. Migrate opportunistically with §A's file moves; don't do a big-bang sweep of
  the UI layer (screens using `DateTime.now()` for display formatting are harmless).

## F. Restore `ml/` purity (S)

`lib/ml/forecaster_service.dart` is the single `ml/` file importing
`flutter_riverpod` (the `StateNotifier` for the live model). Split it:
`ForecasterModelStore` + `TrainingOutcome` + the train/gate/promote logic stay in
`ml/` (pure, takes a `KeyValueStore` after §B); the thin
`ForecasterModelController extends StateNotifier` moves to
`lib/state/forecast_providers.dart`. Then the whole `ml/` tree is host-testable with
zero Flutter deps — and a `dart test`-only CI lane for `analytics/` + `ml/` becomes
possible.

## G. Formalise the UI import rule (S)

Current violations of "UI talks to providers, not layers": 1 × `ui → data`
(`meal_library_screen.dart:5` imports `kv_store.dart`) and 3 files × `ui → pump`.
Most are harmless DTO imports (`PumpSnapshot` etc.); the real ones to fix are
`protocol_explorer_screen.dart` importing the `PumpSource` *interface* directly and
the `kv_store` import (falls out of §B).

- Write the rule: **UI may import value/DTO types from any layer; it may not import
  interfaces, stores, or services — those come through providers.**
- Enforce mechanically: a ~30-line `test/architecture_test.dart` that walks
  `lib/ui/**` imports and fails on `data/kv_store`, `pump/pump_source`,
  `pump/pump_client`, `integrations/*client*`. Same test file is the natural home
  for the **read-only pump guarantee**: fail if any Kotlin file under `android/`
  imports `request.control` (turns the charter's central promise from convention
  into a build check — REVIEW §E suggestion).

## H. Data layer hardening (M, mostly REVIEW items — sequenced here because §C/§3 depend on it)

- **Migration tests now, before schema v3.** Adopt drift's schema-export +
  step-by-step migration testing (`drift_dev schema` snapshots committed under
  `test/drift/`). P1-2 (calibration flag) and P1-3 (dedupe keys) are the next
  schema bumps; landing the harness first means those migrations ship tested.
- **One DB connection.** The WorkManager isolate opens a second SQLCipher
  connection to the same file (`background_summary.dart`); move to a shared
  connection (drift `DatabaseConnection.delayed` + isolate port) before any more
  background work (§C step 3, weekly digest) multiplies the risk.
- **Repository unit tests.** The entire `data/` layer has no direct tests. Drift
  runs in-memory on the host (`NativeDatabase.memory()`): add
  `test/history_repository_test.dart` covering upsert/dedupe semantics, prediction
  reconciliation, and the KV round-trip. This is the enabling investment for
  P1-2/P1-3 and the retention work (feature-ideas §3).
- **Batch prediction reconciliation** (one query for all pending rows instead of
  N+1 `cgmBetween` calls) while in there.

## I. Native boundary tidy-up (S–M)

- **Decide the Pigeon question.** `PumpHostApiImpl.kt` is a Pigeon host-API stub
  while Dart uses hand-rolled channels with a comment "until Pigeon is generated".
  Either generate and switch (type-safe, deletes the mapper boilerplate) or delete
  the stub and the comment. Recommendation: **delete** — two channels and a stable
  JSON snapshot schema don't justify a codegen dependency at this scale.
- `history_backfill.dart` opens its own `MethodChannel` — route it through
  `PumpClient` so the channel name lives in exactly one place and the simulator can
  intercept backfill too.
- The threading fixes (EventChannel main-thread posting P1-4, `MutableSnapshot`
  copy-under-lock) are REVIEW items; they slot naturally into whichever PR first
  touches `PumpBridge.kt`.

## J. Dependency & dead-code hygiene (S)

- Remove unused deps: `riverpod_annotation`, `freezed` + `freezed_annotation`,
  `json_serializable` (+ their build_runner config if any). Less to upgrade, less
  to audit, and it removes the temptation of a half-migration to codegen.
- Delete or wire `NightscoutClient.uploadTreatments` (declared, never called —
  docstring promises boluses/carbs reach Nightscout; they don't). Feature-ideas §3
  (follower mode) will rework this file anyway; until then the docstring should
  tell the truth.
- `DayHistoryController._basalObs` grows unbounded within a session — cap it with
  the same ring pattern as `PumpEventLog.maxEvents`.

## K. Test architecture (S–M, ongoing)

Keep the flat `test/` layout (67 files; by-feature naming works at this scale) but
fill the structural gaps in priority order:

1. `data/` repository + migration tests (§H — currently zero).
2. `AlertService` decision-core tests (§C step 1 makes this possible).
3. Provider-level tests for the extracted modules (§A makes `ProviderContainer`
   tests tractable: override repository + clock + KV, assert notifier behavior).
4. `architecture_test.dart` (§G) — cheap, permanent guardrails.
5. Widget tests only for the 3–4 screens with real logic in the widget layer
   (bolus advisor sheet, quick-log); the integration harness (`pumpDemoApp` with
   its three overrides) already covers screen rendering well and is the right tool
   for the rest.

---

## What NOT to change

- **The layering itself** — core → {analytics, ml, data, …} → state → ui is clean
  in practice (one import violation in ~34k lines). Don't introduce a package-based
  monorepo split; directory discipline plus the §G guard test is enough at this size.
- **`PumpSource` / `SimulatedPumpClient` seam** — this is the load-bearing design
  decision of the whole app and it's right. Extend the same seam pattern to new
  integrations (meter transport already follows it; Nightscout-follower should too).
- **Hand-written Riverpod** — consistent enough once §A's rule is written down;
  codegen would be churn without payoff.
- **Pure, constructor-injected `analytics/` + `ml/`** — the reason this session's
  forecasting overhaul was cheap. Guard it (§F, §G) rather than restructure it.
- **The integration-test harness** — `pumpDemoApp` + demo-mode overrides is a
  simple, effective pattern; §B makes its isolation guarantee complete.

## Suggested order

1. §J dead deps + §G guard test (one afternoon, immediate and permanent).
2. §A split incl. `PersistedStateNotifier` + §D logging sweep + §E clock — one
   sustained effort, done file-by-file (each extracted module = one commit with its
   moved tests).
3. §B KvStore seam (unblocked by §A's base class).
4. §H data-layer hardening (migration harness before any schema change).
5. §C alerting aliveness — steps 1–2 soon (pure core + native backstop); step 3
   after §H's single-connection fix.
6. §F + §I as opportunistic small PRs.

The through-line: **shrink the god file, push state behind seams, make aliveness
and honesty structural.** None of it changes what the app does — it changes how
confidently everything else in the roadmap can be built on top.
