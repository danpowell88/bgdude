---
id: doc-1
title: Roadmap (archived 2026-07-06)
type: other
created_date: '2026-07-06 08:46'
tags:
  - roadmap
  - archived
  - planning
---
# bgdude — The Plan (ARCHIVED)

> **ARCHIVED 2026-07-06.** The backlog (tasks + milestones + decisions) is now the
> single planning source; this document is preserved read-only because task notes
> cite it as `Source: ROADMAP section N`. Do not update it. Milestones m-0..m-7
> mirror the "Suggested execution order" phases below; the charter and standing
> context decisions live in `backlog/decisions/`. Item statuses below are frozen
> as of the archive date — the backlog is authoritative.

_Originally consolidated 2026-07-06 from `ROADMAP.md`, `doc/REVIEW-recommendations.md`
(the July 2026 engineering/clinical review — full evidence preserved verbatim in git
history at commit `7385bda`), `doc/plans/architecture.md`, `doc/plans/feature-ideas.md`
and `doc/plans/panel-llm.md`._

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

## Status snapshot (what's already real, as of 2026-07-06)

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

**Real-hardware milestone (Jul 2026):** verified end-to-end on a live t:slim X2
(API 3.4) — JPAKE 6-digit pairing works after two pairing-flow fixes (see 2-5), and
the new **Protocol Explorer** (Settings → **Developer** → Protocol Explorer) swept
the pump's whole read-only surface, capturing decoded fields for every previously
un-surfaced message (HomeScreenMirror, PumpFeatures, PumpSettings, PumpGlobals,
ControlIQSleepSchedule, MalfunctionBitmaskStatus, CGMHardwareInfo, limits, …). Those
findings seed **section 4-5** (pump mirror & device features) and **section 4-6**
(dev/debug screens); raw capture is in `doc/pump-protocol.md`.

Forecaster = deterministic baseline + learned GBM residual. **July 2026 ML
overhaul (done):** promotion A/Bs candidate vs baseline *and* the live model on the
same held-out tail; sigma from held-out error; no future-dose leakage in training;
training off the UI isolate, ~once a day; hypo gate skips hypo-free windows
(P2-3 ✅); dead sensitivity feature removed (P2-6 ✅); Autotune label is a
duration-weighted median of window ratios; ridge lambda by LOO-CV with skill-based
confidence (most of P2-5 ✅); Clarke zones B/C/D/E reference-tested (part of
P2-10 ✅); direct tests for autotune/ridge/forecaster-service.

---

## Suggested execution order (master) — now milestones m-0..m-7

The through-line: **make the numbers right (Phase 1), make the data trustworthy
(2), make the safety net structural (3), then make forecasting honest (5) — with
hardware verification (4) interleaved whenever device time exists, and the big
architecture consolidation (6) once the safety-critical work has landed.**

| Phase | What | Why this order | Contents |
|---|---|---|---|
| **0. Hygiene & quick safety** (days) | Dead deps, architecture guard test (incl. mechanical read-only-pump check), Keystore fix, the five S-sized dosing-math fixes | Cheap, permanent, independent; P0-1/4/5/6/7 change dosing numbers *today* | 1 P0-1,4,5,6,7 · P1-1 · 3.G, 3.J |
| **1. Root model fix** | Net-basal/EGP baseline + re-tune + like-for-like sensitivity | The single highest-ROI change; every learned label inherits its drift until fixed | 1 P0-2, P0-3 |
| **2. Data integrity & storage** | Drift migration harness → schema v3 (calibration flag + dedupe) → repo tests, batched reconciliation, retention | Dosing advice reads IOB/TDD from this data; also unblocks Phases 3.3 and 5 | 1 P1-2, P1-3, P1-6 · 3.H · 4-3 retention |
| **3. Alert-aliveness backstop** | Pure alert-decision core + native urgent-low backstop; document the limitation | The most safety-relevant *architectural* gap; steps 1–2 are cheap and independent of the big refactor | 3.C steps 1–2 (P1-7 partial) |
| **4. Hardware verification track** (interleaved, 🔌-gated) | Native thread/boot fixes first, then: Gemma on-device (with section-5 items 1–3 landed first) → meter → Garmin (incl. complication) → pump reliability | P1-4/P1-5 crash on first real connection otherwise; order matches prior session's decided direction | 1 P1-4, P1-5, P1-9 · 2 items 1.1→1.6 · P2-8 |
| **5. Honest forecasting** | Robust ROC → quantile bands → conformal calibration → meal detection → overnight-low → walk-forward + rollback | Each step feeds the next; makes Predict/alerts trustworthy rather than plausible; completes P2-1/P2-2/P2-4 | 4-1: 1.8 → 1.1 → 1.2 → 1.3 → 1.4 → 1.10 (+P2-9) |
| **6. Architecture consolidation** | providers.dart split + PersistedStateNotifier + logging sweep + clock injection → KvStore seam → headless alert evaluation | Invasive but mechanical; safer after the safety-critical phases; step 6.3 needs Phase 2's single-connection fix | 3.A, D, E → 3.B → 3.C step 3 · 3.F, 3.I |
| **7. Depth & breadth (by appetite)** | Exercise tails, warm start, per-meal absorption; free-text meal→macros; Nightscout follower; reports/release polish | Pick by energy: forecast depth (4-1.5/1.6/1.9), LLM daily value (4-4.1), or data breadth (4-3) | 4 remainder · 5 remainder · 6 |

Rules of thumb: the hardware track (4) runs opportunistically alongside any desk
phase; nothing in Phase 5+ should start before Phase 1 lands (labels are poisoned
until then — enforced as task dependencies on TASK-2); every user-visible change
updates `doc/user-guide.html` + an integration test in the same commit.

---

## Section 1. Correctness & safety fixes (from the July 2026 review) — tasks 1-28

### The three headline issues

1. **Basal modeled as un-opposed glucose-lowering force (no EGP term)** — cancels
   corrections to ~0 in the advisor (under-dosing highs) and scores a well-tuned
   user as maximally insulin-resistant, poisoning every learned label. One fix:
   model insulin effect from *net* insulin (boluses + basal deviation from
   schedule), treating scheduled basal as EGP-neutral. → P0-2/P0-3 (TASK-2/3).
2. **At-rest encryption is theater** — the SQLCipher passphrase sits in plaintext
   SharedPreferences next to the ciphertext, while comments/README claim Keystore.
   → P1-1 (TASK-8).
3. **Events duplicate; fingersticks corrupt the CGM series** — no dedupe on
   bolus/carb/basal inserts (inflates IOB/TDD used for advice); meter readings are
   indistinguishable from sensor rows and can overwrite them. → P1-2/P1-3 (TASK-9/10).

P0 fixes (dosing math) are TASK-1..7; P1 (data integrity, security, reliability)
TASK-8..16; P2 (robustness, ML honesty, cleanups) TASK-17..28. Per-fix detail,
file references and status live on the tasks.

### Testing & validation principles (from the review)

Repository tests against in-memory `NativeDatabase` (upsert, reconciliation,
dedupe); `ingestSnapshot` restart/dedupe test; ML honesty metrics (coverage + bias)
as first-class; drift schema-export + migration tests **before** schema v3; a
build-failing check that `request.control` is never imported natively (TASK-41).
For end-to-end **device** coverage without hardware — pairing, decode, reconnect,
alert-from-real-BLE — see the **software pump** (TASK-83), a virtual t:slim X2 BLE
peripheral.

---

## Section 2. Finish what's started (device verification — Phase 4) — tasks 29-34

Gemma nutrition-label AI verification (TASK-29), Accu-Chek meter field test
(TASK-30), Garmin complication + on-watch verification (TASK-31/32), pump pairing
reliability (TASK-33), mood-logging decision (TASK-34). Sequence within the track
(decided earlier, still right): Gemma scanner → meter → Garmin → pump. Each is
"prepare build + exact test procedure → run on device → report → fix".

**Pump pairing history (2-5):** JPAKE pairing verified end-to-end on a real
t:slim X2 (Jul 2026) after two fixes that blocked all JPAKE pumps: (a) pairing
scheme defaulted to 16-char challenge, never JPAKE 6-digit (`PumpCommHandler.start`
now selects `SHORT_6CHAR` when no derived secret is cached); (b) `submitPairingCode`
only called pumpx2 `pair()` when a CentralChallenge was present, but JPAKE supplies
none — now always calls `pair()`.

---

## Section 3. Architecture & design changes — tasks 35-45 (+ code health 101-115)

_From the 2026-07-06 structural survey (162 files / ~33.9k lines). What's healthy:
`core` is genuinely foundational (67 importers, zero imports), `analytics/` fully
pure, one layering violation in the whole tree, clean `PumpSource` ↔ simulator
seam, everything through Riverpod (no service locator), no upward/circular deps.
The debt concentrates in three compounding places: the providers god file, static
KV state, and widget-tree-bound aliveness._

- 3.A Split `providers.dart` + `PersistedStateNotifier` → TASK-35 (anchor refactor)
- 3.B `KvStore` behind the DI seam → TASK-36
- 3.C Decouple aliveness from the widget tree → TASK-37 (staged; 🔒)
- 3.D Error-handling & logging discipline + ring buffer → TASK-38
- 3.E Inject the clock → TASK-39
- 3.F Restore `ml/` purity → TASK-40
- 3.G Architecture guard test → TASK-41
- 3.H Data-layer hardening → TASK-42
- 3.I Native boundary tidy-up → TASK-43
- 3.J Dependency & dead-code hygiene → TASK-44 (done ✅)
- 3.K Test architecture → TASK-45
- 3.L Code-health pass (2026-07-06 survey) → TASK-101..115

For "What NOT to change" (layering, PumpSource seam, hand-written Riverpod, pure
analytics/ml, integration harness) see **decision-4** in `backlog/decisions/`.

---

## Section 4. Feature backlog — tasks 46-83

- 4-1 Forecasting core → TASK-46..55 (quantile bands, conformal calibration,
  meal detection, overnight low, exercise, warm start, 15-min horizon, robust ROC,
  absorption learning, walk-forward + model history). Prerequisite for all:
  P0-2 / TASK-2 (enforced as dependencies).
- 4-2 Alert & insight surfaces consuming forecasts → TASK-56..60.
- 4-3 Data foundation → TASK-61..64 (Nightscout follower, retention,
  fingerstick merge, Libre/Dexcom-share).
- 4-4 Beyond forecasting → TASK-65..69 (free-text meal, Q&A, mood correlation,
  clinic prep, weekly digest).
- 4-5 Pump mirror & device features (from the Jul 2026 live-pump Protocol
  Explorer sweep; opcodes + captured cargo in `doc/pump-protocol.md`) →
  TASK-70..77. Sequence: Pump Mirror screen first, then settings/limits mirrors,
  then the safety monitor, then diagnostics.
- 4-6 Developer / debugging screens (debug-build-gated Developer menu) →
  TASK-78..82.
- 4-7 Software pump — virtual t:slim X2 BLE peripheral (test infrastructure;
  never exposes CONTROL characteristics) → TASK-83.

"Top 5 if only five get built" (2026-07-06): overnight-low forecast (TASK-49) ·
quantile bands + coverage (TASK-46) · unannounced-meal detection (TASK-48) ·
population warm start (TASK-51) · free-text meal → macros (TASK-65).

---

## Section 5. Panel-scanner LLM plan — tasks 84-91

Ordered by safety value; items 1-3 were pure Dart and landed first (TASK-84/85/86
done ✅): number validation in the parser, OCR-grounding check, confidence
comparison fix. Remaining: few-shot prompt + self-check (TASK-87), model
integrity & resource gating (TASK-88), OCR script scope decision (TASK-89),
deterministic column reconstruction (TASK-90), LoRA fine-tune (TASK-91).

---

## Section 6. Remaining polish & infrastructure — tasks 92-100

Prediction validation on real data (TASK-92), alert quality pass (TASK-93), data
integrity edges (TASK-94), reliability (TASK-95), first-run polish (TASK-96), git
remote + push (TASK-97 done ✅), golden/screenshot tests (TASK-98), release path
(TASK-99), user-guide privacy note (TASK-100 done ✅).

---

## Open questions (as of archive)

1. **What's the #1 goal right now** — rock-solid daily driver on real hardware
   (Phases 0-4 as written), or pull forward the forecasting features (Phase 5)?
2. **How often is hardware time available?** Sets the cadence of the Phase 4 track.
3. **Which LLM feature after the scanner** — free-text meal→carbs (TASK-65) is the
   staff pick; Q&A / NL quick-log / explanations remain candidates.
4. **Dream features not listed?** (voice, specific integrations, particular
   reports, automation…)

_Answered previously: audience = personal (Summer); neural forecaster = no,
committed to the GBM._
