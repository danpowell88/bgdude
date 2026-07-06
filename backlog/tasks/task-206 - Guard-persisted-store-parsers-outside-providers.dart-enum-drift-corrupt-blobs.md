---
id: TASK-206
title: >-
  Guard persisted-store parsers outside providers.dart (enum drift, corrupt
  blobs)
status: To Do
assignee: []
created_date: '2026-07-06 21:11'
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
- [ ] #1 Each load is wrapped: a corrupt entry is skipped or yields an empty default, with a loud log
- [ ] #2 Every `values.byName(x)` is replaced with `values.asNameMap()[x]` plus fallback handling
- [ ] #3 Table-driven test seeds each store with an unknown enum name and truncated JSON and asserts a usable default
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

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
