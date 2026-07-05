# bgdude — Roadmap & backlog

A living plan for finishing what's in flight and deciding what to build next.

**Charter (don't drift from this):** a personal, **read‑only** Tandem t:slim X2 companion.
On‑device first, privacy‑preserving, never delivers insulin or control commands. Every
number the app suggests is shown with its working and confirmed by you before it matters.

**Legend** — Effort: **S** ≤ ½ day · **M** 1–2 days · **L** 3+ days.
🔌 = needs specific hardware to verify · 🧠 = uses the on‑device LLM runtime · 🔒 = safety‑sensitive.

---

## Status snapshot (what's already real)
Working & verified on emulator / unit-tested: onboarding + demo mode, Today (glucose hero
+ day-trend, next-few-hours + on-board IOB/COB/basal charts), Predict (horizons, scenario
lines, what-if), Insights (briefing, sensitivity, A1c/GMI + lab A1c, sleep), Meals (library,
barcode, name search, **nutrition-label OCR scan**, pre-bolus/FPU coach), **Bolus advisor
(carbs + correction + fat/protein FPU, Control-IQ aware)**, Quick-log (carbs/bolus/exercise/
alcohol/stress/mood/**illness**/sensor/site), Confirm-events inbox, Exercise/Medication/
Illness/Weather modes, Notifications (19 categories incl. **anomaly "Unusual pattern"** +
morning summary), 7 Reports + PDF/CSV, Pump screen (Control-IQ mode), Therapy/Basal, Advanced/
models, Profile, Home-screen widget, **Garmin** widget/watch-face/data-field, **demo mode
seeded with ~2 weeks of history**. Forecaster = deterministic baseline + learned GBM residual.

---

## Decided direction (chosen this session)
- **Focus:** *finish & verify the device-dependent features* — turn "built but unverified"
  into "proven on real hardware."
- **Hardware available for testing:** t:slim X2 pump, Dexcom CGM, Accu-Chek Guide Me meter,
  Garmin watch, Pixel 7 Pro. → every 🔌 item is now verifiable.
- **LLM scope for now:** *just finish the panel scanner* (verify Gemma inference on-device);
  hold the new LLM features (meal→carbs, Q&A, NL log) in the backlog.
- **Audience:** personal (Summer) — skip multi-user pairing UX, store compliance, and public
  onboarding polish for now.

**These are collaborative:** the physical pump/meter/watch and the Pixel are yours, so most
verification is "I prepare a build + an exact test procedure (and in-app self-checks where
possible) → you run it on the device → report back → I fix." I can't touch the hardware.

### Execution order (near-term)
1. **Panel scanner — verify Gemma on-device** (1.1/1.8). Add an in-app "test the model"
   self-check (canned panel text → LLM → JSON) so inference is verifiable without a perfect
   photo; document the exact model-download/license steps; then scan real labels and measure.
2. **Accu-Chek Guide Me meter** (1.2). Field-test pairing + record sync; fix bonding/re-scan
   edge cases; dedupe/merge fingersticks with CGM.
3. **Garmin watch** (1.4 then 1.3). Install the 3 products, verify phone→watch push + the
   background service; add the modern device to the manifests; then the real complication.
4. **Pump + Dexcom** (1.6). Harden real pumpx2 pairing / reconnect / error surfacing and
   validate live CGM data + predictions.
5. **Neural forecaster** (1.5) — decision, likely after the above (or just drop the comments).

_Deprioritised for now: Part 3 new features, Part 4 release/store, multi-user UX._

---

## Part 1 — Finish what's started (deferred / unverified)

| # | Item | What's done | Remaining to "fully finished" | Effort | Flags |
|---|------|-------------|------------------------------|--------|-------|
| 1.1 | **Nutrition-label AI (Gemma)** | Runtime wired (flutter_gemma on AGP 8.9), download/manage UI, gated fallback, builds + launches | Verify **inference** on a real device with a real ~0.5 GB model; curate a known-good Gemma 3 1B `.task` URL + license flow; auto-suggest download when a scan fails; RAM/space gating; consider fine-tuned Gemma 3 270M on our 100-panel dataset | M | 🔌🧠 |
| 1.2 | **Bluetooth glucose meter (Accu-Chek Guide Me)** | Decoder, RACP sync, `flutter_blue_plus` transport, pair/manage UI, unit tests | Field-test pairing + record sync on the real meter; bonding/re-discovery edge cases; dedupe + merge fingersticks with CGM (calibration vs standalone); background sync | M | 🔌 |
| 1.3 | **Garmin complication** | 3 products build/run in sim; complication removed (was mis-implemented) | Implement the *real* publisher path (resource-defined app complication + `updateComplication`); verify on-watch with a subscribing face | M | 🔌 |
| 1.4 | **Garmin on-watch verification + device list** | Sim-verified; screenshots | Install on a paired watch, confirm phone→watch push + background service; add modern devices (fenix 8, fr970, venu 3) to the manifests | S–M | 🔌 |
| 1.5 | **Neural (LiteRT) residual forecaster** | Interface + Dart GBM residual work; comments promise a `residual_model_litert.dart` that doesn't exist | Decide: build the neural residual (LiteRT on-device, train overnight) **or** remove the aspirational comments and commit to the GBM. Validate accuracy uplift vs GBM before promoting | L (build) / S (remove) | 🧠 |
| 1.6 | **Pump pairing robustness (pumpx2)** | Native read path, pairing dialog, reconnect | Real-hardware reliability pass: pairing retries, reconnection, clear error surfacing, handling t:connect mutual-exclusion, long-run stability | M | 🔌 |
| 1.7 | **Mood logging** | 🙂 Mood captured as an annotation | Make it *do* something (feed the sensitivity context / surface a mood↔glucose correlation) or explicitly keep it as journal-only | S | |
| 1.8 | **Inference-quality of the panel LLM** | Prompt + JSON parse tested | Once 1.1 runs on-device, measure real image→values accuracy (the on-device accuracy test exists) and tune prompt / few-shot | S | 🔌🧠 |

---

## Part 2 — Core-loop polish (make the daily driver rock-solid)

- **Prediction validation on real data** — the model-accuracy screen exists; run it against
  your real history, calibrate uncertainty bands, tune momentum/IOB/COB params. (M)
- **Alert quality** — per-time-of-day thresholds, snooze/ack, smarter de-duplication,
  "predicted low" lead-time tuning, do-not-alert-during-exercise nuances. (M) 🔒
- **Data integrity** — CGM gap handling, sensor warm-up/compression robustness, timezone/DST
  correctness across history, dedupe on backfill, clock-drift from the meter. (M)
- **Reliability** — foreground-service survival, battery, reconnect after phone sleep,
  crash-free long runs. (M) 🔌
- **First-run for real hardware** — smooth pump pairing UX, permission flows, Health Connect
  setup, "no data yet" states. (S–M) 🔌

---

## Part 3 — New features (ideas to pick from)

### 3A. Intelligence (mostly reuse the on-device LLM runtime) 🧠
- **Free-text meal → carbs/fat/protein.** "chicken curry, rice, a naan" → estimated macros
  that prefill the bolus advisor. Natural meal entry alongside scan/search. **(M, high value)**
- **Ask-your-data Q&A.** "why was I high last night?", "how does pizza hit me?" — grounded in
  your computed metrics/reports/history (on-device retrieval). **(L)**
- **Free-text quick-log parsing.** "45-min run before lunch + 2 beers" → structured events. (M)
- **Natural-language explanations.** Upgrade the template day/reading narratives; "why?" follow-ups. (M)
- **Clinic-visit prep.** Reports → plain-language summary + "questions for your endo". (S–M)
- **Smarter meal learning.** Surface per-meal learned CR/absorption, time-of-day ISF/CR drift. (M)
- **Exercise-aware forecasting.** HR-zone / workout-type effects folded into the predictor. (M)

### 3B. Data & device breadth 🔌
- **Nightscout as a data *source* (follower mode)**, not just upload — CGM/treatments in. (M)
- **Additional CGM ingestion** — Libre (via LibreLinkUp/xDrip), Dexcom Share/follower. (M–L)
- **More Health Connect / wearable data** — SpO2, respiration, stress, menstrual, workouts. (S–M)
- **Other Bluetooth meters/devices** — ketone meter (DKA safety), smart scale, BP cuff. (M) 🔒
- **Tandem Mobi** support (pumpx2 already knows the model). (M) 🔌

### 3C. UX & surfaces
- **Wear OS / Apple Watch** companions (parallel to Garmin). (L) 🔌
- **Widget variants** — a mini-graph widget, a one-tap quick-log widget. (M)
- **Voice logging** — Assistant/Siri shortcut → quick-log. (M)
- **Accessibility** — large-text, screen-reader labels, colour-blind-safe range palette. (S–M)
- **Localization** — language (units already handled). (M)

### 3D. Reports, sharing & privacy 🔒
- **Standards-compliant AGP** + clinician PDF polish; time-in-tight-range trends. (S–M)
- **Secure share to clinician** (export bundle, redaction options). (M)
- **Encrypted backup / restore + full data export & delete** (privacy/GDPR-style). (M)
- **Period digests** (weekly/monthly) surfaced or exported. (S)

### 3E. Safety hardening 🔒
- **Explicit safety review** of every suggestion path (bolus advisor, rescue carbs, alerts):
  fail-safe defaults, bounds, "when to distrust me" copy. (M)
- **Ketone / sick-day flow** deepening (already have the alert). (S–M)

---

## Part 4 — Quality & infrastructure
- **Git remote + push** so CI + the GitHub Pages workflow actually run (nothing is pushed
  today). (S)
- **Broaden emulator/integration coverage** for the newer screens (meter, AI model, Garmin
  is sim-scripted). (M)
- **Golden/screenshot tests** to catch UI regressions. (M)
- **On-device-only crash/error logging** (no external service, privacy-preserving). (S)
- **Release path** — app signing, Play Store internal track vs. keep sideload-only. (M) 🔌

---

## Part 5 — Open questions (help me prioritise)
1. **What's the #1 goal right now** — a rock-solid daily driver on your real hardware, or
   breadth of new features?
2. **Which hardware can you actually test with** (and how often)? Pump, Dexcom, Accu-Chek
   meter, Garmin watch — this decides what "🔌" work we can finish vs. leave sim/unit-tested.
3. **Which LLM feature first** — free-text meal→carbs, ask-your-data Q&A, NL quick-log, nicer
   explanations, or just finish the panel scanner?
4. **Audience** — strictly personal (Summer), shareable with other T1Ds later, or heading
   toward a public release? (changes how much we invest in pairing UX, model download, safety
   copy, store compliance.)
5. **Neural forecaster** — worth building the LiteRT residual, or commit to the GBM and drop
   the "neural" comments?
6. **Any dream features** not listed here? (voice, a specific integration, a particular report,
   automation…)

_Answers get folded back into this file as the plan is refined._
