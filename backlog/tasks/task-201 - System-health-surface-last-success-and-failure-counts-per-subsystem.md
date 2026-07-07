---
id: TASK-201
title: 'System-health surface: last-success and failure counts per subsystem'
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:10'
updated_date: '2026-07-07 17:00'
labels:
  - code-health
  - insights
  - logging
milestone: m-8
dependencies: []
priority: medium
ordinal: 111500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Recurring background failures have no user-visible signal — startup jobs (`lib/providers.dart:1770`), health sync, nightly training, prediction reconciliation, weather (`lib/providers.dart:1040-1044`), Garmin delivery (`android/app/src/main/kotlin/com/bgdude/app/garmin/GarminSender.kt:44-91`), and model download (`lib/panel_model_manager.dart:44-46`) all funnel to appLog only; grep confirms no aggregate status screen exists. The app keeps showing forecasts built on stale health context or an untrained model with nothing amiss.

- Pump disconnect IS surfaced (ConnectionAlertService) and stale-while-connected is TASK-176 — this ticket is the other subsystems

**Value.** The user can see at a glance which background subsystems are healthy, and notice silent recurring failures before they degrade forecasts.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A lightweight status surface (Advanced or Settings) shows last-success timestamp and failure count per subsystem: health sync, training, reconciliation, Garmin, weather, model download
- [x] #2 Subsystems report through a small shared recorder (feeds from TASK-123 outcomes where available)
- [x] #3 Test: force one subsystem to fail, the surface reflects it
- [x] #4 User guide updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a small shared health recorder (per-subsystem last-success timestamp + failure count), persisted
- Wire the six subsystems (health sync, training, reconciliation, Garmin, weather, model download) to report outcomes, reusing TASK-123 outcome plumbing where available
- Add a lightweight status surface under Advanced or Settings rendering the recorder state
- Add a test forcing one subsystem to fail and asserting the surface reflects it
- Update `doc/user-guide.html` (and `doc/index.html` if needed) for the new surface
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (dart finding 6)
- Effort: M
- Where: `lib/providers.dart`, `lib/panel_model_manager.dart`, new status surface under Settings/Advanced
- Related: TASK-123, TASK-81 (raw dev log), TASK-140 (data census — different)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 16:38
---
Started: reviewing runStartup's StartupJob/StartupReport plumbing (TASK-123) plus the 6 named subsystems (health sync, training, reconciliation, Garmin, weather, model download) to design a shared per-subsystem health recorder + status surface.
---

author: Claude
created: 2026-07-07 17:00
---
Built the full surface. lib/insights/system_health.dart: pure-Dart Subsystem enum (6 values) + SubsystemHealth (lastSuccessAt, consecutiveFailures -- resets on any success, so it measures a SUSTAINED problem not lifetime error count -- lastError, lastAttemptAt) + SystemHealthReport, all with toJson/fromJson. lib/state/providers.dart: SystemHealthNotifier extends PersistedStateNotifier<SystemHealthReport> (key system_health_v1) with recordSuccess/recordFailure/track<T>(subsystem, body) -- track() wraps a call, records the outcome, and RETHROWS on failure so wiring only ADDS observability without changing any existing error-handling behaviour. AC#2: wired via track() -- syncHealth, trainForecaster (outcome.trained==false is NOT a failure, only a thrown exception is), and reconcilePredictions (extracted from an inline runStartup closure into a named AppJobs method) all route through it; weatherProvider wraps its fetch directly (a non-200-swallowed-to-null from WeatherService.current is treated as a failure since s.ready already confirmed a location is configured); PanelModelController.download needed a constructor change (now takes ref) to reach the recorder. Garmin delivery is native (GarminSender.kt) and reports through a NEW, separate path: added in-memory lastSuccessAtMs/consecutiveFailures fields updated in the sendMessage callback (IQMessageStatus.SUCCESS vs anything else) and the three catch blocks (a paired-but-empty device list is left untouched -- normal, not a failure), exposed via GarminIntegration.health() -> a new 'garminHealth' case on PumpBridge's existing command MethodChannel -> PumpSource.garminHealth() (both PumpClient and SimulatedPumpClient implement it) -> a new autoDispose garminHealthProvider fetched fresh each screen visit, since GarminSender tracks it in-memory only (resets on restart) rather than through the persisted recorder -- documented this asymmetry clearly in the screen and the doc comments. New lib/ui/system_health_screen.dart (reached from Advanced -> 'System health', wired through the TASK-127 AppRoutes registry) renders all 6 rows, red when unhealthy. AC#3 test: test/system_health_provider_test.dart forces Subsystem.weather to throw via track(), asserts the rethrow still happens (callers see no behaviour change) AND the report shows consecutiveFailures=1/lastError set/other subsystems untouched; a second test shows a later success resets the streak; a third confirms persistence across a rebuilt container. Also test/system_health_test.dart (11 pure-model tests) and android/.../GarminSenderTest.kt (2 Robolectric tests covering health()'s default shape -- full send()-outcome-recording isn't unit-testable without a larger GarminSender dependency-injection refactor to swap in a fake ConnectIQ, which is a bigger change than this ticket's ask; noted this boundary rather than skipping it silently). Added a features_settings_test.dart integration test (System health screen opens, all 6 rows render) -- written and desk-verified (flutter analyze) but not run on-device per the documented emulator connectivity limitation in this sandboxed session. flutter analyze clean, build_runner succeeded, flutter test test/ green (978 tests), gradlew :app:testDebugUnitTest green (77 tests, 0 failures), flutter build apk --debug succeeded. doc/user-guide.html's Advanced section updated with the new System health entry.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
