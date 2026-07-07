---
id: TASK-111
title: Centralize cross-language string contracts + contract tests
status: Done
assignee: []
created_date: '2026-07-06 04:56'
updated_date: '2026-07-06 13:06'
labels:
  - code-health
  - native
  - testing
milestone: m-8
dependencies: []
priority: medium
ordinal: 105200
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
- [x] #1 Dart channel/key constants defined once and imported by all Dart call sites; Kotlin side reads from a single PumpChannels/keys object
- [x] #2 Contract test: the Dart snapshot parser accepts a golden MutableSnapshot.toJson() fixture (checked-in JSON produced by the Kotlin test suite)
- [x] #3 Contract test: widget prefs key sets asserted equal between the Dart service and a checked-in list matching BgWidgetProvider.kt
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

Implemented all three ACs. AC#1: lib/pump/channels.dart (PumpChannels.events/commands) + lib/widget/widget_keys.dart (WidgetKeys) define the Dart constants once; pump_client, history_backfill and home_widget_service migrated. Kotlin: new PumpChannels object + WidgetKeys object as the single source; PumpBridge and BgWidgetProvider reference them. AC#2: checked-in golden test/contracts/mutable_snapshot_golden.json — Dart contracts_test parses it via PumpSnapshot.fromJson (field-by-field), and Kotlin SnapshotContractTest asserts MutableSnapshot.toJson() (timestamp normalized) equals the golden AND cross-checks the checked-in file. AC#3: Dart contracts_test + Kotlin ChannelContractTest both assert WidgetKeys == {bg_text,bg_trend,bg_unit,iob_text,bg_range,cgm_epoch_ms} and the channel names. flutter analyze/test (519) + gradlew :app:testDebugUnitTest green; APK builds. SCOPE: Garmin payload keys (BgData.mc/GarminSender.kt) were noted in Background but not covered by any AC — left as a possible follow-up.
<!-- SECTION:NOTES:END -->
