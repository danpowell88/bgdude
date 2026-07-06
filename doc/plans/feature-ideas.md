# High-value feature ideas — forecasting first (with implementation notes)

_Drafted 2026-07-06, expanded with per-item implementation detail. A curated backlog
ranked by expected value for a single-user, read-only, on-device companion.
Forecasting is the deepest section because it's the engine everything else (alerts,
advisor context, insights) draws from. Fix-type work lives in
[../REVIEW-recommendations.md](../REVIEW-recommendations.md); deferred panel-LLM work
lives in [panel-llm.md](panel-llm.md); this doc is *new capability* ideas.
Effort: S ≤ ½ day · M 1–2 days · L 3+ days._

**One prerequisite dominates:** the net-basal/EGP baseline fix (REVIEW P0-2). Until
the deterministic baseline (`lib/analytics/predictor.dart`) stops treating basal as
an un-opposed glucose-lowering force, residual labels, Autotune labels and the
sensitivity stack all inherit its drift. Everything in §1 assumes it lands first.

---

## Top 5 (if only five get built)

1. Overnight-low forecast at bedtime (§1.4) — the single highest-anxiety hour for a T1D.
2. Quantile residuals + coverage reporting (§1.1) — makes the cone *honest*, not just plausible.
3. Unannounced-meal detection wired into the live forecast (§1.3).
4. Population-prior warm start (§1.6) — useful from day one instead of week three.
5. Free-text meal → macros via the on-device LLM (§4.1) — highest daily-use value outside forecasting.

---

## 1. Forecasting core

### 1.1 Honest, asymmetric prediction intervals (M)

**What:** per-horizon quantile residual models (q10/q50/q90) so the band can be wide
toward hypo and tight toward hyper when that's what the data says, plus coverage +
signed-bias reporting so miscalibration is visible.

**Implementation:**
- **Quantile GBM.** `GbmRegressor.fit` (`lib/ml/gbm.dart`) boosts squared error, whose
  pseudo-residual is `y − pred`. Pinball loss at quantile τ has pseudo-residual
  `τ` if `y > pred` else `τ − 1`; leaf values become the *weighted τ-quantile* of
  the in-leaf residuals rather than the weighted mean. Add a `GbmLoss` enum
  (`squared`, `quantile(tau)`) to the constructor; `_bestSplit` can keep using the
  variance-reduction criterion (standard practice — LightGBM does the same), so only
  the residual computation and `_weightedMean` → `_weightedQuantile` change. Include
  `loss`/`tau` in `toJson` so persisted ensembles round-trip.
- **Model shape.** `ResidualGbmModel` (`lib/ml/residual_gbm_model.dart`) grows
  `Map<int, GbmRegressor> _lowerModels/_upperModels` beside the existing median
  models. `ResidualModel.correct` (`lib/ml/forecaster.dart`) returns
  `(residual, sigma)` today; add a richer
  `({double residual, double lowerOffset, double upperOffset})` path — either a new
  `correctQuantiles` method with a default that derives offsets from sigma
  (`±kForecastZ90·σ`) so `NoResidualModel` keeps working, or widen the record. The
  `Forecaster.forecast` loop then builds `lowerMgdl/upperMgdl` from the offsets
  instead of the symmetric `kForecastZ90 * sigma`.
- **Training.** `ResidualGbmTrainer.train` fits three ensembles per horizon on the
  same `TrainingSample`s (3× cost; ~50 trees × depth 3 × 3 horizons is still
  well under a second per quantile off the UI isolate). Note the trainer feeds
  Huber-clipped targets (`RetrainingPipeline`, `lib/feedback/retraining.dart`) —
  clip at a wider delta (e.g. 60 mg/dL) for the q10/q90 fits or the tails get
  flattened by the very mechanism that protects the median.
- **Reporting.** `AccuracyReport` (`lib/ml/accuracy_report.dart`) already scores
  reconciled `StoredPrediction`s, which persist `lowerMgdl/upperMgdl`
  (`lib/data/history_repository.dart`). Add per-horizon `coverage`
  (fraction of matured predictions with `lower ≤ actual ≤ upper`) and `meanSignedError`;
  render both on `ModelAccuracyScreen` ("90% band caught 84% · bias +6 mg/dL").
- **Gate.** Add `minCoverage`/`maxCoverageExcess` to `PromotionGate`
  (`lib/ml/model_registry.dart`) once coverage is measured, so a badly calibrated
  candidate can't ship.
- **Tests:** extend `test/gbm_test.dart` with a known asymmetric-noise dataset
  (e.g. exponential noise) asserting q10/q90 recover the analytic quantiles within
  tolerance; `test/residual_gbm_test.dart` asserts lower ≤ median ≤ upper monotonicity
  (enforce by sorting the three outputs at predict time — quantile crossing happens).

### 1.2 Conformal calibration of the live band (S–M)

**What:** distribution-free band correction using recent reconciled predictions as
the calibration set; guarantees ~target coverage regardless of model quality.

**Implementation:**
- **Where.** Extend `UncertaintyCalibrator` (`lib/ml/uncertainty_calibrator.dart`).
  Today `perHorizonRmse` feeds `recentHorizonErrorProvider` from
  `AppJobs.updateRecentForecastError` (`lib/state/providers.dart`); replace the RMSE
  map with a per-horizon *conformal scale*: for split-conformal on a symmetric score,
  collect `s_i = |actual_i − predicted_i| / halfWidth_i` over the last 14 days
  (halfWidth from the stored `lowerMgdl/upperMgdl`), then the corrected band is
  `predicted ± q̂ · halfWidth` where `q̂` = the `⌈(n+1)(1−α)⌉/n` empirical quantile
  of the scores (α = 0.10). Using the *ratio* score means the learned band shape
  (incl. §1.1 asymmetry, scored per side) is preserved and only scaled.
- **Asymmetric variant** (after §1.1): score lower and upper violations separately
  (`(pred − actual)/lowerOffset` and `(actual − pred)/upperOffset`), quantile each →
  two scale factors. ~30 lines.
- **Both directions.** Unlike the current widen-only `max(modelSigma, recentRmse)`,
  conformal q̂ can be < 1 — an over-wide band tightens. Keep a safety floor
  (never scale below, say, 0.7) so a lucky fortnight can't produce an overconfident cone.
- **Min-sample guard** stays (`minSamples = 20` per horizon; fall back to the model
  band below it). Recompute in `updateRecentForecastError` at startup and after
  each reconciliation pass.
- **Tests:** feed synthetic (predicted, actual, band) triples with known error
  distribution; assert achieved coverage ∈ [86%, 94%] after calibration when the raw
  band under- and over-covers; assert the floor engages.

### 1.3 Unannounced-meal detection → live forecast (M)

**What:** when CGM rises in a way insulin can't explain, bend the live forecast up
instead of insisting BG will fall; ask the user to confirm; stop these windows from
poisoning Autotune.

**Implementation:**
- **Detection already exists:** `MealDetector` (`lib/ml/event_detectors.dart`)
  estimates carbs from sustained unexplained rise (`accumulatedRise / csf`). It
  currently has *zero* callers in the live path and zero tests — first add the unit
  tests (synthetic rise with/without covering bolus), then wire it.
- **Live wiring.** In the provider that assembles `PredictionState`
  (`lib/state/providers.dart`, the `forecastState` call sites), run the detector
  over the last ~45 min of CGM + IOB each refresh. On detection, append a synthetic
  `CarbEntry(time: detectedStart, grams: estimate, absorptionMinutes: 180)` to the
  state's carb list *for prediction only* — never persisted to history. Tag the
  Predict screen with a chip ("assuming ~35 g unlogged carbs — confirm?") so the
  user knows why the cone bent.
- **Confirm loop.** Stage a `PendingConfirmation` (`lib/feedback/pending_confirmation.dart`)
  via `ConfirmationService` with kind "detected meal"; confirming writes the real
  `CarbEntry` through the existing quick-log path and clears the synthetic one;
  dismissing suppresses re-detection for that window (KV-store a
  `meal_detect_dismissed_<window>` key, mirroring the exercise-warning pattern in
  `providers.dart`).
- **Autotune exclusion.** In `SensitivityTrainingService.buildExamples`
  (`lib/ml/sensitivity_training.dart`), run `MealDetector` over each day and pass
  detected windows into `Autotune.analyseDay` as extra pseudo-carb entries (they
  already close windows via the carb-active check) — unlogged meals then stop
  reading as insulin resistance.
- **Hysteresis/safety:** require the rise sustained ≥ 15 min (already the default),
  cap the synthetic estimate at ~60 g, decay it if the rise stops, and never let a
  synthetic entry raise the *bolus advisor's* COB — prediction-only, enforced by
  keeping the injection inside the forecast state builder, not the repository.
- **Tests:** unit tests for the detector; a provider-level test that a synthetic
  rise produces a bent forecast + staged confirmation; an Autotune test that a
  detected-meal day no longer inflates the multiplier. Docs: user guide (Predict
  chip + Confirm events card), integration test extension for the chip.

### 1.4 Bedtime / overnight-low forecast (M)

**What:** a 6–8 h hypo-risk assessment at ~bedtime: low/med/high with the working
shown, plus a suggested snack when risk is high.

**Implementation:**
- **Risk engine** — new `lib/insights/overnight_low.dart`. Inputs it can already get:
  current BG + trend (`PredictionState`), bolus IOB tail (`IobCalculator.total`
  projected forward hourly), tonight's basal schedule (`TherapySettings`), today's
  workout list + `WorkoutType` (`lib/insights/workout_classifier.dart` — aerobic
  raises overnight risk; the same signal the existing evening warning uses in
  `providers.dart`), alcohol events (`lib/insights/alcohol_watch.dart`), and the
  learned overnight buckets of `TimeOfDayProfile` (multiplier < 1 overnight = runs
  low). Method: run the deterministic predictor hourly to +8 h with the residual
  correction at 120 min then flat extrapolation of the *band* (don't pretend point
  accuracy at 6 h — evaluate the q10/lower edge only), then score
  `risk = f(min lower-edge, minutes below 80, aerobic load, alcohol flag)` into
  three tiers with explicit reasons (`['long ride this afternoon', '1.2 U IOB at
  bedtime']`).
- **Snack suggestion:** reuse the rescue-carbs sizing logic
  (`lib/analytics/rescue_carbs.dart`) against the projected deficit; present as
  "consider ~12 g slow carbs", advisory-only per charter.
- **Delivery:** a "Tonight" card on Today after ~20:30 (hide once slept), plus a new
  `NotificationCategory.overnightLowRisk` is *already defined* and used for the
  aerobic warning — either reuse it (replacing the cruder heuristic when the new
  engine is available) or add a distinct category; fire once per evening via the
  same KV-dedup pattern.
- **Evaluation loop:** log each night's tier + the actual overnight minimum
  (reconcile next morning in `AppJobs.runStartup`); show hit/miss stats on the
  accuracy screen after a few weeks. This is the honest-forecast principle applied
  to a longer horizon.
- **Tests:** unit tests for tiering on synthetic evenings (high IOB + exercise →
  high; flat no-IOB → low); reconciliation test; integration test for the card.
  User-guide section + notification table row.

### 1.5 Exercise-aware forecasting, properly (M)

**What:** teach the residual model the two exercise effects it currently can't see:
workout *type* and the delayed (up to ~24 h) sensitivity tail.

**Implementation:**
- **Features.** Extend `HealthFeatureSampler` (`lib/ml/health_features.dart`) with:
  `aerobic_tail = Σ over workouts of intensity · 0.5^(hoursSince/12)` (12 h
  half-life, clamp [0, 1.5]) and a `resistance_flag` for the last 4 h (anaerobic can
  *raise* BG). Workout type comes from `WorkoutClassifier.classify` on the health
  samples' `meta['activity']`, which the sampler already receives. Bump
  `ForecastFeatures.version` → 5 (`lib/ml/forecast_features.dart`); stale models
  auto-discard via `ForecasterModelStore`.
- **Zeros-for-missing** must hold (the sampler's existing contract) so pre-wearable
  history keeps training cleanly.
- **Immediate physiological band widening:** independent of learning, when exercise
  mode is active (`lib/insights/exercise_mode.dart`) widen the hypo side of the band
  by a fixed factor in `Forecaster.forecast` (or the calibrator) — physiology first,
  the learned tail then earns back tightness. After §1.1 this is "scale
  `lowerOffset` × 1.3 while exercise mode on".
- **Ordering note:** land *after* the EGP baseline fix and §1.8, or the new features
  will partly fit label noise.
- **Tests:** extend `test/health_forecast_features_test.dart` (tail decays with the
  right half-life; resistance flag windows; version bump), plus a trainer test that
  a synthetic history with post-exercise drops yields a negative residual
  contribution when the tail feature is high (GBM recovery-style test like the
  existing nonlinear ones in `test/gbm_test.dart`).

### 1.6 Population-prior warm start (L)

**What:** ship a prior residual model so week one isn't "deterministic baseline
only"; blend it out as personal data accumulates.

**Implementation:**
- **Build the prior offline, ship as an asset.** The GBM already serialises to JSON;
  train per-horizon priors on synthetic-but-plausible histories from the existing
  simulator (`lib/dev/sim_data.dart` — vary seed, dawn magnitude, meal-overshoot
  parameters across ~100 simulated users via a small `tools/` script), then commit
  `assets/models/residual_prior_v<featureVersion>.json`. Because it's trained
  against the *same* `GlucosePredictor` baseline and `ForecastFeatures` layout, it's
  drop-in compatible — and must be regenerated on every feature-version bump
  (assert `featureVersion` inside the asset and refuse to load on mismatch).
- **Blend.** New `BlendedResidualModel implements ResidualModel`:
  `residual = (1−w)·prior + w·personal`, `sigma = max(prior σ, personal σ)` (never
  report the tighter of the two while blending), with
  `w = (personalTrainSamples / 600).clamp(0, 1)` persisted alongside the model.
  `ForecasterModelStore.load` returns the blend when a personal model exists, prior-only
  otherwise; `Forecaster` is untouched (it just sees a `ResidualModel`).
- **Gate interaction.** The promotion gate compares candidate vs incumbent
  (`ForecasterModelController.train`); the incumbent becomes the *blend*, which is
  exactly right — a personal model must beat prior+personal to ship.
- **Honesty rule:** the Advanced screen's "Learned residual" row shows
  "prior (n=0)" / "blended (w=0.4)" / "personal" so it's never ambiguous whose
  correction is on screen.
- **Tests:** blend math unit tests; asset load + version-mismatch refusal;
  cold-start integration check (fresh demo profile shows "prior" and a non-flat
  residual at 60 min).

### 1.7 Short-horizon forecast for alerting (S–M)

**What:** a 15-min horizon powering the predicted-low alert with tunable lead time.

**Implementation:**
- `Forecaster(horizons: const [15, 30, 60, 120])` — the pipeline is horizon-keyed
  end-to-end (trainer map, sigmas, `StoredPrediction.horizonMinutes`, accuracy
  report), so this is mostly configuration. Check the two UI call sites that
  iterate horizons (`predictions_screen.dart`, Today's next-hours card) and filter
  to `[30, 60, 120]` there so the 15-min line stays alert-internal.
- Prediction persistence: 15-min predictions mature fast, quadrupling reconciliation
  rows — pair with §3 retention/pruning, or store 15-min rows with a shorter TTL.
- **Alert rule** in `AlertMonitor` (`lib/insights/alert_monitor.dart`): fire
  "predicted low" when the 15-min *lower band edge* (not the point estimate —
  deliberate asymmetric caution) crosses the user's low threshold
  (`lib/insights/alert_thresholds.dart`), with a lead-time setting (10/15/20 min →
  interpolate along the prediction line) and re-alert suppression until the
  prediction recovers. After §1.1/§1.2 the band edge is calibrated, which is what
  makes this trustworthy.
- **Tests:** alert-monitor unit tests with synthetic falling traces (fires at the
  configured lead time, suppresses duplicates, respects quiet-hours prefs in
  `notification_prefs.dart`).

### 1.8 Robust rate-of-change + CGM noise handling (S)

**What:** replace the noisiest feature (single-step ROC) and stop first-day sensor
noise from polluting bands and training.

**Implementation:**
- **Slope:** add `robustRocMgdlPerMin(List<CgmSample>, DateTime now)` — weighted
  least-squares slope over the last 15 min (≥ 3 points, weights = recency), fall
  back to the 2-point delta below 3 points. Use it in *both* places the 2-point ROC
  is computed today: live state assembly (`providers.dart`) and training
  (`ForecasterTrainer`, which currently derives `roc` from `cur/prev`) — train/serve
  symmetry matters more than the estimator choice.
- **Sensor-age awareness:** sensor start events are already logged (quick-log sensor
  change / `DeviceKind` tracking). During the first 24 h of a sensor: multiply
  training-sample weight by ~0.5 (`RetrainingPipeline` already supports per-sample
  weights via annotations — add a synthetic low-confidence context annotation over
  the window rather than new plumbing), and scale the live band by ~1.15 in the
  calibrator. `CgmSample.sensorWarmup` already excludes the blind window; this
  handles the noisy-but-present day after it.
- **Tests:** slope estimator on noisy synthetic ramps (recovers true slope, beats
  2-point delta variance); weight-annotation window applied; feature version note —
  ROC swap changes feature *semantics* without changing layout, so still bump
  `ForecastFeatures.version` to force retrain on the new definition.

### 1.9 Per-meal absorption learning → COB curves (M)

**What:** repeat meals get their own absorption duration/shape in forecasts and
bolus previews, learned from their observed post-meal traces.

**Implementation:**
- **Learning:** `MealOutcomeService` (`lib/meals/meal_outcome_service.dart`) already
  reconciles each logged meal against the CGM window and stores outcomes
  (peak, time-to-peak). Add a per-meal absorption estimate: fit
  `absorptionMinutes ≈ clamp(2 × timeToReturnToBaseline − preBolusOffset, 90, 360)`
  from the last N outcomes of that `SavedMeal` (median of ≥ 3 outcomes before
  trusting; store on the meal record in `meal_library.dart` as
  `learnedAbsorptionMinutes` + `outcomeCount`).
- **Consumption:** when a meal is logged from the library, stamp the resulting
  `CarbEntry.absorptionMinutes` from the learned value (fallback: current default).
  `CarbModel` (`lib/analytics/carb_math.dart`) already honours per-entry absorption,
  so the predictor, COB display, IOB/COB charts and Autotune's carb-active windows
  all pick it up with no further changes — that's the leverage.
- **Surfacing:** meal detail sheet shows "your absorption ≈ 4.5 h (from 6 meals)";
  FPU coach (`lib/meals/fpu_coach.dart`) should *not* double-count — skip the FPU
  extension when the learned duration already exceeds the FPU-extended default.
- **Tests:** outcome→absorption fit on synthetic traces (fast/slow meals recovered);
  library round-trip persistence; a predictor test that two meals with different
  learned absorptions produce visibly different COB tails.

### 1.10 Walk-forward validation + real model history (M)

**What:** promote on multi-fold walk-forward evidence instead of one 80/20 split,
and make model history browsable/rollbackable.

**Implementation:**
- **Folds.** Generalise `ForecasterTrainer.train`: split the sample timeline into
  K = 3–4 contiguous blocks; for each fold k, train on blocks < k, evaluate on
  block k, with a *purge gap* of `maxHorizon` minutes between train end and test
  start (rows whose target time crosses the boundary are dropped — the ±6 min
  `_nearest` slop makes this mandatory). Candidate metrics = pooled fold metrics;
  the shipped model retrains on all blocks. Guard: below ~10 days of data, fall
  back to the current single split (folds too thin otherwise).
- **Promotion.** `ForecasterModelController` gates on pooled metrics; add
  `foldRmses` to `TrainingOutcome` and persist them in the `ModelRuns` metrics JSON
  (`saveModelRun` in `providers.dart`) so instability across folds is visible.
- **Rollback.** The `ModelRuns` table (`lib/data/database.dart`) currently stores
  metrics only. Add the model blob (or a KV key per run id) for the last ~5
  promoted models; Advanced screen gets a "Model history" list (id, date, RMSE,
  promoted/kept) with "restore this model" → writes it through
  `ForecasterModelStore.save` and refreshes `forecasterModelProvider`. Restore must
  refuse on feature-version mismatch.
- **Tests:** fold construction (purge gap enforced, no target leakage across the
  boundary — assert via a crafted sample whose target sits in the gap); pooled-gate
  behaviour; store/restore round-trip incl. version refusal.

---

## 2. Alerts & insight surfaces that consume forecasts

- **Band trust meter on Predict** (S, needs §1.1/§1.2): compute rolling 7-day
  coverage per horizon from reconciled `StoredPrediction`s (same query
  `updateRecentForecastError` already runs), expose as a provider, render a small
  "band caught 9/10 this week" chip under the cone. Honest-UI counterpart of the
  calibration work.
- **Daily hypo-risk score** (S): LBGI is already computed in the metrics layer;
  surface yesterday-vs-14-day-baseline in `MorningSummary`
  (`lib/insights/morning_summary.dart`) with one reason string (worst overnight
  window, exercise tail). No new math — presentation + threshold.
- **Per-time-of-day alert thresholds** (M): extend `AlertThresholds` to a small
  per-segment table (overnight/day/post-meal), editable in the Notifications
  screen; `AlertMonitor` picks the active segment. Migration: existing single
  values become the all-day row. Update user guide + integration test.
- **"Why this forecast" decomposition** (S–M): `GlucosePredictor` already exposes
  scenario lines (insulin-only / carbs-only in `scenarioLines`); add a per-horizon
  breakdown sheet in advanced mode: baseline Δ from insulin, carbs, momentum
  (three simulations with the others zeroed — cheap), + residual correction value
  and band source (model σ / conformal-scaled / default widening). Pure
  presentation over existing pieces; no model changes.

## 3. Data foundation (enablers)

- **Nightscout follower mode** (M): `NightscoutClient`
  (`lib/integrations/nightscout.dart`) currently uploads. Add
  `fetchEntries(since)` / `fetchTreatments(since)` (GET `/api/v1/entries.json`,
  `treatments.json`, token auth already configured), a pull loop in `AppJobs`
  guarded by a "source mode" setting, and merge through the same dedupe path as
  pump backfill (stable ids: Nightscout `_id`). Charter-safe: read-only by nature.
  Risk to manage: don't double-ingest when the pump link is also live — source
  priority setting (pump > NS) with per-sample provenance.
- **Retention & pruning** (S–M): startup job in `AppJobs` deleting
  `Predictions` > 90 d, `HealthSamples` > 180 d, keeping CGM/treatments (they're
  the training corpus; revisit at 12+ months). Drift migrations not needed —
  plain deletes; add repository `pruneBefore(table, cutoff)` methods + tests. Also
  fixes the growing reconciliation cost noted in the review.
- **Fingerstick↔CGM merge policy** (M, REVIEW P1-2): add `isCalibration` to meter
  imports (heuristic: within ±15 min and ±20% of a CGM reading → calibration
  candidate, user-confirmable via Confirm events), exclude calibrations from
  metrics/training, show both on the day chart with distinct glyphs. Schema change
  → drift migration + tests.
- **Libre / Dexcom-share ingestion** (M–L): separate source adapters feeding the
  same ingest path as Nightscout-follower; do *after* follower mode establishes the
  provenance/dedupe pattern.

## 4. Beyond forecasting

- **4.1 Free-text meal → carbs/fat/protein** (M, 🧠): reuse the `flutter_gemma`
  runtime (`lib/food/panel_llm_gemma.dart`) with a new prompt builder
  (`buildMealEstimatePrompt`: dish list → JSON `{items:[{name, grams_carbs, …}],
  total}`), the same greedy decoding + 45 s timeout + close-after-use pattern, and
  the same validation layer as the scanner ([panel-llm.md](panel-llm.md) items 1–3
  are prerequisites — bounds + grounding are shared infrastructure). Entry point: a
  text field on the Meals tab / bolus advisor prefill, always editable before use,
  clearly labelled as an estimate. Fallback when no model installed: name search
  against the offline AFCD database (`lib/food/offline_afcd.dart`) — the feature
  degrades, never blocks.
- **4.2 Ask-your-data Q&A** (L, 🧠): grounded generation over *computed* facts, not
  raw history: build a retrieval context from existing analytics (day narratives
  `lib/insights/daily_narrative.dart`, reports, metrics, event log) selected by
  keyword/date parsing of the question; the LLM only phrases/synthesises the
  retrieved facts and must cite which fact each claim came from (reject answers
  referencing nothing — same grounding philosophy as the scanner). Start with a
  fixed question taxonomy ("why high/low at T?", "how does <meal> hit me?",
  "compare this week") before free-form.
- **4.3 Garmin complication publisher** (M, 🔌, ROADMAP 1.3): resource-defined
  complication in the CIQ app + `Complications.updateComplication` on each BG push;
  verify with a subscribing watch face on real hardware. (Kotlin/Monkey C —
  remember `./gradlew :app:testDebugUnitTest` and the sim screenshots script.)
- **4.4 Mood ↔ glucose correlation** (S, ROADMAP 1.7): mood is an annotation kind
  already; weekly job correlating mood tags with same-day TIR/CV (Spearman on
  ranked TIR, ≥ 8 tagged days before showing anything) → one Insights card
  ("stressed days run 12% less time-in-range"). If nothing significant after
  8 weeks, show nothing — decide explicitly against fishing.
- **4.5 Clinic-visit prep** (S–M, 🧠 optional): compose the existing report models
  into a plain-language summary (template-based first — the LLM is optional
  phrasing, so this ships without a model installed) + auto-generated questions
  ("overnight lows clustered on gym days — discuss basal profile?"). Export via the
  existing PDF pipeline.
- **4.6 Weekly digest** (S): reuse the `background_summary.dart` WorkManager
  scheduling (add a weekly task alongside the morning one) + `MorningSummary`
  composition style: TIR/GMI/hypo deltas vs prior week + one learned insight
  (best/worst recurring window from the time-of-day profile). Notification +
  Insights card; user-guide + notification-category row.

---

## Suggested sequencing

EGP baseline fix → 1.8 (cheap, improves labels) → 1.1 + 1.2 (honest bands) →
1.3 (meal detection) → 1.4 (overnight low) → 1.10 (validation/rollback) → then
branch by appetite: 1.5/1.9 (forecast depth), 4.1 (LLM daily value), or §3
(data breadth). §2 items slot in behind their §1 dependencies as S-sized wins.

Cross-cutting reminders for every item: update `doc/user-guide.html` for anything
user-visible, extend `integration_test/` for new screens/panels, bump
`ForecastFeatures.version` whenever feature semantics change (not just layout), and
keep every learned number advisory + explained per the charter.
