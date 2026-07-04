/// Pure formatting logic for the Android home-screen BG widget.
///
/// Turns a raw CGM reading (mg/dL + trend + reading age) and IOB into the display
/// strings and range/staleness tokens the widget renders. Kept free of plugin
/// imports so it is unit-testable ([test/home_widget_service_test.dart]); the
/// Kotlin renderer (`BgWidgetProvider.kt`) mirrors the time-dependent parts of
/// these rules so system-triggered re-renders stay consistent.
///
/// Rules:
///   * BG is coloured by range: red below 70 mg/dL, green in range, orange above
///     180 mg/dL (thresholds from [GlucoseThresholds]).
///   * A reading older than [kBgWidgetStaleAfter] (15 min) — or missing entirely —
///     is stale: greyed out and labelled.
library;

import '../core/samples.dart';
import '../core/units.dart';

/// A CGM reading older than this is shown greyed-out with a stale label.
const Duration kBgWidgetStaleAfter = Duration(minutes: 15);

/// Range bucket for widget colouring. [token] is the string persisted for the
/// native renderer — must match the constants in `BgWidgetProvider.kt`.
enum BgRange {
  low('low'),
  inRange('inRange'),
  high('high'),
  unknown('unknown');

  const BgRange(this.token);
  final String token;

  static BgRange fromMgdl(int? mgdl) {
    if (mgdl == null) return BgRange.unknown;
    if (mgdl < GlucoseThresholds.low) return BgRange.low;
    if (mgdl > GlucoseThresholds.high) return BgRange.high;
    return BgRange.inRange;
  }
}

/// Single-character arrow for a CGM trend (empty when unknown).
String trendArrowChar(GlucoseTrend trend) => switch (trend) {
      GlucoseTrend.doubleUp => '⇈',
      GlucoseTrend.singleUp => '↑',
      GlucoseTrend.fortyFiveUp => '↗',
      GlucoseTrend.flat => '→',
      GlucoseTrend.fortyFiveDown => '↘',
      GlucoseTrend.singleDown => '↓',
      GlucoseTrend.doubleDown => '⇊',
      GlucoseTrend.unknown => '',
    };

/// Everything the widget displays, fully formatted.
class BgWidgetData {
  const BgWidgetData({
    required this.bgText,
    required this.trendArrow,
    required this.unitLabel,
    required this.iobText,
    required this.range,
    required this.isStale,
    required this.updatedText,
  });

  /// Glucose in the user's display unit (e.g. '6.2' or '112'), '--' if absent.
  final String bgText;

  /// Trend arrow character, '' when the trend is unknown or BG is absent.
  final String trendArrow;

  /// The display unit's label (e.g. 'mmol/L').
  final String unitLabel;

  /// IOB line, e.g. 'IOB 1.2 U' ('IOB --' when unavailable).
  final String iobText;

  /// Range bucket driving the BG colour (ignored by renderers while stale).
  final BgRange range;

  /// True when the reading is missing or older than [kBgWidgetStaleAfter].
  final bool isStale;

  /// Reading age line, e.g. 'just now', '7m ago', 'Stale · 23m ago', 'no data'.
  final String updatedText;
}

/// Format a snapshot's CGM/IOB fields for the widget.
///
/// [readingAge] is the time elapsed since the CGM reading was taken; pass null
/// when there is no timestamped reading (treated as stale).
BgWidgetData formatBgWidgetData({
  required int? cgmMgdl,
  required GlucoseTrend? trend,
  required double? iobUnits,
  required GlucoseUnit unit,
  required Duration? readingAge,
}) {
  final isStale = readingAge == null || readingAge > kBgWidgetStaleAfter;
  return BgWidgetData(
    bgText: cgmMgdl == null ? '--' : Mgdl(cgmMgdl.toDouble()).display(unit),
    trendArrow: cgmMgdl == null ? '' : trendArrowChar(trend ?? GlucoseTrend.unknown),
    unitLabel: unit.label,
    iobText: iobUnits == null ? 'IOB --' : 'IOB ${iobUnits.toStringAsFixed(1)} U',
    range: BgRange.fromMgdl(cgmMgdl),
    isStale: isStale,
    updatedText: _updatedText(readingAge, isStale),
  );
}

String _updatedText(Duration? age, bool isStale) {
  if (age == null) return 'no data';
  final minutes = age.inMinutes;
  final base = minutes <= 0
      ? 'just now'
      : minutes < 60
          ? '${minutes}m ago'
          : '${age.inHours}h ago';
  return isStale ? 'Stale · $base' : base;
}
