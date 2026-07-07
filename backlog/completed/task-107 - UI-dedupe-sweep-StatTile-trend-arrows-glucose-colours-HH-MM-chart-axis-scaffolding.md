---
id: TASK-107
title: >-
  UI dedupe sweep: StatTile, trend arrows, glucose colours, HH:MM, chart axis
  scaffolding
status: Done
assignee: []
created_date: '2026-07-06 04:54'
updated_date: '2026-07-06 13:59'
labels:
  - code-health
  - cleanup
  - ui
milestone: m-8
dependencies: []
priority: medium
ordinal: 105100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Five presentation helpers are each re-implemented in multiple screens:

- **Stat tiles / key-value rows** — four near-identical private widgets: home_screen.dart:291 `_StatTile`, your_day_panel.dart:76 `_Stat`, insulin_report_screen.dart:160 `_Stat`, glucose_report_screen.dart:147 `_Metric`; plus `KvRow` in ui/widgets/common.dart:9 vs private `_Row` in insulin_report_screen.dart:173
- **Trend arrow glyphs** — bg_widget_format.dart:42-51 `trendArrowChar` duplicated verbatim as `_arrow` in pump_screen.dart:142-151; related trend→text/Icon/threshold mappings scattered in daily_narrative.dart:306, glucose_hero.dart:103, pump_snapshot.dart:147, sim_data.dart:178, core/samples.dart:22
- **Glucose colour scale** — glucose_hero.dart:97-99 maps via GlucoseThresholds, but glucose_report_screen.dart:210-214 and events_journal_screen.dart:105-106 hardcode their own shades
- **HH:MM formatting** — hand-rolled `padLeft` in 8 files (reading_explainer.dart:568, event_builder.dart:229, timeline_screen.dart:199, exercise_mode_screen.dart:155, protocol_explorer_screen.dart:405, report_exporter.dart:239, events_journal_screen.dart:111, glucose_report_screen.dart:361)
- **fl_chart axis scaffolding** — the FlTitlesData hidden-top/right + SideTitles boilerplate repeated in glucose_report_screen.dart:286, therapy_report_screen.dart:135, insulin_report_screen.dart:97, on_board_forecast_chart.dart:92, prediction_chart.dart:113

**Reason for change.** Styling and clinical-colour drift across screens, plus repeated boilerplate that makes every new screen more expensive. A shared-widget module (common.dart) already exists but was not used.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 One shared StatTile in ui/widgets/common.dart; the four private variants and _Row deleted
- [x] #2 pump_screen imports trendArrowChar; trend mappings consolidated as extensions on GlucoseTrend in core/samples.dart
- [x] #3 Shared glucoseColor/band palette keyed off GlucoseThresholds used by hero, TIR bar and journal
- [x] #4 Shared formatHhmm/formatShortDateTime utility replaces the 8 hand-rolled copies
- [x] #5 Shared chart-axis helper (parameterised formatter + reserved size) used by the 5 charts
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Work helper-by-helper (5 sub-passes), each a small mechanical migration with a screenshot sanity check in demo mode.
- Keep visual output identical; this is consolidation, not redesign.
- Extend widget tests only where logic exists (colour thresholds).
- `flutter analyze` clean, `flutter test` green; spot-check screens on the emulator.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: code-health survey 2026-07-06 (lib findings 6, 7, 8, 9, 11)
- Effort: M
- Where: see per-item file lists in the description

Implemented all 5 sub-passes. AC#4: lib/core/time_format.dart (formatHhmm/formatHhmmss/formatShortDateTime) replaced the hand-rolled padLeft copies in reading_explainer, event_builder, timeline_screen, exercise_mode, protocol_explorer, events_journal, glucose_report (report_exporter._fmtDate left — single-file full-date ISO, not a cross-file dup). AC#2: GlucoseTrend.arrow getter in core/samples.dart; bg_widget_format.trendArrowChar delegates, pump_screen uses .arrow. AC#3: lib/ui/widgets/glucose_colors.dart (forMgdl 3-way + 5-band palette) used by hero, TIR bar, journal. AC#1: lib/ui/widgets/common.dart StatTile with StatVariant.{card,panel,metric} replaces home _StatTile, your_day _Stat, insulin _Stat, glucose _Metric (kept insulin _Row — spaceBetween layout distinct from KvRow's fixed-width). AC#5: lib/ui/widgets/chart_axis.dart (hiddenAxis + numericSideTitles) used by all 5 charts. Tests: test/ui_helpers_test.dart (colour thresholds + formatters). flutter analyze clean, 527 unit tests green, reports integration test green on emulator. NOTE: two PRE-EXISTING integration failures in app_test (predict tab / therapy editor) fail on the committed state without these changes too — not caused by this task; fixing separately.
<!-- SECTION:NOTES:END -->
