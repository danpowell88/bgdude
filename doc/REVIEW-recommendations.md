# bgdude — Engineering & Clinical Review: Recommendations, Fixes & Feature Ideas

_Prepared 2026-07-06. A full read-across of the codebase (160 Dart files ≈ 33k lines, plus
native Android/Kotlin and Garmin Monkey C), reviewed from four angles: clinical/physiological
correctness, the ML/forecasting layer, software architecture & data integrity, and the
food-scanning / on-device-LLM / native (pump + Garmin) layers._

**Charter reminder (this review respects it):** bgdude is a personal, **read-only** Tandem
t:slim X2 companion. It never delivers insulin. Every number is advisory and user-confirmed.
So "safety-relevant" here means *"a wrong number the user might act on with their own pump,"*
not regulatory.

---

## 0. Headline

The engineering fundamentals are genuinely strong for a solo app: a clean device/data/
analytics/UI layering, pure and constructor-injected analytics, 64 unit-test files, and — importantly
— the read-only pump discipline is enforced *by construction* in native code (no `request.control`
imports, `enableActionsAffectingInsulinDelivery` never called). The CGM-metric math (GMI, GRI,
LBGI/HBGI, TIR, CV) and the exponential IOB / bilinear COB curves are correct and faithfully cited.

But the review surfaced **one root modeling error that dominates everything else**, plus two
serious integrity/security gaps. Fix these three first; the rest is polish.

### The three things to fix before this is trusted with real therapy data

1. **Basal insulin is modeled as un-opposed glucose-lowering force (no EGP term).** This single
   choice is wrong in two independent places and both were flagged independently:
   - *Dosing:* the bolus advisor subtracts **total** IOB (bolus + integrated basal) from a
     correction, which cancels corrections to ~0 — systematic **under-dosing of highs**.
   - *Learning:* the forecaster/Autotune/sensitivity stack counts gross basal as a downward
     pull with nothing pushing back, so a **perfectly-tuned user is scored as maximally
     insulin-resistant**, poisoning every learned label (sensitivity, time-of-day, basal
     recommendations, unannounced-meal carb estimates).
   Root cause and fix are the same idea (model insulin effect from *net* insulin — boluses plus
   basal *deviation from schedule* — treating scheduled basal as EGP-neutral). This is the
   single highest-ROI change in the codebase.

2. **At-rest encryption is currently ineffective.** The SQLCipher passphrase is stored in
   **plaintext SharedPreferences**, sitting next to the ciphertext — while code comments and the
   README claim it lives in the platform Keystore via `flutter_secure_storage` (which isn't even a
   dependency). For a health-data app this is the #1 security fix.

3. **Insulin/carb events can duplicate, and fingersticks corrupt the CGM series.** No dedupe on
   bolus/carb/basal inserts (a restart race + backfill-vs-live overlap creates duplicate rows that
   inflate IOB and TDD used for dosing advice), and meter readings are persisted as
   indistinguishable-from-sensor CGM — a `time`-collision can even *overwrite* a real sensor
   reading.

---

## 1. Priority-ranked fix list

Effort: **S** ≤ ½ day · **M** 1–2 days · **L** 3+ days.

### P0 — safety-relevant correctness (do first)

| # | Fix | Where | Effort |
|---|-----|-------|--------|
| P0-1 | **Correction subtracts bolus-only (or net) IOB, not total incl. basal.** Use `_iob.fromBoluses(...)` for the correction subtraction; keep full IOB only for the forward prediction. | `lib/analytics/bolus_advisor.dart:191,293-294` | S |
| P0-2 | **Predictor: model insulin effect from net insulin (boluses + delivered−scheduled basal), or add an EGP term.** Pass the scheduled profile into the IOB/predict path so scheduled basal nets to zero. Re-tune constants + tests after. | `lib/analytics/predictor.dart:290-291`, `lib/analytics/insulin_math.dart:107-145` | M |
| P0-3 | **Autotune & time-of-day sensitivity: compare like-for-like after P0-2.** A well-tuned fasting user must score ≈1.0, not 1.5. Flows into `SensitivityModel`, `TimeOfDaySensitivityAnalyzer`, `BasalRecommender`. | `lib/ml/autotune.dart:82-104`, `lib/ml/time_of_day_sensitivity.dart:147-149` | M (mostly falls out of P0-2) |
| P0-4 | **Advisor/predictor must honour the user's configured DIA & insulin peak.** Build the `IobCalculator` from `TherapySettings.durationOfInsulinActionMinutes`/`insulinPeakMinutes` instead of the hard-coded 360/75. The care detectors already do this — the advisor and predictor don't, so they disagree. | `bolus_advisor.dart:102-103`, `predictor.dart:177-178` | S |
| P0-5 | **Rescue-carb calc: enforce/document bolus-only IOB** so `iobDrop = iob·ISF` doesn't include ~2 U of phantom basal and over-treat lows. | `lib/analytics/rescue_carbs.dart:56` | S |
| P0-6 | **Advisor: hard low-guard on the *current* reading + compression-low exclusion.** If `currentMgdl < low`, refuse corrections and add a "treat the low first, dose meal insulin after eating" note (the pre-bolus coach has this; the advisor doesn't). | `bolus_advisor.dart:183` | S |
| P0-7 | **Ketone/DKA prompt is late.** Lower base threshold to 250 mg/dL (13.9 mmol/L) and add an *unconditional* prompt for BG > ~300 mg/dL with a rising trend or very-low IOB, independent of the 2 h-sustained + co-factor gate. (ADA Standards of Care / ISPAD sick-day.) | `lib/insights/ketone_risk.dart:21` | S |

### P1 — data integrity, security, reliability

| # | Fix | Where | Effort |
|---|-----|-------|--------|
| P1-1 | **Move the DB passphrase to `flutter_secure_storage` (Keystore)**; migrate from the prefs key; **await** the write; correct the false comments in code + README. | `lib/data/secure_key.dart:8-28`, `database.dart:187`, `main.dart` | S |
| P1-2 | **Add `isCalibration`/`source` to `CgmReadings` (schema v3)**; persist & read the flag; stop fingersticks overwriting sensor rows (uniqueness on `(time, source)` or skip-on-conflict for calibrations); exclude calibrations from metrics/training. | `database.dart:23-36`, `history_repository.dart:98-136`, `glucose_meter.dart:42-44` | M |
| P1-3 | **Dedupe bolus/carb/basal.** Unique index on `(time, units)` or a source/event-id + upsert; reconcile backfill vs live-ingested rows; fix the `_lastBolusTime` restart race by checking the DB before insert. | `database.dart:38-64`, `history_repository.dart:139-198`, `day_history_controller.dart:110-144`, `pump/history_backfill.dart` | M |
| P1-4 | **Native EventChannel sink is called off the platform thread.** Marshal every `eventSink.success(...)` to `Handler(Looper.getMainLooper()).post{…}` — BLE callbacks arrive on a background thread and Flutter's sink is `@UiThread`; the first real pump connection will otherwise throw and kill the stream. | `android/.../PumpBridge.kt:128-155` | S |
| P1-5 | **BootReceiver can crash after reboot and never reconnects anyway.** Gate on `hasBluetoothPermission` before `startForegroundService`; add auto-reconnect (`commHandler.start(savedMac)`) so a boot restart actually resumes. | `android/.../BootReceiver.kt:16-18`, `PumpService.kt:63-75` | S–M |
| P1-6 | **Surface DB-open failure** (banner + log) instead of silently swapping to `InMemoryHistoryRepository` — today a corrupt DB / lost key silently stops persisting health data. | `main.dart:26-34` | S |
| P1-7 | **Alerts stop when the Flutter engine dies.** All alerting runs off a `ref.listen` in the widget tree; only the morning summary has a WorkManager backstop. Drive alert evaluation from the native foreground service (or a low-glucose WorkManager backstop), and document the limitation in the user guide. | `lib/app.dart:19-31`, native | L |
| P1-8 | **Replace silent `catch (_)`** (58 occurrences) with logged catches, especially `AppJobs.runStartup` and every notification path; don't advance `_lastFired` on a *failed* urgent-low notification. | `lib/state/providers.dart` throughout | S |
| P1-9 | **Model-download security:** reject HTTP, only send the HF token to `huggingface.co`/`kaggle*` hosts, verify a SHA-256 after download, and don't echo the URL/token into a snackbar. | `lib/food/panel_model_manager.dart:29-40`, `lib/ui/ai_model_screen.dart:50` | S–M |

### P2 — robustness, honesty of the ML, cleanups

| # | Fix | Where | Effort |
|---|-----|-------|--------|
| P2-1 | **Prediction interval is over-confident & symmetric.** Compute sigma on the **held-out tail** (already computed, just unused), correct for **bias** (mean error) separately, and add empirical **coverage** to the accuracy screen. Prefer quantile intervals at the hypo end. | `lib/ml/residual_gbm_model.dart:117-119`, `forecaster.dart:97-98`, `accuracy_report.dart`, `uncertainty_calibrator.dart:44` | M |
| P2-2 | **Validation methodology.** Replace the single autocorrelated time-split with blocked/purged CV + embargo (drop the horizon-width straddling the split). Applies to forecaster & sensitivity model. | `forecaster_training.dart:78-81` | M |
| P2-3 | **Guard the promotion gate against empty-hypo tails** — `hypoSensitivity = 0/0 = 0` currently makes the residual model *never* promote for well-controlled users. Skip the hypo criterion when the tail has no reference lows. | `lib/ml/model_registry.dart:62-68`, `error_grid.dart:108-110` | S |
| P2-4 | **Regularize/early-stop the GBM** (validation-chosen `nEstimators`, weighted leaf counts, optional seeded subsampling, L2 leaf shrinkage) — 50 trees × depth 3 on ~150 points overfits. | `lib/ml/gbm.dart:101-107,289` | M |
| P2-5 | **Sensitivity model has no validation and confidence = calendar time.** Add leave-one-day-out CV; only adopt the learned model if it beats the transparent heuristic; make confidence reflect out-of-sample error, not days elapsed. Consider sign-constrained coefficients so a noisy 21-day fit can't invert a physiological direction. | `lib/ml/sensitivity_model.dart:139-160` | M |
| P2-6 | **Dead sensitivity feature** pinned to constant 1.0 in both train & serve — either feed the real effective context or drop it. | `lib/ml/forecast_features.dart:89`, `forecaster_training.dart:115` | S |
| P2-7 | **Health-feature look-ahead leak** — resting-HR baseline is the median over the whole (future-inclusive) window at training time. Use a trailing baseline. Also make `_activityAt` a binary search (currently O(n²) over the training walk). | `lib/ml/health_features.dart:32-33,98-106` | S–M |
| P2-8 | **Garmin: delta is always ~0 and unit is hardcoded mmol.** Compute delta from consecutive distinct `cgmTimestampEpochMs` and only advance `lastBg` on an actual send; plumb the display-unit setting through instead of `"mmol"`. | `android/.../GarminIntegration.kt:31-44` | S |
| P2-9 | **Report providers use `ref.read` for the repository** so toggling demo mode doesn't rebuild them; make them `ref.watch`. Re-scan `pendingConfirmationsProvider` on new CGM data. | `lib/state/providers.dart:665-831` | S |
| P2-10 | **Validate the Clarke error grid against reference vectors** (or switch to Parkes/consensus) — it's an approximation of the 1987 polygons and it *gates model promotion*. | `lib/ml/error_grid.dart:45-74` | M |
| P2-11 | **Nutrition-panel parser & LLM-gate quirks** — see §7; exclude `%`-tokens, split kJ/kcal, capture EU "Salt … g", handle ml servings, and cross-check every extracted number against the OCR text before trusting it (carbs feed bolus advice). | `lib/food/nutrition_panel_parser.dart`, `panel_scan_service.dart:44-52` | M |
| P2-12 | **Split `providers.dart` (2,208-line god file)** into ~5 modules and extract a `PersistedStateNotifier<T>` base to kill ~12 copies of restore/save boilerplate and its constructor race. | `lib/state/providers.dart` | L |

---

## 2. Detailed findings by subsystem

### A. Clinical / dosing math (`lib/analytics`, `lib/meals`, `lib/insights`)

**What's right:** exponential IOB model exactly matches LoopKit `ExponentialInsulinModel`
(`insulin_math.dart:43-51`); bilinear COB is area-normalised and continuous; the FPU/Warsaw
implementation is faithful (`FPU = (fat·9 + protein·4)/100`, 1 FPU ≈ 10 g carb-equiv, extend ≈
FPU+2 h); GMI/GRI/LBGI/HBGI/TIR/CV formulas are correct and cited; **no mg/dL↔mmol/L conversion
errors** anywhere (everything stored mg/dL, converted only at the display boundary). The safety
scaffolding — negative-correction→0, max-bolus cap, predicted-low attenuation, Control-IQ
auto-correct halving to prevent stacking, CGM-noisy refusal, rescue 15-15 floor + 45 g cap — is
thoughtfully built.

**The defects are in the IOB *inputs*, not the guard logic:**
- **Basal IOB subtracted from corrections (P0-1)** — headline. Under the exponential model,
  steady-state basal IOB for ~0.8 U/h ≈ 1.7–2.5 U, comparable to or larger than a typical
  correction, so `correctionUnits = rawCorrection − totalIOB` collapses to ~0. Every commercial
  calculator (Tandem included) subtracts **bolus IOB only** — basal maintains background needs and
  its effect is already reflected in the current BG, so subtracting it double-counts.
- **DIA/peak ignored (P0-4)**, **no current-low guard (P0-6)**, **rescue over-treatment (P0-5)**,
  **late ketone prompt (P0-7)** — all above.
- **Meal IOB also subtracted from corrections** (`_iobNow` sums all boluses) — the classic
  simple-calculator limitation; combined with P0-1 it amplifies under-dosing. Ideally net
  un-absorbed COB against meal IOB (M).
- **Symmetric carb triangle peaks at td/2** (90 min) — real mixed-meal absorption peaks earlier
  (~45–60 min). Front-load the triangle (peak ≈ td/3) or adopt Loop's piecewise model; keep
  area-normalisation (M). The file's doc comment overstates "Loop-style" fidelity.
- Minor: GMI formula duplicated in `metrics.dart:72` and `a1c_goal.dart:138`; `_baseConfidence`
  mislabels a neutral context as "high"; `FatProteinLevel.high = 3.5 FPU` underestimates a large
  pizza (5–7 FPU).

**Good additions to consider:** exercise-adjusted ISF in the advisor (you already model an 8 h
aerobic sensitivity tail but don't lower correction ISF during/after exercise); dynamic ISF
(AndroidAPS-style, scaled by BG/TDD); trend/ROC-aware corrections (Dexcom trend is in `samples.dart`
but the advisor ignores it); net-basal IOB so Control-IQ suspensions correctly *raise* effective IOB.

### B. ML / forecasting (`lib/ml`, `lib/analytics/predictor.dart`)

**Architecture:** forecast = deterministic baseline + learned GBM residual at {30, 60, 120} min,
with graceful cold-start (`NoResidualModel` → pure baseline + widening band) and a feature-layout
version key that discards stale models. Sound shape.

**The dominant issue is C1/P0-2 (basal-as-un-opposed-insulin)**, which poisons the *labels*:
`residual = actual − baseline` inherits the baseline's downward drift; Autotune's `ratio =
observed/modelled ≈ 0/negative ≈ 0` → `mult → 1.5` (max resistance) for a well-tuned user; that
flows into the sensitivity model, time-of-day profile, basal recommender, and unannounced-meal carb
estimates. **Fix P0-2 before touching anything else in this layer — most of the rest falls out of it.**

Independent-of-C1 issues, in priority order: over-confident in-sample sigma (P2-1); single
autocorrelated time-split gate (P2-2); empty-hypo-tail makes the model never promote (P2-3);
un-regularized GBM overfits (P2-4); sensitivity model has no validation and confidence = calendar
time, unconstrained coefficients can flip a physiological sign (P2-5); dead constant feature (P2-6);
health-feature look-ahead leak + O(n²) sampling (P2-7); Clarke grid approximate yet gates promotion
(P2-10). Also: triple confidence-shrinkage (Autotune day-damp × training weight × effectiveMultiplier
blend) buries the sensitivity signal — encode confidence in one place; ±6 min label-match allows
look-ahead slop; single-step ROC is very noisy (use a ~15 min regression slope); the `ModelRegistry`
versioning/rollback story is aspirational — the live forecaster reimplements its own promote logic
and "latest promoted JSON wins" with no real rollback.

**High-value additions:** population prior / warm-start so cold-start isn't "deterministic-only for
weeks"; quantile GBM for honest asymmetric intervals at the hypo end; report **coverage + bias**
(not just RMSE) on the accuracy screen; exclude `MealDetector` windows from Autotune so unannounced
meals stop contaminating the carb-free sensitivity estimate.

**On the neural (LiteRT) forecaster (ROADMAP 1.5):** don't build it yet. The GBM residual isn't the
bottleneck — the *labels* are (C1). Fix the baseline, get honest validation (coverage/bias, purged
CV) in place, and only then decide whether a neural residual beats a well-regularized GBM on your
real history. Until then, either commit to the GBM and delete the aspirational
`residual_model_litert.dart` comments, or keep them as an explicit backlog note.

### C. Data integrity & persistence (`lib/data`, `lib/pump`, `lib/state`)

The three integrity gaps (P1-2 fingersticks, P1-3 event dedupe, P1-1 encryption) are covered above.
Additional:
- **No retention/pruning** — `Predictions`, `CgmReadings`, `HealthSamples` grow unboundedly (M).
- **Prediction reconciliation is N+1** (one `cgmBetween` per pending row) and runs at startup +
  inside `modelReportProvider` — batch it (M).
- **DB migrations are untested** (`schemaVersion = 2`, minimal `onUpgrade`, no `drift_dev`
  snapshots). Adopt Drift schema-export + step migration tests *now*, before schema v3 lands for
  P1-2/P1-3 (M).
- **Background isolate opens a 2nd SQLCipher connection** to the same file — Drift warns about
  multi-isolate access; share one connection or serialize. The background morning summary also
  ignores the `morning_summary_shown` key → possible duplicate briefings (M).
- **Meter/pump clock drift** acknowledged but not corrected; `PumpSnapshot.fromJson` falls back to
  `DateTime.now()` on a missing timestamp with no skew detection.
- **Constructor `_restore()` race** repeated ~15×: an unawaited async restore in every notifier
  constructor; a `save()` racing an in-flight restore gets clobbered, and early readers see
  placeholder values. The `PersistedStateNotifier<T>` base (P2-12) fixes this by queuing saves
  behind restore.

### D. Architecture & code quality (`lib/state`, `lib/ui`, `lib/feedback`)

Middle/bottom layers are well-designed (clean `PumpSource` / `HistoryRepository` seams, pure
constructor-injected analytics, strong unit-test discipline). The weak point is the top:
`providers.dart` is a **2,208-line god file** holding ~40 providers plus `AlertService` (~350 lines)
and `AppJobs` (~500 lines), both taking a raw `Ref` — the de-facto app layer, hard to test and
navigate (P2-12). `app.dart` doing persistence + alerting + Nightscout inside a widget `build`
listener is an orchestration smell. Global statics (`KvStore`, `ConfirmationDecisionStore`,
`BatteryHistoryStore`, `MealLogStore`) bypass Riverpod, which is why demo mode's "never touch real
data" guarantee only holds for the repository, not for KV-backed state. Dead deps
(`riverpod_annotation`, `freezed`, `json_serializable`) declared but unused; `NightscoutClient.
uploadTreatments` never called (boluses/carbs never reach Nightscout despite the docstring);
`DayHistoryController._basalObs` grows unbounded within a session.

### E. Native Android (pump) & Garmin

**Pump path is convincingly read-only** — worth adding a unit test / lint that *fails the build if
`request.control` is ever imported*, making the guarantee mechanical rather than conventional.
Priority native bugs: off-thread EventChannel sink (P1-4), BootReceiver crash + no-reconnect (P1-5),
`PumpClient._onEvent` can throw an unhandled zone error on a malformed snapshot decode (wrap in
try/catch, S). Medium: `requestStatusJson` returns the *previous* snapshot (name says otherwise);
`fetchHistory` ignores the requested range (rescued by the Dart high-water mark); `MutableSnapshot`
read/written across BLE + binder threads without synchronization (copy-under-lock before `toJson()`).

**Garmin:** delta always ~0 + hardcoded mmol unit (P2-8); watch-face/data-field silently show no
data on devices lacking `registerForPhoneAppMessageEvent` (raise `minApiLevel` or prune products, S);
product lists (35 devices, identical across 3 manifests) omit the current generation (fenix 8, FR
165/970, vivoactive 6 — S). **The complication (ROADMAP 1.3) is the highest-leverage Garmin item:**
implement exactly what `garmin/COMPLICATIONS.md` prescribes (resource-defined complication +
`ComplicationPublisher` + `Complications.updateComplication`, gated by `Toybox has :Complications`)
to expose BG to every native/third-party face (M, needs on-device verification).

### F. Food / OCR / on-device LLM

The Dart pipeline is well-layered (interface-separated, host-testable prompt/parse, sensible
fallback ordering) and the on-device privacy claims hold (ML Kit OCR + Gemma inference are local;
photos never leave the device). Model download is the security weak point (P1-9). Correctness gaps:
the LLM never runs when the parser found *any* carb value however garbled (`confidence ≥ 0.6` gate),
so a confidently-wrong carb can suppress the very fallback meant to catch it (P2-11); parser accepts
unit-less `%DV` numbers as grams, mixes kJ/kcal into one nutrient's two columns, never captures EU
"Salt … g", and drops ml serving sizes; **the LLM's numbers aren't cross-checked against the OCR
text** — a cheap "does this number literally appear in the source?" check would catch most
hallucinations before a carb value reaches the bolus advisor. Also: no disk/RAM gate before pulling
~0.5 GB and loading it on CPU (low-RAM devices OOM at scan time, then silently fall back — the user
paid 0.5 GB for a feature that never fires); ML Kit's structured line/column geometry is discarded
before the "multi-language LLM fallback," and OCR is Latin-only so CJK labels are garbage the LLM
can't repair.

**Highest-value food additions:** deterministic column reconstruction from ML Kit's block/line
geometry (fixes most "columns merged" cases without the LLM); a cross-validation post-processor
(every number occurs in the OCR text; sugars ≤ carbs; per-serve ≈ per-100g × serving/100); a LoRA
fine-tune of Gemma on synthetic panels generated from the existing `test/data/nutrition_panels.json`
fixture corpus (flutter_gemma already supports LoRA in `installModel`); and eventually the ROADMAP
3A free-text meal→carbs (natural entry alongside scan/search).

### G. Security & privacy summary

Fix order: (1) plaintext DB key (P1-1) — the whole at-rest-encryption story is currently theater;
(2) model-download token/HTTP/integrity (P1-9); (3) Nightscout `apiSecret` is plaintext in KV
(acceptable *after* P1-1). `toString()` correctly redacts the secret. Prompt injection via OCR text
is bounded (schema-parsed, macro-gated, user-confirmed) — worth a comment. Add a user-guide privacy
line noting BG/IOB transit the Garmin Connect app (which may sync to Garmin's cloud per its policy).

---

## 3. Testing & validation recommendations

- **Add `DriftHistoryRepository` tests against an in-memory `NativeDatabase`** — upsert semantics,
  `reconcilePredictions`, and (once P1-2/P1-3 land) dedupe/calibration separation. Integration tests
  currently run demo-mode only, so the real Drift/SQLCipher path is untested.
- **`DayHistoryController.ingestSnapshot`** restart/dedupe test would have caught the duplicate-bolus
  race; **fingerstick-vs-sensor separation** test would have caught the `isCalibration` loss.
- **ML honesty metrics as first-class:** report interval **coverage** and **bias** (not just RMSE),
  and adopt purged/blocked CV. Validate the Clarke grid against published test vectors.
- **A build-failing check that `request.control` is never imported** in native code — turn the
  read-only guarantee into a test.
- Add Drift schema-export + migration tests before schema v3.

---

## 4. Valuable new features / changes (beyond fixes)

Ranked roughly by value-to-effort, respecting the read-only/on-device charter:

1. **Garmin complication publisher** (M) — exposes BG to any watch face; the single biggest wearable win.
2. **Nutrition-scan cross-validation + geometry-aware OCR** (M) — materially raises the trust of the
   one number that feeds bolus advice.
3. **Honest, asymmetric prediction intervals with coverage reporting** (M) — quantile residuals at
   the hypo end; makes the Predict screen trustworthy rather than merely plausible.
4. **Population-prior warm-start for the forecaster** (L) — "reasonable from day one" instead of
   deterministic-only for weeks.
5. **Free-text meal → carbs/fat/protein** (M, ROADMAP 3A) — reuse the on-device LLM; prefill the
   advisor. High daily value once the scan cross-check infrastructure exists.
6. **Exercise-aware & dynamic ISF in the advisor** (M) — safer corrections around workouts and at
   BG extremes; you already have the sensitivity tail and multiplier, just not wired into ISF.
7. **Ask-your-data Q&A grounded in computed metrics/reports** (L, ROADMAP 3A) — "why was I high last
   night?" on-device retrieval.
8. **Make mood logging *do* something** (S, ROADMAP 1.7) — feed the sensitivity context or surface a
   mood↔glucose correlation, or explicitly keep it journal-only in the guide.
9. **Clinic-visit prep** (S–M) — reports → plain-language summary + "questions for your endo."

---

## 5. Suggested execution order

1. **P0-2 (net-basal/EGP baseline)** — the root fix; unblocks honest ML and correct sensitivity.
   Do it with the re-tune + tests, and verify a fasting demo user now scores ≈1.0.
2. **P0-1, P0-4, P0-5, P0-6, P0-7** — the localized dosing-math fixes (all S, mostly independent).
3. **P1-1 (encryption)** — small, high-severity, unblocks trusting the DB.
4. **P1-2 + P1-3 (schema v3: calibration flag + dedupe)** with migration tests — the integrity pass.
5. **P1-4 + P1-5 (native thread + boot)** — cheap and *must* precede any real-pump testing (they'll
   crash on first hardware connection otherwise). Aligns with ROADMAP §1.6 / §1.4.
6. **P2-1 → P2-3 (ML honesty + promotion-gate guard)** — makes the Predict/Accuracy screens truthful
   and lets the residual model actually promote. Then revisit the neural-forecaster decision (1.5).
7. **P1-9, P2-8, P2-11, Garmin complication** — the food-scan security + Garmin polish, alongside
   ROADMAP §1.1–1.3 hardware verification.
8. **P2-12 (split providers.dart)** and remaining cleanups — opportunistically.

---

_This document is a review artifact, not user-facing; no `doc/user-guide.html` update is required.
When any of these fixes lands as a user-visible change, update the user guide per project convention._
