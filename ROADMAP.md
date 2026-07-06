# bgdude — The Plan

_The single planning document: roadmap, fix list, architecture changes, feature
backlog and sequencing. Consolidated 2026-07-06 from `ROADMAP.md`,
`doc/REVIEW-recommendations.md` (the July 2026 engineering/clinical review — full
evidence preserved verbatim in git history at commit `7385bda`),
`doc/plans/architecture.md`, `doc/plans/feature-ideas.md` and
`doc/plans/panel-llm.md`, which this file replaces._

**Charter (don't drift from this):** a personal, **read-only** Tandem t:slim X2
companion. On-device first, privacy-preserving, never delivers insulin or control
commands. Every number the app suggests is shown with its working and confirmed by
you before it matters.

**Legend** — Effort: **S** ≤ ½ day · **M** 1–2 days · **L** 3+ days.
🔌 = needs specific hardware to verify · 🧠 = uses the on-device LLM runtime ·
🔒 = safety-sensitive. Fix ids (P0-x/P1-x/P2-x) come from the July 2026 review.

**Context decisions (standing):** audience is personal (Summer) — skip multi-user
UX, store compliance, public onboarding polish. Hardware available: t:slim X2,
Dexcom CGM, Accu-Chek Guide Me, Garmin watch, Pixel 7 Pro — every 🔌 item is
verifiable, collaboratively ("build + exact test procedure → you run it → report
→ fix"). Neural (LiteRT) forecaster: **decided against** — committed to the
pure-Dart GBM (revisit only if real-hardware accuracy plateaus).

---

## Status snapshot (what's already real)

Working & verified on emulator / unit-tested: onboarding + demo mode, Today
(glucose hero + day-trend, next-few-hours + on-board IOB/COB/basal charts), Predict
(horizons, scenario lines, what-if), Insights (briefing, sensitivity, A1c/GMI + lab
A1c, sleep), Meals (library, barcode, name search, nutrition-label OCR scan,
pre-bolus/FPU coach), Bolus advisor (carbs + correction + fat/protein FPU,
Control-IQ aware), Quick-log (carbs/bolus/exercise/alcohol/stress/mood/illness/
sensor/site), Confirm-events inbox, Exercise/Medication/Illness/Weather modes,
Notifications (19 categories incl. anomaly + morning summary), 7 Reports + PDF/CSV,
Pump screen (Control-IQ mode), Therapy/Basal, Advanced/models, Profile, Home-screen
widget, Garmin widget/watch-face/data-field, demo mode seeded with ~2 weeks of
history.

Forecaster = deterministic baseline + learned GBM residual. **July 2026 ML
overhaul (done):** promotion A/Bs candidate vs baseline *and* the live model on the
same held-out tail; sigma from held-out error; no future-dose leakage in training;
training off the UI isolate, ~once a day; hypo gate skips hypo-free windows
(P2-3 ✅); dead sensitivity feature removed (P2-6 ✅); Autotune label is a
duration-weighted median of window ratios; ridge lambda by LOO-CV with skill-based
confidence (most of P2-5 ✅); Clarke zones B/C/D/E reference-tested (part of
P2-10 ✅); direct tests for autotune/ridge/forecaster-service.

---

## Suggested execution order (master)

The through-line: **make the numbers right (Phase 1), make the data trustworthy
(2), make the safety net structural (3), then make forecasting honest (5) — with
hardware verification (4) interleaved whenever device time exists, and the big
architecture consolidation (6) once the safety-critical work has landed.**

| Phase | What | Why this order | Contents |
|---|---|---|---|
| **0. Hygiene & quick safety** (days) | Dead deps, architecture guard test (incl. mechanical read-only-pump check), Keystore fix, the five S-sized dosing-math fixes | Cheap, permanent, independent; P0-1/4/5/6/7 change dosing numbers *today* | §1 P0-1,4,5,6,7 · P1-1 · §3.G, §3.J |
| **1. Root model fix** | Net-basal/EGP baseline + re-tune + like-for-like sensitivity | The single highest-ROI change; every learned label inherits its drift until fixed | §1 P0-2, P0-3 |
| **2. Data integrity & storage** | Drift migration harness → schema v3 (calibration flag + dedupe) → repo tests, batched reconciliation, retention | Dosing advice reads IOB/TDD from this data; also unblocks Phases 3.3 and 5 | §1 P1-2, P1-3, P1-6 · §3.H · §4-3 retention |
| **3. Alert-aliveness backstop** | Pure alert-decision core + native urgent-low backstop; document the limitation | The most safety-relevant *architectural* gap; steps 1–2 are cheap and independent of the big refactor | §3.C steps 1–2 (P1-7 partial) |
| **4. Hardware verification track** (interleaved, 🔌-gated) | Native thread/boot fixes first, then: Gemma on-device (with §5 items 1–3 landed first) → meter → Garmin (incl. complication) → pump reliability | P1-4/P1-5 crash on first real connection otherwise; order matches prior session's decided direction | §1 P1-4, P1-5, P1-9 · §2 items 1.1→1.6 · P2-8 |
| **5. Honest forecasting** | Robust ROC → quantile bands → conformal calibration → meal detection → overnight-low → walk-forward + rollback | Each step feeds the next; makes Predict/alerts trustworthy rather than plausible; completes P2-1/P2-2/P2-4 | §4-1: 1.8 → 1.1 → 1.2 → 1.3 → 1.4 → 1.10 (+P2-9) |
| **6. Architecture consolidation** | providers.dart split + PersistedStateNotifier + logging sweep + clock injection → KvStore seam → headless alert evaluation | Invasive but mechanical; safer after the safety-critical phases; step 6.3 needs Phase 2's single-connection fix | §3.A, D, E → §3.B → §3.C step 3 · §3.F, §3.I |
| **7. Depth & breadth (by appetite)** | Exercise tails, warm start, per-meal absorption; free-text meal→macros; Nightscout follower; reports/release polish | Pick by energy: forecast depth (§4-1.5/1.6/1.9), LLM daily value (§4-4.1), or data breadth (§4-3) | §4 remainder · §5 remainder · §6 |

Rules of thumb: the hardware track (4) runs opportunistically alongside any desk
phase; nothing in Phase 5+ should start before Phase 1 lands (labels are poisoned
until then); every user-visible change updates `doc/user-guide.html` + an
integration test in the same commit.

---

## §1. Correctness & safety fixes (from the July 2026 review)

### The three headline issues

1. **Basal modeled as un-opposed glucose-lowering force (no EGP term)** — cancels
   corrections to ~0 in the advisor (under-dosing highs) and scores a well-tuned
   user as maximally insulin-resistant, poisoning every learned label. One fix:
   model insulin effect from *net* insulin (boluses + basal deviation from
   schedule), treating scheduled basal as EGP-neutral. → P0-2/P0-3.
2. **At-rest encryption is theater** — the SQLCipher passphrase sits in plaintext
   SharedPreferences next to the ciphertext, while comments/README claim Keystore.
   → P1-1.
3. **Events duplicate; fingersticks corrupt the CGM series** — no dedupe on
   bolus/carb/basal inserts (inflates IOB/TDD used for advice); meter readings are
   indistinguishable from sensor rows and can overwrite them. → P1-2/P1-3.

### P0 — safety-relevant correctness

| # | Fix | Where | Effort | Status |
|---|-----|-------|--------|--------|
| P0-1 | Correction subtracts **bolus-only (or net) IOB**, not total incl. basal (`_iob.fromBoluses(...)` for the subtraction; full IOB only for forward prediction) | `bolus_advisor.dart:191,293-294` | S | open |
| P0-2 | Predictor models insulin effect from **net insulin** (boluses + delivered−scheduled basal) or adds an EGP term; re-tune constants + tests after | `predictor.dart:290-291`, `insulin_math.dart:107-145` | M | open |
| P0-3 | Autotune & TOD sensitivity compare like-for-like after P0-2 — a well-tuned fasting user must score ≈1.0 | `autotune.dart`, `time_of_day_sensitivity.dart` | M (falls out of P0-2) | open |
| P0-4 | Advisor/predictor honour configured **DIA & insulin peak** (care detectors already do; advisor/predictor hardcode 360/75) | `bolus_advisor.dart:102-103`, `predictor.dart:177-178` | S | open |
| P0-5 | Rescue-carb calc uses **bolus-only IOB** so phantom basal doesn't over-treat lows | `rescue_carbs.dart:56` | S | open |
| P0-6 | Advisor: hard low-guard on the *current* reading + compression-low exclusion ("treat the low first") | `bolus_advisor.dart:183` | S | open |
| P0-7 | Ketone/DKA prompt earlier: base threshold 250 mg/dL + unconditional prompt >~300 rising / very-low IOB | `ketone_risk.dart:21` | S | open |

### P1 — data integrity, security, reliability

| # | Fix | Where | Effort | Status |
|---|-----|-------|--------|--------|
| P1-1 | DB passphrase → `flutter_secure_storage` (Keystore); migrate off prefs; await the write; fix false comments | `secure_key.dart`, `database.dart:187`, `main.dart` | S | open |
| P1-2 | `isCalibration`/`source` on CGM rows (schema v3); stop fingersticks overwriting sensor rows; exclude calibrations from metrics/training | `database.dart`, `history_repository.dart`, `glucose_meter.dart` | M | open |
| P1-3 | Dedupe bolus/carb/basal (unique key or event-id + upsert); fix `_lastBolusTime` restart race | `database.dart`, `day_history_controller.dart`, `history_backfill.dart` | M | open |
| P1-4 | Native EventChannel sink marshalled to the main looper (BLE callbacks arrive off-thread; first real connection kills the stream) | `PumpBridge.kt:128-155` | S | open |
| P1-5 | BootReceiver: gate on BT permission; add auto-reconnect so a boot restart actually resumes | `BootReceiver.kt`, `PumpService.kt` | S–M | open |
| P1-6 | Surface DB-open failure (banner + log) instead of silently swapping to in-memory | `main.dart:26-34` | S | open |
| P1-7 | Alerts survive engine death — see §3.C (staged: pure core → native backstop → headless evaluation) | `app.dart`, native | L | open |
| P1-8 | Replace silent `catch (_)` with logged catches; don't advance `_lastFired` on a failed urgent-low — see §3.D | `providers.dart` throughout | S | open |
| P1-9 | Model-download security: reject HTTP, token only to HF/Kaggle hosts, SHA-256 verify, don't echo URL/token | `panel_model_manager.dart`, `ai_model_screen.dart` | S–M | open (overlaps §5-5) |

### P2 — robustness, ML honesty, cleanups

| # | Fix | Effort | Status |
|---|-----|--------|--------|
| P2-1 | Honest intervals: held-out sigma ✅ (Jul 2026) · bias correction + coverage reporting + quantile tails → §4-1.1/1.2 | M | **partial** |
| P2-2 | Purged/blocked walk-forward validation replacing the single time-split → §4-1.10 | M | open |
| P2-3 | Promotion gate skips hypo criterion on hypo-free tails | S | **done ✅** |
| P2-4 | Regularize/early-stop the GBM (validation-chosen `nEstimators`, subsampling) — fold into §4-1.10's fold work | M | open |
| P2-5 | Sensitivity model validation: LOO-CV lambda + skill-based confidence ✅ · remaining: sign-constrained coefficients; only adopt learned model if it beats the heuristic | M | **partial** |
| P2-6 | Dead constant sensitivity feature removed (feature v4) | S | **done ✅** |
| P2-7 | Health-feature look-ahead leak (trailing resting-HR baseline) + `_activityAt` binary search | S–M | open |
| P2-8 | Garmin: real delta (consecutive distinct timestamps) + plumb display unit instead of hardcoded mmol | S | open |
| P2-9 | Report providers `ref.watch` the repository (demo-mode toggle rebuilds); re-scan pending confirmations on new CGM | S | open |
| P2-10 | Clarke grid: zone B/C/D/E reference tests ✅ · optional: switch to Parkes/consensus grid | M | **partial** |
| P2-11 | Panel parser quirks (%DV, kJ/kcal split, EU Salt, ml servings) + LLM-gate fix → §5-1/2 and §5-7 | M | open |
| P2-12 | Split `providers.dart` + `PersistedStateNotifier` base → §3.A | L | open |

### Testing & validation principles (from the review)

Repository tests against in-memory `NativeDatabase` (upsert, reconciliation,
dedupe); `ingestSnapshot` restart/dedupe test; ML honesty metrics (coverage + bias)
as first-class; drift schema-export + migration tests **before** schema v3; a
build-failing check that `request.control` is never imported natively (§3.G).

---

## §2. Finish what's started (device verification — Phase 4)

| # | Item | What's done | Remaining | Effort | Flags |
|---|------|-------------|-----------|--------|-------|
| 2-1 | **Nutrition-label AI (Gemma)** | Runtime wired (flutter_gemma on AGP 8.9), download/manage UI, gated fallback, builds + launches | Verify inference on a real device with a real model; curate a known-good Gemma 3 1B `.task` URL + licence flow; auto-suggest download on scan failure; RAM/space gating (→ §5-5); consider fine-tuned Gemma 3 270M (→ §5-8) | M | 🔌🧠 |
| 2-2 | **Bluetooth meter (Accu-Chek Guide Me)** | Decoder, RACP sync, transport, pair/manage UI, unit tests | Field-test pairing + sync; bonding/re-discovery edges; dedupe/merge fingersticks with CGM (needs P1-2); background sync | M | 🔌 |
| 2-3 | **Garmin complication** | 3 products build/run in sim; mis-implemented complication removed | Implement the real publisher (resource-defined complication + `updateComplication`, gated on `has :Complications` per `garmin/COMPLICATIONS.md`); verify on-watch. The highest-leverage Garmin item — exposes BG to every face | M | 🔌 |
| 2-4 | **Garmin on-watch verification + devices** | Sim-verified; screenshots | Install on paired watch; confirm phone→watch push + background service; add current-gen devices (fenix 8, FR 165/970, venu/vivoactive 6) to the 3 manifests; raise `minApiLevel` or prune products lacking `registerForPhoneAppMessageEvent` | S–M | 🔌 |
| 2-5 | **Pump pairing robustness (pumpx2)** | Native read path, pairing dialog, reconnect | Real-hardware reliability pass: pairing retries, reconnect, error surfacing, t:connect mutual-exclusion, long-run stability. **P1-4/P1-5 first** — they crash on first real connection | M | 🔌 |
| 2-6 | **Mood logging** | Captured as annotation | Make it do something (→ §4-4.4) or declare journal-only in the guide | S | |

Sequence within the track (decided earlier, still right): Gemma scanner → meter →
Garmin (2-4 then 2-3) → pump. Each is "prepare build + exact procedure → run on
device → report → fix".

---

## §3. Architecture & design changes

_From the 2026-07-06 structural survey (162 files / ~33.9k lines). What's healthy:
`core` is genuinely foundational (67 importers, zero imports), `analytics/` fully
pure, one layering violation in the whole tree, clean `PumpSource` ↔ simulator
seam, everything through Riverpod (no service locator), no upward/circular deps.
The debt concentrates in three compounding places: the providers god file, static
KV state, and widget-tree-bound aliveness._

### 3.A Split `providers.dart` + `PersistedStateNotifier` (L — the anchor refactor; P2-12)

`lib/state/providers.dart`: 2,239 lines, 85 providers, 20 inline notifiers, plus
`AlertService` (~358 lines) and `AppJobs` (~520 lines); 33 of 43 codebase silent
catches and 45 of 78 raw `DateTime.now()` live here. Target:

```
lib/state/   persisted_state_notifier.dart, settings_providers.dart,
             mode_providers.dart, meal_providers.dart, pump_providers.dart,
             forecast_providers.dart, integration_providers.dart
lib/services/ alert_service.dart, app_jobs.dart
```

- **`PersistedStateNotifier<T>` first:** ~12 notifiers repeat an un-awaited
  `_restore()` constructor race (a `save()` racing restore gets clobbered). Base:
  `_ready` future completed by restore; saves queue behind it; subclasses provide
  `encode/decode/kvKey`. Migrate two notifiers + a race test, then sweep.
- **`AlertService`/`AppJobs` take explicit deps, not `Ref`** (repository,
  notification service, thresholds, clock) — that's what makes them unit-testable.
- **One pattern per state kind** (persisted → base class; flags → `StateProvider`;
  derived → `Provider`/`FutureProvider`; device streams → `StreamProvider`);
  written down in the module header.
- **No riverpod codegen migration** — hand-written is fine; don't entangle the
  split with a framework change.

### 3.B `KvStore` behind the DI seam (M)

Static `KvStore` (and `PumpEventLog`'s store) bypass Riverpod, so demo mode's
"never touch real data" holds for the repository but not KV-backed state.
`KeyValueStore` interface + `DbKeyValueStore`/`MemoryKeyValueStore` via
`kvStoreProvider`; demo overrides to a namespaced/memory store — the isolation
guarantee becomes structural. Keep a delegating static facade during migration
(~40 call sites), then delete. `PersistedStateNotifier` takes the interface from
day one.

### 3.C Decouple aliveness from the widget tree (L, 🔒 — P1-7)

Alert evaluation runs off a `ref.listen` in `app.dart`; engine dies → alerts die.
Staged:

1. **Pure decision core** (do regardless): `evaluate(AlertInputs) →
   List<AlertDecision>`, no Riverpod/clock/notifications inside; unit-test the
   matrix (thresholds × trend × quiet hours × dedup).
2. **Native urgent-low backstop (S–M):** `PumpService` already sees every CGM
   value; add a deliberately-dumb native threshold check (urgent-low only,
   hysteresis, "Flutter alive" heartbeat suppression).
3. **Headless Dart evaluation (M–L):** WorkManager/isolate-driven engine fed by
   the repository — **only after** the single-DB-connection fix (§3.H); the
   background isolate currently opens a second SQLCipher connection.
4. Until then: document the limitation in the user guide's safety section.

### 3.D Error-handling & logging discipline (S–M — P1-8)

43 bare `catch (_) {}` (33 in providers.dart). Add `lib/logging/app_log.dart`: an
on-device ring buffer (~500 entries, no network), surfaced read-only on the
Advanced screen — this *is* the "on-device crash/error logging" infra item, do it
as part of the sweep. Sweep rule: a swallow is legal only if the operation is
optional *and* it logs. Two behavioral fixes during the sweep: failed urgent-low
must not advance `_lastFired`; `runStartup` records per-job failures so a
permanently-failing job is visible.

### 3.E Inject the clock (S–M)

78 raw `DateTime.now()` (45 in providers.dart) make time-relative behavior
untestable. `clockProvider` (`DateTime Function()`), constructor-injected into
`AppJobs`/`AlertService`/persisted notifiers during §3.A moves. Pure
`analytics/`/`ml/` already take explicit `DateTime` args — keep that style; don't
sweep display-only UI usages.

### 3.F Restore `ml/` purity (S)

`ml/forecaster_service.dart` is the only `ml/` file importing Riverpod. Split:
store + train/gate/promote logic stay in `ml/` (pure; takes `KeyValueStore` after
§3.B); the thin `StateNotifier` controller moves to `state/forecast_providers.dart`.
Enables a `dart test`-only CI lane for `analytics/` + `ml/`.

### 3.G Architecture guard test (S — do in Phase 0)

Rule: **UI may import value/DTO types from any layer; never interfaces, stores or
services** (those come via providers). Current violations: `meal_library_screen.dart`
→ `kv_store.dart`; `protocol_explorer_screen.dart` → `pump_source.dart` interface.
Enforce with `test/architecture_test.dart` (~30 lines walking `lib/ui/**` imports) —
and in the same file, **fail the build if any Kotlin file imports
`request.control`**, turning the read-only-pump promise into a mechanical check.

### 3.H Data-layer hardening (M — Phase 2)

- Drift **schema-export + step migration tests** (`test/drift/` snapshots) *before*
  schema v3 (P1-2/P1-3).
- **One DB connection** across isolates (drift `DatabaseConnection.delayed` /
  isolate port) — prerequisite for §3.C step 3 and any new background work.
- **Repository unit tests** on `NativeDatabase.memory()` — the whole `data/` layer
  currently has zero direct tests; covers upsert/dedupe, reconciliation, KV.
- **Batch prediction reconciliation** (currently N+1 `cgmBetween` per pending row).

### 3.I Native boundary tidy-up (S–M)

- **Pigeon: delete the stub.** `PumpHostApiImpl.kt` awaits a codegen migration
  that two channels + a stable JSON schema don't justify; remove it and the
  "until Pigeon is generated" comments.
- Route `history_backfill.dart`'s private `MethodChannel` through `PumpClient` so
  the channel name lives once and the simulator can intercept backfill.
- Threading fixes (P1-4 main-looper sink, `MutableSnapshot` copy-under-lock,
  `requestStatusJson` returning the *previous* snapshot) slot into the first PR
  touching `PumpBridge.kt` — before real-pump testing.

### 3.J Dependency & dead-code hygiene (S — Phase 0)

Remove unused deps (`riverpod_annotation`, `freezed`/`freezed_annotation`,
`json_serializable`); delete or wire `NightscoutClient.uploadTreatments` (declared,
never called — docstring lies until §4-3 follower work); cap
`DayHistoryController._basalObs` (unbounded within a session) with the
`PumpEventLog.maxEvents` ring pattern.

### 3.K Test architecture (ongoing)

Keep the flat `test/` layout. Fill gaps in order: data-layer tests (§3.H) →
alert decision-core tests (§3.C-1) → provider-module tests (post-§3.A) →
`architecture_test.dart` (§3.G) → widget tests only for the 3–4 screens with real
widget-layer logic (bolus sheet, quick-log); the `pumpDemoApp` integration harness
covers the rest well.

### What NOT to change

The layering itself (directory discipline + guard test beats a package split at
this size); the `PumpSource`/simulator seam (extend the pattern to new
integrations instead); hand-written Riverpod; pure constructor-injected
`analytics/`+`ml/`; the integration-test harness.

---

## §4. Feature backlog (forecasting first, with implementation notes)

**Prerequisite for all of §4-1: P0-2 (EGP baseline).** Until then residual and
Autotune labels inherit the baseline's drift.

**Top 5 if only five get built:** overnight-low forecast (1.4) · quantile bands +
coverage (1.1) · unannounced-meal detection (1.3) · population warm start (1.6) ·
free-text meal → macros (4.1).

### §4-1 Forecasting core

**1.1 Honest, asymmetric prediction intervals (M)** — completes P2-1.
Quantile GBMs at q10/q50/q90: pinball loss in `gbm.dart` (pseudo-residual `τ` /
`τ−1`; leaf value = weighted τ-quantile; keep the variance split criterion;
`loss`/`tau` in JSON). `ResidualGbmModel` grows lower/upper ensembles;
`ResidualModel` gains a quantile path defaulting to `±kForecastZ90·σ` so
`NoResidualModel` keeps working; `Forecaster` builds the band from offsets.
Gotcha: the retraining pipeline's Huber clip (±30) flattens tails — clip wider
(~60) for the q10/q90 fits. Reporting: per-horizon **coverage** and
**mean signed error** on `ModelAccuracyScreen` (from stored `lower/upperMgdl`).
Gate: add `minCoverage` once measured. Tests: asymmetric-noise quantile recovery
in `gbm_test`; enforce lower ≤ median ≤ upper by sorting at predict time
(quantile crossing is real).

**1.2 Conformal calibration of the live band (S–M).**
Extend `UncertaintyCalibrator`: per-horizon *ratio scores*
`|actual−predicted| / halfWidth` over 14 d of reconciled predictions → band scale =
`⌈(n+1)(1−α)⌉/n` empirical quantile (α=0.10). Ratio scoring preserves the learned
band *shape* (incl. 1.1 asymmetry — score each side separately for two scales).
Unlike today's widen-only rule it can tighten; keep a floor (≥0.7×) so a lucky
fortnight can't produce overconfidence. `minSamples=20` guard stays; recompute in
`updateRecentForecastError`. Tests: synthetic triples hit 86–94% coverage from
both directions; floor engages.

**1.3 Unannounced-meal detection → live forecast (M).**
`MealDetector` (`ml/event_detectors.dart`) exists with zero callers and zero tests
— test it first. Wire: (a) run over last ~45 min at each forecast refresh; on
detection append a synthetic `CarbEntry` **inside the forecast-state builder
only** — it may bend the cone but must never reach the bolus advisor's COB or be
persisted; Predict shows a chip ("assuming ~35 g unlogged — confirm?"). (b) stage
a `PendingConfirmation`; confirming writes the real entry via quick-log; dismissing
KV-suppresses that window. (c) pass detected windows into `Autotune.analyseDay` as
pseudo-carbs so unlogged meals stop reading as resistance. Safety: ≥15 min
sustained, cap ~60 g, decay when the rise stops. Tests: detector units; bent-cone +
staged-confirmation provider test; Autotune no-longer-inflated test.

**1.4 Bedtime / overnight-low forecast (M).**
New `insights/overnight_low.dart`: inputs all exist — BG/trend, bolus-IOB tail
projected hourly, tonight's basal schedule, today's workouts + `WorkoutType`
(aerobic raises risk), alcohol events, overnight `TimeOfDayProfile` buckets.
Method: hourly deterministic run to +8 h, residual correction to 120 min, then
extrapolate the **lower band edge only** (no point-accuracy pretense at 6 h);
`risk = f(min lower edge, minutes < 80, aerobic load, alcohol)` → 3 tiers with
explicit reasons. Snack sizing via `rescue_carbs.dart`, advisory-only. Delivery:
Tonight card after ~20:30 + the existing `overnightLowRisk` notification category
(replace the cruder heuristic). **Self-grading:** log tier + actual overnight
minimum, reconcile next morning, show hit/miss on the accuracy screen. Tests:
tiering on synthetic evenings, reconciliation, card integration test.

**1.5 Exercise-aware forecasting (M).**
`HealthFeatureSampler` gains `aerobic_tail = Σ intensity·0.5^(hrsSince/12)`
(clamp [0,1.5]) and a 4 h `resistance_flag` (anaerobic can *raise* BG), typed via
`WorkoutClassifier` on sample meta. Feature version → 5. Zeros-for-missing
contract holds. Independent of learning: exercise mode active → scale the hypo
side of the band ×~1.3 (physiology first). Order: after P0-2 and 1.8. Tests:
half-life decay, version bump, GBM-recovery test with post-exercise drops.

**1.6 Population-prior warm start (L).**
Train per-horizon priors offline on ~100 simulator variants (`dev/sim_data.dart`,
varied dawn/overshoot params via a `tools/` script) against the *same* baseline +
feature layout; ship `assets/models/residual_prior_v<ver>.json` (assert version
inside the asset; refuse on mismatch; regenerate on every feature bump).
`BlendedResidualModel`: `residual=(1−w)·prior+w·personal`,
`sigma=max(prior,personal)` (never narrower while blending),
`w=(personalSamples/600).clamp(0,1)`. Store returns blend; `Forecaster` untouched.
The promotion gate's incumbent becomes the blend — exactly right. Advanced screen
shows "prior / blended (w=0.4) / personal". Tests: blend math, asset version
refusal, cold-start integration check.

**1.7 Short-horizon forecast for alerting (S–M).**
Add a 15-min horizon (pipeline is horizon-keyed end-to-end; filter it out of the
Predict/Today UIs). Alert rule in `AlertMonitor`: fire when the 15-min **lower
band edge** crosses the low threshold, lead-time setting (10/15/20 min via
interpolation), re-alert suppression until recovery. Trustworthy only after
1.1/1.2. Pair with retention (§4-3) — 15-min rows quadruple reconciliation volume.

**1.8 Robust ROC + CGM noise handling (S) — do first in Phase 5.**
`robustRocMgdlPerMin`: recency-weighted LS slope over 15 min (≥3 points; fallback
2-point). Use in *both* live state assembly and `ForecasterTrainer` (train/serve
symmetry). Sensor-age awareness: first 24 h of a sensor → training weight ×~0.5
(via a synthetic low-confidence context annotation — no new plumbing) and live
band ×1.15. Bump feature version (semantics changed). Also fixes P2-7's leak
sibling: use a *trailing* resting-HR baseline while in the file.

**1.9 Per-meal absorption learning (M).**
`MealOutcomeService` already stores per-meal outcomes. Fit
`absorptionMinutes ≈ clamp(2·timeToBaseline − preBolus, 90, 360)`, median of ≥3
outcomes, stored on the `SavedMeal`. Logging that meal stamps
`CarbEntry.absorptionMinutes`; `CarbModel` already honours per-entry absorption so
predictor/COB/Autotune all pick it up free. Meal sheet shows "your absorption ≈
4.5 h (6 meals)"; FPU coach skips its extension when learned duration already
exceeds it. Tests: fit recovery, persistence round-trip, differing COB tails.

**1.10 Walk-forward validation + model history (M)** — completes P2-2, hosts P2-4.
K=3–4 contiguous blocked folds with a purge gap of `maxHorizon` (the ±6 min label
slop makes the gap mandatory); pooled fold metrics gate promotion; final model
retrains on everything; <~10 days falls back to the single split. Persist
`foldRmses` in the `ModelRuns` metrics JSON. While in there: validation-chosen
`nEstimators` (early stopping — P2-4). **Rollback:** store the last ~5 promoted
model blobs; Advanced screen "Model history" list with restore (refuses on feature
version mismatch). Tests: purge-gap leakage assert, pooled gate, restore round-trip.

### §4-2 Alert & insight surfaces consuming forecasts

- **Band trust meter on Predict** (S, needs 1.1/1.2): rolling 7-day coverage chip
  ("band caught 9/10 this week") from the reconciliation query that already runs.
- **Daily hypo-risk score** (S): LBGI vs 14-day baseline in the morning summary
  with one reason string.
- **Per-time-of-day alert thresholds** (M): small per-segment table
  (overnight/day/post-meal) in `AlertThresholds`; migration = existing values
  become the all-day row.
- **"Why this forecast" decomposition** (S–M): advanced-mode sheet per horizon —
  baseline Δ from insulin/carbs/momentum (three zeroed simulations, cheap) +
  residual value + band source. Presentation only.
- **Exercise-aware / dynamic ISF in the advisor** (M, 🔒): wire the sensitivity
  multiplier + exercise tail into the correction ISF (bounded, shown in the
  working) — the advisor currently ignores signals the app already computes.

### §4-3 Data foundation (enablers)

- **Nightscout follower mode** (M): add `fetchEntries/fetchTreatments(since)` to
  `NightscoutClient`; pull loop in jobs behind a source-mode setting; merge through
  the backfill dedupe path keyed on NS `_id`; source priority (pump > NS) with
  per-sample provenance so dual-live never double-ingests.
- **Retention & pruning** (S–M): startup prune — predictions > 90 d, health
  samples > 180 d; keep CGM/treatments (training corpus). Repository
  `pruneBefore` + tests. Prerequisite-ish for 1.7.
- **Fingerstick↔CGM merge** (M): the P1-2 schema work, plus heuristic calibration
  matching (±15 min, ±20% → user-confirmable via Confirm events) and distinct
  chart glyphs.
- **Libre / Dexcom-share ingestion** (M–L): new source adapters reusing the
  follower-mode provenance/dedupe pattern — after it exists.

### §4-4 Beyond forecasting

- **4.1 Free-text meal → macros** (M, 🧠): new `buildMealEstimatePrompt` (dish list
  → itemised JSON) on the same Gemma runtime, greedy decoding, 45 s timeout,
  close-after-use; **shares §5's validation/grounding layer** (items 1–3 are
  prerequisites). Entry: text field on Meals/advisor, always editable, labelled
  estimate; no-model fallback = AFCD name search. Degrades, never blocks.
- **4.2 Ask-your-data Q&A** (L, 🧠): retrieval over *computed* facts (narratives,
  reports, metrics, events) selected by keyword/date parsing; LLM only phrases and
  must cite which fact backs each claim (reject otherwise). Fixed question
  taxonomy first.
- **4.3 Mood ↔ glucose correlation** (S): weekly Spearman of mood tags vs same-day
  TIR/CV, ≥8 tagged days, show only significant results; if nothing after 8 weeks,
  explicitly show nothing (resolves item 2-6).
- **4.4 Clinic-visit prep** (S–M, 🧠 optional): template-based plain-language
  summary + auto-questions from report models; LLM optional phrasing; existing PDF
  pipeline.
- **4.5 Weekly digest** (S): second WorkManager task beside the morning summary;
  TIR/GMI/hypo deltas + one learned insight from the TOD profile.

---

## §5. Panel-scanner LLM plan (🧠 — pairs with item 2-1)

Ordered by safety value; items 1–3 are pure Dart and land before any hardware
session; 4 lands before on-device accuracy measurement; 5–6 fold into the 2-1
hardware session.

1. **Validate the LLM's numbers** (highest priority — dosing safety). In the
   parser, not the prompt: hard bounds (macros 0–100 g/100 g, sodium ≤5000 mg,
   energy ≤4000 kJ/100 g, serving 1–1000 g, servings/pack 1–100 — out-of-range →
   null); cross-field checks (sugars ≤ carbs; per-serve ≈ per-100g×serving/100
   within ~25%, else keep per-100g + serving and null per-serve); keep the
   all-macros-empty rejection.
2. **OCR-grounding check** (anti-hallucination + injection guard): accept an LLM
   value only if the number literally appears in the OCR text (± comma/rounding).
   Post-parse filter in `PanelScanService` so it applies to any model.
3. **Fix the confidence comparison**: completeness-scored confidence lets a
   hallucinating model (carbs+protein+fat invented) beat an honest partial parse
   at 0.9. After (2), LLM confidence counts *grounded* fields only. Also fix the
   LLM-gate quirk (P2-11): today the LLM never runs when the parser found *any*
   carb value, however garbled.
4. **Few-shot prompt + on-device self-check**: two exemplars (AU/EU two-column,
   US single-column) in `buildPanelPrompt`; "test the model" button on the AI
   screen (canned text → LLM → JSON, pass/fail); then run the on-device accuracy
   integration test with the LLM enabled and record numbers.
5. **Model integrity & resource gating**: URL + SHA-256 stored and verified
   (with P1-9's host/HTTPS rules); free-space check before download, RAM check
   before load (silent-null failure today); reconcile the 0.5 GB vs 1.5 GB claims
   by measuring on the Pixel 7 Pro.
6. **OCR script support (scope decision)**: Latin-only OCR means CJK labels feed
   the LLM garbage. Either add script detection + ML Kit recognizers, or scope the
   copy honestly to Latin-script labels. Decide from real usage during 2-1.
7. **Deterministic column reconstruction** (from the review): use ML Kit's
   block/line geometry (currently discarded) to rebuild per-serve/per-100g columns
   before parsing — fixes most merged-column cases without the LLM. Plus parser
   quirks: exclude %DV tokens, split kJ/kcal, capture EU "Salt … g", ml servings.
8. **Longer-term**: LoRA fine-tune of Gemma (flutter_gemma supports LoRA in
   `installModel`) on synthetic panels generated from the
   `test/data/nutrition_panels.json` corpus; consider Gemma 3 270M fine-tuned.

---

## §6. Remaining polish & infrastructure

- **Prediction validation on real data** (M): run the accuracy screen against real
  history once the pump link is live; tune momentum/IOB/COB params. (Phase 4/5.)
- **Alert quality pass** (M, 🔒): snooze/ack semantics, smarter dedup,
  do-not-alert-during-exercise nuances — around §4-2's threshold work.
- **Data integrity edges** (M): CGM gap handling, warm-up/compression robustness,
  timezone/DST across history, meter clock drift (`PumpSnapshot.fromJson` falls
  back to `DateTime.now()` with no skew detection).
- **Reliability** (M, 🔌): foreground-service survival, battery, reconnect after
  sleep, crash-free long runs. (With Phase 4's pump work.)
- **First-run polish for real hardware** (S–M, 🔌): pairing UX, permission flows,
  Health Connect setup, "no data yet" states.
- **Git remote + push** (S): CI + GitHub Pages workflows exist but nothing is
  pushed.
- **Golden/screenshot tests** (M): catch UI regressions; the screenshot harness
  exists.
- **Release path** (M, 🔌): signing, Play internal track vs sideload-only.
- **User-guide privacy note** (S): BG/IOB transit the Garmin Connect app (may sync
  to Garmin's cloud per its policy).

---

## Open questions

1. **What's the #1 goal right now** — rock-solid daily driver on real hardware
   (Phases 0–4 as written), or pull forward the forecasting features (Phase 5)?
2. **How often is hardware time available?** Sets the cadence of the Phase 4
   track.
3. **Which LLM feature after the scanner** — free-text meal→carbs (§4-4.1) is the
   staff pick; Q&A / NL quick-log / explanations remain candidates.
4. **Dream features not listed?** (voice, specific integrations, particular
   reports, automation…)

_Answered previously: audience = personal (Summer); neural forecaster = no,
committed to the GBM._

---

_Maintenance: this is the only planning doc. When work lands, update the status
here (tables + snapshot) in the same commit. User-visible changes also update
`doc/user-guide.html` + an integration test, per `CLAUDE.md`._
