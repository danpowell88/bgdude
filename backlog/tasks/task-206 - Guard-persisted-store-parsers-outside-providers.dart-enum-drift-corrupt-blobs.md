---
id: TASK-206
title: >-
  Guard persisted-store parsers outside providers.dart (enum drift, corrupt
  blobs)
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:11'
updated_date: '2026-07-07 17:44'
labels:
  - code-health
  - data-integrity
milestone: m-8
dependencies: []
priority: high
ordinal: 112000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The KV-hardening ticket TASK-188 is scoped to the `_restore()` sites in `lib/providers.dart`, but the same unguarded pattern lives in six other stores: `PumpEventLog.load` (`lib/pump/pump_events.dart:51-55`, `PumpEventKind.values.byName` + `DateTime.parse` + hard casts), `lib/battery_history.dart:24,41`, `lib/pending_confirmation.dart:71,89`, `lib/weather_history.dart:19`, `lib/device_changes.dart:32` (`DeviceKind.values.byName`), and `GlucoseMeterController._restore` (`lib/glucose_meter_controller.dart:73-84`, fire-and-forget from the constructor).

- `enum.byName` throws ArgumentError on any renamed/removed enum value — a permanent AsyncError that breaks the Confirmation Inbox, pump timeline, events journal and battery report screens until the blob is cleared

**Reason for change.** One stale enum name or truncated blob must not permanently break whole screens; loads should degrade to a usable default with a loud log.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Each load is wrapped: a corrupt entry is skipped or yields an empty default, with a loud log
- [x] #2 Every `values.byName(x)` is replaced with `values.asNameMap()[x]` plus fallback handling
- [x] #3 Table-driven test seeds each store with an unknown enum name and truncated JSON and asserts a usable default
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Wrap each of the six store load paths (pump events, battery history, pending confirmation, weather history, device changes, glucose meter controller) with per-entry guards: skip corrupt entries or return an empty default, log loudly
- Replace every `values.byName(x)` with `values.asNameMap()[x]` + explicit fallback
- Add a table-driven test seeding each store with an unknown enum name and truncated JSON, asserting a usable default
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (dart finding 11)
- Effort: S-M
- Where: `lib/pump/pump_events.dart`, `lib/battery_history.dart`, `lib/pending_confirmation.dart`, `lib/weather_history.dart`, `lib/device_changes.dart`, `lib/glucose_meter_controller.dart`
- Related: TASK-188 (same pattern, providers.dart scope)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 17:35
---
Started: locating the 6 named persisted-store parsers (paths in the ticket are stale post-rename) to guard each load path against enum drift and corrupt blobs, matching TASK-188's pattern.
---

author: Claude
created: 2026-07-07 17:44
---
Guarded all 6 named stores. lib/pump/pump_events.dart: PumpEventKind.values.byName -> asNameMap()[...] + explicit throw on unknown, caught per-entry in load() (one bad event no longer loses the whole log); outer jsonDecode also guarded. lib/pump/battery_history.dart: same outer+per-entry guard pattern (no enum, just malformed entries). lib/feedback/pending_confirmation.dart: ConfirmationDecisionStore.load's ALREADY-safe enum lookup (values.where(...).firstOrNull) was fine, but the outer jsonDecode and the per-entry (e.value as Map) cast were not -- both now guarded; also guarded record()'s read-before-write path so a corrupt existing blob can't block recording a NEW decision. lib/weather/weather_history.dart: outer decode + per-entry value cast guarded (record() is transitively safe since it calls the now-guarded loadDaily()). lib/logging/device_changes.dart: DeviceKind.values.byName -> asNameMap()[...] + throw-on-unknown, caught per-entry in DeviceState.fromJson's list comprehension; outer decode in DeviceChangeStore.load guarded too. lib/integrations/glucose_meter_controller.dart: _restore() (fire-and-forget from the constructor, the most exposed of the 6 -- previously an uncaught decode failure would've been an unhandled async error, not even logged) wrapped in try/catch + appLog.error, plus added mounted guards matching the codebase's existing StateNotifier convention. All six log via appLog.error('persistence', ...) rather than full TASK-188 quarantine-to-.corrupt-key -- a proportionate response for secondary caches/history logs per AC#1's literal wording ('skipped or yields a usable default, with a loud log'), reserving quarantine for clinical settings. AC#3: extended test/persisted_state_corruption_test.dart (TASK-188's own table-driven corruption suite) with an 11-test 'TASK-206 stores' group covering every store: a totally-corrupt blob -> empty/default + logged, AND a single malformed/unknown-enum entry among otherwise-valid ones -> skipped, others survive, for each of the 6. flutter analyze clean, flutter test test/ green (994 tests), flutter build apk --debug succeeded. No native Kotlin/screen change -- DoD #5/#6/#7 n/a.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
