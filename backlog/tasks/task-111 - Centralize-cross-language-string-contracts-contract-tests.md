---
id: TASK-111
title: Centralize cross-language string contracts + contract tests
status: To Do
assignee: []
created_date: '2026-07-06 04:56'
labels:
  - code-health
  - native
  - testing
dependencies: []
priority: medium
ordinal: 111000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The Dart/Kotlin/Monkey C boundaries repeat magic strings in 3+ places each, kept in sync only by comments:

- **Channel names** — `bgdude/pump_events` / `bgdude/pump_commands` hardcoded in pump_client.dart:24-25, again in history_backfill.dart:22, and in PumpBridge.kt:193-194
- **Snapshot JSON keys** — MutableSnapshot.toJson() (Kotlin) mirrored by hand in pump_snapshot.dart
- **Home-widget prefs keys** — home_widget_service.dart:36-41 (bg_text, bg_trend, bg_unit, iob_text, bg_range, cgm_epoch_ms) must match BgWidgetProvider.kt
- **Garmin payload keys** — BgData.mc:21-29 mirror the map keys built in GarminSender.kt

**Reason for change.** A typo on either side fails silently at runtime (dead EventChannel, blank widget, dropped snapshot field) — invisible to the compiler and to current tests.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Dart channel/key constants defined once and imported by all Dart call sites; Kotlin side reads from a single PumpChannels/keys object
- [ ] #2 Contract test: the Dart snapshot parser accepts a golden MutableSnapshot.toJson() fixture (checked-in JSON produced by the Kotlin test suite)
- [ ] #3 Contract test: widget prefs key sets asserted equal between the Dart service and a checked-in list matching BgWidgetProvider.kt
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add lib/pump/channels.dart (or core/contracts.dart) consts; migrate pump_client + history_backfill.
- Add a Kotlin object for channel names + widget keys; migrate PumpBridge/BgWidgetProvider.
- Generate the golden MutableSnapshot JSON from the existing Kotlin test and check it in; Dart test parses it.
- Note: TASK-43 already plans to route the backfill channel through PumpClient — do these together.
- flutter test + gradlew :app:testDebugUnitTest green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: code-health survey 2026-07-06 (test finding 4)
- Effort: M
- Related: TASK-43 (native boundary tidy-up)
<!-- SECTION:NOTES:END -->
