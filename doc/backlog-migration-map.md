# Backlog.md → GitHub Issues migration map

Migrated 2026-07-11. Every Backlog.md task became a GitHub issue in
`danpowell88/bgdude`; `Done`/archived tasks were migrated closed. Old `task-<id>` branch names
refer to the Backlog IDs below, NOT to issue numbers — new work uses `issue-<n>`
branches. Full task content (description, AC, plan, notes, DoD, comment history)
lives in each issue body.

| Backlog ID | Issue | Title | Status at migration |
|---|---|---|---|
| TASK-1 | #15 | Correction subtracts bolus-only (or net) IOB, not total incl. basal | Done |
| TASK-2 | #16 | Predictor models insulin effect from net insulin (EGP baseline) | To Do |
| TASK-3 | #17 | Autotune & TOD sensitivity compare like-for-like (after P0-2) | To Do |
| TASK-4 | #18 | Advisor/predictor honour configured DIA & insulin peak | Done |
| TASK-5 | #19 | Rescue-carb calc uses bolus-only IOB | Done |
| TASK-6 | #20 | Advisor hard low-guard on current reading + compression-low exclusion | Done |
| TASK-7 | #21 | Ketone/DKA prompt earlier | Done |
| TASK-8 | #22 | DB passphrase → Keystore (flutter_secure_storage) | Done |
| TASK-9 | #23 | CGM calibration flag + source (schema v3); stop fingersticks overwriting sensor rows | Done |
| TASK-10 | #24 | Dedupe bolus/carb/basal inserts; fix _lastBolusTime restart race | Done |
| TASK-11 | #25 | Native EventChannel sink marshalled to the main looper | Done |
| TASK-12 | #26 | BootReceiver: gate on BT permission + auto-reconnect | Done |
| TASK-13 | #27 | Surface DB-open failure instead of silent in-memory swap | Done |
| TASK-14 | #28 | Alerts survive engine death (staged; see TASK-37) | To Do |
| TASK-15 | #29 | Replace silent catch(_) with logged catches; do not advance _lastFired on failed urgent-low | Done |
| TASK-16 | #30 | Model-download security (reject HTTP, host allowlist, SHA-256, no token echo) | Done |
| TASK-17 | #31 | Honest intervals: bias correction + coverage reporting + quantile tails | Done |
| TASK-18 | #32 | Purged/blocked walk-forward validation | To Do |
| TASK-19 | #33 | Promotion gate skips hypo criterion on hypo-free tails | Done |
| TASK-20 | #34 | Regularize/early-stop the GBM | To Do |
| TASK-21 | #35 | Sensitivity model validation: sign-constrained coefficients; only adopt if beats heuristic | Done |
| TASK-22 | #36 | Dead constant sensitivity feature removed | Done |
| TASK-23 | #37 | Health-feature look-ahead leak + _activityAt binary search | Done |
| TASK-24 | #38 | Garmin: real delta + plumb display unit | Done |
| TASK-25 | #39 | Report providers watch the repository; re-scan pending confirmations on new CGM | Done |
| TASK-26 | #40 | Clarke grid: optional Parkes/consensus grid | Done |
| TASK-27 | #41 | Panel parser quirks + LLM-gate fix | Done |
| TASK-28 | #42 | Split providers.dart + PersistedStateNotifier base | To Do |
| TASK-29 | #43 | Nutrition-label AI (Gemma) — verify on-device inference | To Do |
| TASK-30 | #44 | Bluetooth meter (Accu-Chek Guide Me) — field test | To Do |
| TASK-31 | #45 | Garmin complication — implement the real publisher | Blocked |
| TASK-32 | #46 | Garmin on-watch verification + current-gen devices | To Do |
| TASK-33 | #47 | Pump pairing robustness (pumpx2) — reliability pass | Blocked |
| TASK-34 | #48 | Mood logging — make it do something or declare journal-only | Done |
| TASK-35 | #49 | Split providers.dart + PersistedStateNotifier | To Do |
| TASK-36 | #50 | KvStore behind the DI seam | To Do |
| TASK-37 | #51 | Decouple aliveness from the widget tree | To Do |
| TASK-38 | #52 | Error-handling & logging discipline + on-device log ring buffer | Done |
| TASK-39 | #53 | Inject the clock | To Do |
| TASK-40 | #54 | Restore ml/ purity | Done |
| TASK-41 | #55 | Architecture guard test (+ read-only-pump check) | Done |
| TASK-42 | #56 | Data-layer hardening (schema tests, one connection, repo tests, batch reconciliation) | To Do |
| TASK-43 | #57 | Native boundary tidy-up (delete Pigeon stub, route backfill channel, threading fixes) | Done |
| TASK-44 | #58 | Dependency & dead-code hygiene | Done |
| TASK-45 | #59 | Test architecture (fill gaps in order) | To Do |
| TASK-46 | #60 | Honest, asymmetric prediction intervals (quantile GBMs) | To Do |
| TASK-47 | #61 | Conformal calibration of the live band | To Do |
| TASK-48 | #62 | Unannounced-meal detection → live forecast | To Do |
| TASK-49 | #63 | Bedtime / overnight-low forecast | To Do |
| TASK-50 | #64 | Exercise-aware forecasting | To Do |
| TASK-51 | #65 | Population-prior warm start | To Do |
| TASK-52 | #66 | Short-horizon (15-min) forecast for alerting | To Do |
| TASK-53 | #67 | Robust ROC + CGM noise handling (do first in Phase 5) | To Do |
| TASK-54 | #68 | Per-meal absorption learning | To Do |
| TASK-55 | #69 | Walk-forward validation + model history | To Do |
| TASK-56 | #70 | Band trust meter on Predict | Done |
| TASK-57 | #71 | Daily hypo-risk score | Done |
| TASK-58 | #72 | Per-time-of-day alert thresholds | Done |
| TASK-59 | #73 | "Why this forecast" decomposition | To Do |
| TASK-60 | #74 | Exercise-aware / dynamic ISF in the advisor | To Do |
| TASK-61 | #75 | Nightscout follower mode | To Do |
| TASK-62 | #76 | Retention & pruning | Done |
| TASK-63 | #77 | Fingerstick↔CGM merge | To Do |
| TASK-64 | #78 | Libre / Dexcom-share ingestion | To Do |
| TASK-65 | #79 | Free-text meal → macros | To Do |
| TASK-66 | #80 | Ask-your-data Q&A | To Do |
| TASK-67 | #81 | Mood ↔ glucose correlation | Done |
| TASK-68 | #82 | Clinic-visit prep | Done |
| TASK-69 | #83 | Weekly digest | Done |
| TASK-70 | #84 | Pump Mirror screen (HomeScreenMirror) | To Do |
| TASK-71 | #85 | Pump settings mirror (PumpSettings + PumpGlobals) | To Do |
| TASK-72 | #86 | Limits & max-bolus display + advisor sanity bounds | Done |
| TASK-73 | #87 | Control-IQ sleep schedule on the timeline | To Do |
| TASK-74 | #88 | Malfunction / safety monitor (MalfunctionBitmaskStatus) | To Do |
| TASK-75 | #89 | Pump features → adaptive UI (PumpFeaturesV2 + Localization) | To Do |
| TASK-76 | #90 | CGM diagnostics + alert-threshold mirror | To Do |
| TASK-77 | #91 | Reminders mirror | To Do |
| TASK-78 | #92 | Raw message + qualifying-event monitor | To Do |
| TASK-79 | #93 | Connection / BLE state inspector | To Do |
| TASK-80 | #94 | History-log raw viewer | To Do |
| TASK-81 | #95 | On-device log ring buffer (Developer surface) | To Do |
| TASK-82 | #96 | Feature-flag / dev toggles | To Do |
| TASK-83 | #97 | Software pump — virtual t:slim X2 BLE peripheral | To Do |
| TASK-84 | #98 | Validate the LLM's numbers (dosing safety) | Done |
| TASK-85 | #99 | OCR-grounding check (anti-hallucination + injection guard) | Done |
| TASK-86 | #100 | Fix the confidence comparison | Done |
| TASK-87 | #101 | Few-shot prompt + on-device self-check | To Do |
| TASK-88 | #102 | Model integrity & resource gating | To Do |
| TASK-89 | #103 | OCR script support (scope decision) | To Do |
| TASK-90 | #104 | Deterministic column reconstruction | To Do |
| TASK-91 | #105 | Longer-term: LoRA fine-tune of Gemma | To Do |
| TASK-92 | #106 | Prediction validation on real data | To Do |
| TASK-93 | #107 | Alert quality pass | To Do |
| TASK-94 | #108 | Data integrity edges | To Do |
| TASK-95 | #109 | Reliability (foreground service survival, battery, reconnect) | To Do |
| TASK-96 | #110 | First-run polish for real hardware | To Do |
| TASK-97 | #111 | Git remote + push | Done |
| TASK-98 | #112 | Golden/screenshot tests | To Do |
| TASK-99 | #113 | Release path | To Do |
| TASK-100 | #114 | User-guide privacy note | Done |
| TASK-101 | #115 | Split BolusAdvisor.advise() into a pure compute core + presenter | Done |
| TASK-102 | #116 | Dedupe the default asleep-window rule into one shared policy | Done |
| TASK-103 | #117 | Centralize clinical threshold constants (low gate, alert defaults, morning window) | Done |
| TASK-104 | #118 | Add Mgdl.inUnit() and delta helpers; dedupe per-chart unit conversion | Done |
| TASK-105 | #119 | Single TIR band decomposition on GlucoseMetrics | Done |
| TASK-106 | #120 | Extract onboarding gate logic; typed accessors for app flags | Done |
| TASK-107 | #121 | UI dedupe sweep: StatTile, trend arrows, glucose colours, HH:MM, chart axis scaffolding | Done |
| TASK-108 | #122 | Shared test fixture library under test/support/ | Done |
| TASK-109 | #123 | Unit tests for carb_math and event_detectors (currently zero coverage) | Done |
| TASK-110 | #124 | Kotlin unit tests for PumpHistoryMapper and PumpProfileMapper | Done |
| TASK-111 | #125 | Centralize cross-language string contracts + contract tests | Done |
| TASK-112 | #126 | Garmin: shared background-app base + draw helpers in source-common | Done |
| TASK-113 | #127 | Strengthen analyzer lints (stream safety, dynamic calls) and fix fallout | Done |
| TASK-114 | #128 | PumpCommHandler: extract testable history-range and profile-read state machines | Done |
| TASK-115 | #129 | Native/Garmin hygiene: log the swallowed snapshot catch; fix stale test-runner reference | Done |
| TASK-116 | #130 | Extract a pure AlertOrchestrator from AlertService | Done |
| TASK-117 | #131 | Report providers: autoDispose + shared range-scoped dataset | Done |
| TASK-118 | #132 | Type HealthSample: metric enum + typed meta | Done |
| TASK-119 | #133 | Adopt the Mgdl type across domain models | Done |
| TASK-120 | #134 | Version the PumpSnapshot JSON + golden contract test | Done |
| TASK-121 | #135 | Make MealLibrary immutable | Done |
| TASK-122 | #136 | Narrow provider watches; share one forecast per snapshot | Done |
| TASK-123 | #137 | Structured StartupJob pipeline for AppJobs.runStartup | Done |
| TASK-124 | #138 | QuickLogService: move illness/mood policy out of the sheet widget | Done |
| TASK-125 | #139 | Handle failures in the app-root snapshot chain | Done |
| TASK-126 | #140 | Move Control-IQ state mapping onto PumpSnapshot | Done |
| TASK-127 | #141 | Typed route registry (decouple settings from the screen graph) | Blocked |
| TASK-128 | #142 | Model persistence hardening: in-blob version, structural validation, atomic save | Done |
| TASK-129 | #143 | Await model restore before training (incumbent race) | Done |
| TASK-130 | #144 | Per-horizon promotion gate | Done |
| TASK-131 | #145 | Local-time contract for time-of-day features (UTC/DST skew) | Done |
| TASK-132 | #146 | Fix residual future-leak in HR feature lookup | Done |
| TASK-133 | #147 | Reconciliation must skip warm-up and compression-low artifacts | Done |
| TASK-134 | #148 | Replace O(n²) scans in overnight training with sorted lookups | Done |
| TASK-135 | #149 | Enforce weighted minimum leaf mass in GBM splits | Done |
| TASK-136 | #150 | Single source for the widening-band fallback sigma | Done |
| TASK-137 | #151 | Shared per-step sensitivity-attribution kernel | Done |
| TASK-138 | #152 | Model-drift detection and retrain trigger | Done |
| TASK-139 | #153 | Advisory ISF/CR suggestions from the learned sensitivity profile | To Do |
| TASK-140 | #154 | Training-data census on the diagnostics screen | Done |
| TASK-141 | #155 | CGM fault detectors: jump, flatline, dropout | Needs Review |
| TASK-142 | #156 | GBM permutation feature importance | Needs Review |
| TASK-143 | #157 | Predicted hypo/hyper duration on Predict | Needs Review |
| TASK-144 | #158 | Rescue-carb and ketone alerts must bypass quiet hours | Done |
| TASK-145 | #159 | Fix weekly-digest notification collision and category routing | Done |
| TASK-146 | #160 | Shared resistance-overlay helper on SensitivityContext | Done |
| TASK-147 | #161 | EffectiveLowThreshold: one composed low-line policy | Done |
| TASK-148 | #162 | Insulin report: separate Control-IQ auto-boluses from manual corrections | Done |
| TASK-149 | #163 | Produce siteFailure confirmations from StubbornHighDetector | Done |
| TASK-150 | #164 | Screen-reader semantics for core surfaces | Done |
| TASK-151 | #165 | Control-IQ behaviour insights (auto-correction load, loop-delivered fraction) | Needs Review |
| TASK-152 | #166 | Infusion-site insights: learned set lifetime from siteFailure + site age | Needs Review |
| TASK-153 | #167 | Learn fat/protein-heavy meals from outcome tails | Needs Review |
| TASK-154 | #168 | Day-type clustering: weekday vs weekend glucose patterns | Needs Review |
| TASK-155 | #169 | Overlay detected events onto report and prediction charts | Needs Review |
| TASK-156 | #170 | Encrypted full-data backup and restore | To Do |
| TASK-157 | #171 | Alert log + alarm-fatigue analytics | To Do |
| TASK-158 | #172 | Predicted-low glance on the home widget and Garmin | To Do |
| TASK-159 | #173 | CI must fail on native-test and coverage regressions | Done |
| TASK-160 | #174 | Reference-pin clinical formulas with independent literals | Done |
| TASK-161 | #175 | Round the bolus suggestion down, not to nearest | Done |
| TASK-162 | #176 | FPU extended-bolus duration: use the published Pankowska table | Done |
| TASK-163 | #177 | Add MARD to model evaluation and the accuracy screen | Needs Review |
| TASK-164 | #178 | Rename the gmi_eA1c_pct export column | Done |
| TASK-165 | #179 | Extract and regression-pin the JPAKE pairing-scheme decision | Done |
| TASK-166 | #180 | Provider-graph regression tests for the demo-toggle rebuild fix | Done |
| TASK-167 | #181 | Integration tests must assert displayed numbers, not labels | Done |
| TASK-168 | #182 | Property tests: band ordering, COB conservation, aggregate IOB monotonicity | Done |
| TASK-169 | #183 | Boundary tests at the clinical thresholds | Done |
| TASK-170 | #184 | Anchor time-dependent tests to fixed instants | Done |
| TASK-171 | #185 | MealDetector negative case: rise explained by IOB | Done |
| TASK-172 | #186 | Automatic KvStore test isolation | Done |
| TASK-173 | #187 | MutableSnapshotTest: parse-based round-trip assertions | Done |
| TASK-174 | #188 | Autotune case with model-independent ground truth | Done |
| TASK-175 | #189 | Set tz.local — scheduled notifications currently fire in UTC | Done |
| TASK-176 | #190 | Stale-data watchdog: alert when readings stop while connected | Done |
| TASK-177 | #191 | Widget must re-render (and grey out) when the Flutter engine dies | Done |
| TASK-178 | #192 | Sticky service restart must resume the pump connection | Done |
| TASK-179 | #193 | Cap DayHistoryController CGM list; roll the day at local midnight | Done |
| TASK-180 | #194 | Guard notification init so a plugin failure cannot brick startup | Done |
| TASK-181 | #195 | Guard snapshot decode in PumpClient so one bad event cannot stall the stream | Done |
| TASK-182 | #196 | Exact alarm for the pre-bolus timer | Done |
| TASK-183 | #197 | Battery-optimization exemption prompt in onboarding | Done |
| TASK-184 | #198 | Monotonic alert cooldowns (DST/clock-change safe) | Done |
| TASK-185 | #199 | Set busy_timeout on the encrypted DB connections | Done |
| TASK-186 | #200 | Robolectric lifecycle tests for PumpService | Done |
| TASK-187 | #201 | Global crash capture: zoned errors, Flutter errors, native uncaught handler | Done |
| TASK-188 | #202 | Harden every KV restore path against corrupt JSON | Done |
| TASK-189 | #203 | Guard the pumpx2 BLE callback bodies so one throw cannot kill the service | Done |
| TASK-190 | #204 | NaN and Infinity guards at the metrics and chart boundary | Done |
| TASK-191 | #205 | Fix unsafe empty-iterable operations (meter transport firstWhere) | Done |
| TASK-192 | #206 | DB corruption and wrong-key recovery flow | Done |
| TASK-193 | #207 | Hostile-input corpus tests for persisted and external parsers | Done |
| TASK-194 | #208 | Crash-restart recovery simulation tests | To Do |
| TASK-195 | #209 | Chaos navigation and large-history stress tests | To Do |
| TASK-196 | #210 | Guard the home-widget receiver so a render throw cannot kill the pump service | Done |
| TASK-197 | #211 | Wire illness/medication mode auto-expiry (currently never expires, survives restarts) | Done |
| TASK-198 | #212 | Acknowledge persisted-state writes; surface failed therapy-settings saves | Done |
| TASK-199 | #213 | Handle database downgrade (older APK over newer schema) | Done |
| TASK-200 | #214 | Persist the announced exercise session across restarts | Done |
| TASK-201 | #215 | System-health surface: last-success and failure counts per subsystem | Done |
| TASK-202 | #216 | PumpService.onDestroy: tear down BLE handler and Garmin SDK | Done |
| TASK-203 | #217 | Tappable native notifications (contentIntent with FLAG_IMMUTABLE) | Done |
| TASK-204 | #218 | Clean up partial model downloads; re-verify installed state | Done |
| TASK-205 | #219 | Submit pairing code off the main thread | Done |
| TASK-206 | #220 | Guard persisted-store parsers outside providers.dart (enum drift, corrupt blobs) | Done |
| TASK-207 | #221 | Per-row meta decode guard in HistoryRepository.health() | Done |
| TASK-208 | #222 | Plugin-call guard sweep: health sync tap, home-widget hot path, Garmin unit push, weather casts, OCR placement | Done |
| TASK-209 | #223 | mounted guards on meter-screen async callbacks | Done |
| TASK-210 | #224 | Shared fault-injection test doubles | Done |
| TASK-211 | #225 | Failure-injection tests for the alert loop | Done |
| TASK-212 | #226 | Failure-injection tests for the app-root snapshot chain | Done |
| TASK-213 | #227 | runStartup per-dependency failure tests | Done |
| TASK-214 | #228 | External-service throw-path degradation tests (LLM, OCR, Nightscout) | Done |
| TASK-215 | #229 | Refresh doc/index.html overview (stale demo facts, missing landed features) | Done |
| TASK-216 | #230 | User-guide currency nits (Models cards, exercise alert muting, table/screenshot fixes) | Done |
| TASK-217 | #231 | SETUP.md: complete the new-developer path | Done |
| TASK-218 | #232 | CI: cache Gradle dependencies | Done |
| TASK-219 | #233 | CI emulator job: run the functional integration suite nightly | Done |
| TASK-220 | #234 | Deterministic demo seam + integration-test isolation | Blocked |
| TASK-221 | #235 | Scriptable simulator scenarios for on-device alert flows | To Do |
| TASK-222 | #236 | Notification-posting assertion harness | To Do |
| TASK-223 | #237 | Device-config test matrix: API levels + dark/font-scale/small-screen variants | To Do |
| TASK-224 | #238 | Health Connect fake-data integration test (API 34 emulator) | To Do |
| TASK-225 | #239 | Camera OCR panel-scan e2e via the emulator virtual-scene camera | To Do |
| TASK-226 | #240 | Fix BLE scanning below API 31: request ACCESS_FINE_LOCATION at runtime | Blocked |
| TASK-227 | #241 | Lower minSdk 29 -> 26 (document the floor rationale) | To Do |
| TASK-228 | #242 | Edge-to-edge readiness (targetSdk is already 37 — Android 15+ enforces it) | To Do |
| TASK-229 | #243 | 16 KB page-size native-library alignment audit | Done |
| TASK-230 | #244 | Stale-data watchdog must gate on connection stage (contradicts connection-lost alert) | Done |
| TASK-231 | #245 | Feed the composed low-line into the alert cycle (stop re-deriving it) | Done |
| TASK-232 | #246 | Pin the empty-CGM kernel guard + degenerate-input tests for all kernel consumers | Done |
| TASK-233 | #247 | Add .gitattributes and normalize line endings once | To Do |
| TASK-234 | #248 | Fix failing integration test: advanced/model internals screen renders sections | Done |
| TASK-235 | #249 | Fix the three sibling tap-miss sites; extract a tapListTile helper | Done |
| TASK-236 | #250 | Cancel the widget staleness alarm (armed forever, cancel method is dead code) | Done |
| TASK-237 | #251 | Extend the wall-clock test guard to integration_test/ and support files | Done |
| TASK-238 | #252 | Native follow-ups: widget unit fallback + restart-policy parameter honesty | Done |
| TASK-239 | #253 | Prompt to grant exact-alarm permission when the pre-bolus timer is gated | Done |
| TASK-240 | #254 | Garmin visual-regression screenshot testing across the device matrix | To Do |
| TASK-240.1 | #255 | Deterministic multi-device Garmin simulator capture harness | To Do |
| TASK-240.2 | #256 | Approved-baseline pixel comparison with tolerance and diff output | To Do |
| TASK-240.3 | #257 | Wire Garmin visual-regression into the test run + document, and grow the device matrix | To Do |
| TASK-241 | #258 | Phone visual-regression: approval-diff screenshots across the Android-version and screen-size matrix | To Do |
| TASK-242 | #259 | GitHub Actions workflow to build and publish Connect IQ packages | Needs Review |
| TASK-243 | #260 | Strengthen read-only pump guard to catch fully-qualified and sendCommand writes | Done |
| TASK-244 | #261 | Gate the sign-constrained sensitivity model on the model actually deployed | Done |
| TASK-245 | #262 | Add Parkes lower-zone under-prediction reference-point tests | Blocked |
| TASK-246 | #263 | Verify or strip the auth token on cross-host redirect in model download | Done |
| TASK-247 | #264 | Guard the reading-explainer ISF division with safeDivide | Done |
| TASK-248 | #265 | Add a negative-case test for the predictor NaN/Infinite forecast clamp | Done |
| TASK-249 | #266 | DB recovery reset must not delete an intact file on a key-mismatch verdict (data-loss) | Done |
| TASK-250 | #267 | Hostile-input corpus must assert output invariants, not just absence of throw | Done |
| TASK-251 | #268 | Fix hollow assertions in the crash-restart recovery tests | Done |
| TASK-252 | #269 | Test the DB reset file deletion and recovery-screen destructive gate, add on-device coverage | Done |
| TASK-253 | #270 | Fix DB-open error copy: recovery is via the banner not Settings; guard KvStore on corrupt DB | Done |
| TASK-254 | #271 | Gate the DB integrity scan so quick_check does not run a full decrypt on every launch | Done |
| TASK-255 | #272 | Extend the hostile-input corpus to the remaining KvStore decoders | Done |
| TASK-256 | #273 | Add a mid-write interruption scenario to the restart harness | Done |
| TASK-257 | #274 | Chaos-nav integration test asserts on a crash log its harness never populates | Blocked |
| TASK-258 | #275 | IllnessModeNotifier.lastDeactivationAnnotation is set but never persisted to the history repository | Done |
| TASK-259 | #276 | persist() failure must not latch _hasLocalWrite and suppress the pending restore | Done |
| TASK-260 | #277 | Illness/medication persist failure leaves in-memory dosing state diverged from the UI | Done |
| TASK-261 | #278 | Surface illness and medication auto-expiry to the user with a notification and log line | Done |
| TASK-262 | #279 | PumpService.onDestroy double-closes the BLE central and never resets the pumpx2 handler singleton | Done |
| TASK-263 | #280 | Strengthen PumpService destroy and notification-intent test assertions | Done |
| TASK-264 | #281 | Garmin health should track per-target so a not-installed watch face or data field does not flap the row | Done |
| TASK-265 | #282 | System-health rows should go stale when last-success exceeds a subsystems expected cadence | Done |
| TASK-266 | #283 | Use a neutral unknown indicator not a green check for never-run subsystems on the system-health screen | Needs Review |
| TASK-267 | #284 | Fix concurrency and lifecycle gaps introduced by off-main pairing I/O | Done |
| TASK-268 | #285 | Bounds-guard the AnnotationKind index decode in HistoryRepository.annotations() | Done |
| TASK-269 | #286 | Close the remaining parser-guard gaps from the TASK-206/208 sweep | Done |
| TASK-270 | #287 | Two app-root snapshot-chain containment sub-tests are hollow and prove no containment | Done |
| TASK-271 | #288 | Complete the pre-31 BLE permission flow: location-services check and permanent-denial deep-link | Done |
| TASK-272 | #289 | Route the demo meal-library seed through demoClockProvider to complete the determinism seam | Done |
| TASK-273 | #290 | PumpSnapshot hardening skips the glucose reading and dosing fields — the safety-critical ones | Done |
| TASK-274 | #291 | CI is red: line coverage 58.6% is below the 60% gate | Done |
| TASK-275 | #292 | Restore dropped line coverage and lock it in by raising the CI floor | Done |
| TASK-276 | #293 | Reorganise the test suite by feature with a consistent AAA or Given-When-Then structure | Blocked |
| TASK-277 | #294 | PumpCommHandler pairing-timeout field is not thread-safe -- orphaned scan timeout can tear down an active connection | Done |
| TASK-278 | #295 | Bound the post-pairing-code bonding and authentication phase with a timeout | Done |
| TASK-279 | #296 | tapListItem has the same TASK-234 tap-miss gap as tapListTile did | Done |
| TASK-280 | #297 | AppBar title Row overflows in demo mode on a narrow screen | Done |
| TASK-281 | #298 | Quick-log sheet overflows vertically on a real device/emulator | Done |
| TASK-282 | #299 | Meals-tab tap-miss on a saved meal tile (app_test.dart:267) | Done |
| TASK-283 | #300 | 'Clarke error grid' text not found on the Advanced screen (app_test.dart:315) | Done |
| TASK-284 | #301 | Unpair must not freeze a still-present widget -- keep the staleness alarm while a widget exists | Done |
| TASK-285 | #302 | _AddMealSheet form overflows vertically, breaking the Save button's tap target | Done |
| TASK-286 | #303 | Meal-detail coach section check ran before scrolling to it | Done |
| TASK-287 | #304 | Speed up the CI test pipeline: shard the unit tests, parallelise jobs, cache codegen | Done |
| TASK-288 | #305 | Make the test pipeline resilient to network issues: hermetic tests, CI retries, timeouts | Done |
| TASK-289 | #306 | Emulator workflow run 28910537179 was inconclusive (manually cancelled, not a confirmed hang) | Done |
| TASK-290 | #307 | Make the pairing-timeout schedule/cancel mutually atomic -- @Volatile alone still races | Done |
| TASK-291 | #308 | chaos_navigation_test.dart hangs on real device, consuming the full 45-min emulator-workflow timeout | Done |
| TASK-292 | #309 | Emulator suite aborts on the first failing file, hiding signal for every file after it | Done |
| TASK-293 | #310 | Chaos-walk crash-log assertion is still inert -- flutter_test overrides FlutterError.onError | Blocked |
| TASK-294 | #311 | Pump screen Control-IQ row RenderFlex overflow (45px) on real device | Blocked |
| TASK-295 | #312 | features_settings_test.dart: Clarke error grid check missing scroll (sibling of TASK-283) | Blocked |
| TASK-296 | #313 | features_flows_test.dart: what-if explorer Slider drag hit-test miss (sibling of TASK-234) | Blocked |
| TASK-297 | #314 | Shard the CI unit-test job across a matrix | Done |
| TASK-298 | #315 | Cache build_runner output in CI, correctly invalidated on source/pubspec.lock changes | Done |
| TASK-299 | #316 | Regenerate the committed Gradle wrapper -- old vintage of unverifiable provenance, inconsistent with the pinned 8.11.1 | Done |
| TASK-300 | #317 | Model-download redirect must not send the auth token over a cleartext HTTP downgrade | Done |
| TASK-301 | #318 | Harden the sharded CI so it cannot mask a native-test flake or silently drop a test | Done |
| TASK-302 | #319 | Range-clamp persisted decoder numerics on restore -- esp. AlertThresholds mg/dL | Done |
| TASK-303 | #320 | AlertThresholds restore must enforce the urgentLow<low<high ordering -- per-field range alone can still suppress a hypo alert | Done |
| TASK-304 | #321 | Auto-expiry mode-ended notification fires even when the persist failed (mode still active) | Done |
| TASK-305 | #322 | Exercise-announcement notification fires even when the plan failed to persist | Done |
| TASK-306 | #323 | Drift-triggered retrain has no cooldown -- sustained unfixable drift retrains the forecaster every startup | Needs Review |
| TASK-309 | #324 | CI does not run on task-<id> branches, so the review-merge gate can never confirm green | Needs Review |
| TASK-310 | #325 | Review branches are stale and conflicting with main -- rebase before build/merge, and reduce main churn | To Do |
| TASK-311 | #326 | Fix implicit PendingIntents flagged by CodeQL (high severity) in PumpService and WidgetNativePush | To Do |
| TASK-312 | #327 | Disable Android auto-backup of app data (CodeQL java/android/backup-enabled, high) | To Do |
| TASK-313 | #328 | Pin GitHub Actions to commit SHAs (21 CodeQL actions/unpinned-tag warnings) | To Do |
| TASK-HIGH.1 | #329 | CI is red: line coverage 58.6% is below the 60% gate | To Do (archived) |
