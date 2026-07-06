# High-value feature ideas — forecasting first

_Drafted 2026-07-06. A curated backlog of features ranked by expected value for a
single-user, read-only, on-device companion. Forecasting is the deepest section
because it's the engine everything else (alerts, advisor context, insights) draws
from. Fix-type work lives in [../REVIEW-recommendations.md](../REVIEW-recommendations.md);
deferred panel-LLM work lives in [panel-llm.md](panel-llm.md); this doc is *new
capability* ideas. Effort: S ≤ ½ day · M 1–2 days · L 3+ days._

**One prerequisite dominates:** the net-basal/EGP baseline fix
(REVIEW P0-2). Until the deterministic baseline stops treating basal as an
un-opposed glucose-lowering force, residual labels, Autotune labels and the
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
Replace the single symmetric sigma with per-horizon **quantile residual models**
(the GBM already supports weighted fitting; pinball loss at q10/q50/q90 is a small
change) so the band can be wide toward hypo and tight toward hyper when that's what
the data says. Pair it with **coverage + signed-bias reporting** on the accuracy
screen ("your 90% band contained 84% of outcomes; forecasts run +6 mg/dL high at
60 min"). RMSE alone can't tell an over-confident model from a biased one.

### 1.2 Conformal calibration of the live band (S–M)
The reconciled-predictions table is exactly the calibration set split-conformal
needs: take the last ~2 weeks of |error| quantiles per horizon and inflate/deflate
the band to hit target coverage, distribution-free. Strictly better than the current
"widen to recent RMSE" rule (which conflates bias and variance and never narrows),
and it composes with 1.1: quantile model for shape, conformal for guaranteed coverage.

### 1.3 Unannounced-meal detection → live forecast (M)
`MealDetector` already estimates carbs from unexplained rise. Wire it in two places:
(a) inject a low-confidence synthetic COB into the *live* forecast so the cone bends
up during an unlogged meal instead of insisting BG will fall; (b) exclude detected
windows from Autotune's "carb-free" observation so unlogged meals stop reading as
insulin resistance. Surface it as a Confirm-events card ("~35 g detected at 13:10 —
confirm?") so the user stays the labeler of record.

### 1.4 Bedtime / overnight-low forecast (M)
A purpose-built 6–8 h hypo-risk assessment at bedtime: current BG + IOB tail +
today's exercise load + alcohol flags + the learned overnight time-of-day profile
→ "risk of <70 before 3am: low/med/high, working shown", with a suggested snack
size when high. Uses only existing signals; delivered as a notification category +
a Tonight card. This is the feature that most changes how safe the nights feel.

### 1.5 Exercise-aware forecasting, properly (M)
The health features capture *acute* activity. Add the two effects that matter and
are currently invisible: **workout-type** (aerobic vs anaerobic vs mixed — already
classified for the hypo warning) as residual features, and a **post-exercise
sensitivity tail** feature (hours-since-workout × intensity, decaying over ~24 h)
so the model can learn delayed overnight drops. Also let active exercise mode widen
the hypo-side band immediately (physiology first, learning later).

### 1.6 Population-prior warm start (L)
Cold start is "deterministic-only for weeks". Ship a small prior residual model
trained on plausible synthetic/simulated patterns (dawn phenomenon, post-meal
overshoot shapes) and blend `prior × (1−w) + personal × w` with w ramping on
personal sample count. Even a crude prior beats a flat zero residual, and the
promotion gate already protects against a bad blend.

### 1.7 Short-horizon forecast for alerting (S–M)
Add a 15-min horizon dedicated to the predicted-low alert (the 30-min one is the
current floor). Cheap: same pipeline, one more horizon key. Pair with lead-time
tuning in the alert monitor ("warn when the q10 line crosses 80 within 20 min").

### 1.8 Robust rate-of-change + CGM noise model (S)
Single-step ROC is the noisiest feature in the vector. Replace with a ~15-min
weighted regression slope, and flag first-day-of-sensor periods (already tracked
via sensor age) with a wider band / down-weighted training samples. Small change,
benefits every horizon.

### 1.9 Per-meal absorption learning → COB curves (M)
Meal outcomes are already learned per library meal. Feed the learned peak/duration
back into that meal's absorption curve for forecasting and bolus preview ("pizza:
your absorption ≈ 4.5 h"), instead of one global bilinear curve. High leverage for
repeat meals, which is most meals.

### 1.10 Walk-forward validation + model history (M)
Replace the single 80/20 time split with purged, blocked walk-forward folds (3–4
folds over 30 days, gap ≥ horizon between train/test) for the promotion decision,
and make the model registry real: keep the last N promoted models with metrics and
allow one-tap rollback from the Advanced screen. Prevents a lucky fold from
shipping and makes regressions recoverable.

---

## 2. Alerts & insight surfaces that consume forecasts

- **Band trust meter on Predict** (S): show live 7-day coverage next to the cone
  ("band caught 9 of last 10") so trust is earned, not asserted. Depends on 1.1/1.2.
- **Daily hypo-risk score** (S): LBGI-based morning number with trend, feeding the
  morning summary ("higher risk than usual — yesterday's long ride").
- **Per-time-of-day alert thresholds** (M, ROADMAP Part 2): tighter overnight
  predicted-low threshold, looser post-meal; snooze/ack semantics.
- **"Why this forecast" decomposition** (S–M): advanced-mode breakdown per horizon
  (baseline insulin/carb/momentum contributions + residual correction + band
  source). The pieces all exist; this is presentation and trust.

## 3. Data foundation (enablers, mostly M)

- **Nightscout follower mode** (M): CGM/treatments as a *source* — makes the app
  useful on days the pump link is down and enables remote-follow scenarios.
- **Retention & pruning** (S–M): predictions/health tables grow unboundedly today;
  a rolling window keeps startup training and reconciliation fast (REVIEW C).
- **Fingerstick↔CGM merge policy** (M): calibration-vs-standalone flags so meter
  imports stop double-counting in metrics and training (REVIEW P1-2; prerequisite
  for trusting meter-augmented labels).
- **Libre / Dexcom-share ingestion** (M–L): breadth beyond the pump path.

## 4. Beyond forecasting

- **4.1 Free-text meal → carbs/fat/protein** (M, 🧠): "chicken curry, rice, naan"
  → macro estimate prefilled into the advisor, using the already-wired Gemma
  runtime; grounding/validation layer shared with the panel scanner
  ([panel-llm.md](panel-llm.md) items 1–3 are the prerequisite).
- **4.2 Ask-your-data Q&A** (L, 🧠): "why was I high last night?" answered from
  computed metrics + events (on-device retrieval over reports, not raw-LLM guessing).
- **4.3 Garmin complication publisher** (M, 🔌): BG on any watch face —the biggest
  wearable win (ROADMAP 1.3).
- **4.4 Mood ↔ glucose correlation** (S): make mood logging *do* something
  (ROADMAP 1.7): weekly insight card correlating mood tags with TIR/variability, or
  explicitly declare it journal-only.
- **4.5 Clinic-visit prep** (S–M, 🧠): reports → plain-language summary + suggested
  questions for the endo; pure consumer of existing report data.
- **4.6 Weekly digest** (S): TIR/GMI/hypo-count deltas + one learned insight
  ("Wednesday lunches run high"), reusing morning-summary plumbing.

---

## Suggested sequencing

EGP baseline fix → 1.8 (cheap, improves labels) → 1.1 + 1.2 (honest bands) →
1.3 (meal detection) → 1.4 (overnight low) → 1.10 (validation/rollback) → then
branch by appetite: 1.5/1.9 (forecast depth), 4.1 (LLM daily value), or §3
(data breadth). §2 items slot in behind their §1 dependencies as S-sized wins.
