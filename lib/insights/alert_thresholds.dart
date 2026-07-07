/// User-customisable glucose alert thresholds (mg/dL internally). These feed the
/// real-time [AlertMonitor] so the low/high nudges match the user's own targets rather
/// than fixed defaults. Safety modifiers (hypo-awareness, alcohol, exercise) are layered
/// on top of the resolved low line at evaluation time.
///
/// Per-time-of-day (§4-2.3): the top-level [lowMgdl]/[highMgdl]/[urgentLowMgdl] are the
/// "all-day" row. Optional [segments] override them for the overnight window, daytime, or
/// the post-meal window; anything not overridden falls back to the all-day row. This lets
/// you warn earlier overnight and tolerate the expected bump after a meal without nagging.
library;

import '../core/sleep_window.dart';
import '../core/units.dart';

/// The parts of the day a threshold row can apply to. `day` is everything that isn't the
/// overnight window; `postMeal` takes precedence over both while a meal is digesting.
enum AlertSegment { overnight, day, postMeal }

/// One low/high/urgent-low triple, typed [Mgdl] (TASK-119). The constructor takes
/// plain doubles (values arrive from JSON/steppers) and wraps once here.
class AlertBand {
  AlertBand({
    required double lowMgdl,
    required double highMgdl,
    required double urgentLowMgdl,
  })  : lowMgdl = Mgdl(lowMgdl),
        highMgdl = Mgdl(highMgdl),
        urgentLowMgdl = Mgdl(urgentLowMgdl);

  final Mgdl lowMgdl;
  final Mgdl highMgdl;
  final Mgdl urgentLowMgdl;

  AlertBand copyWith({double? lowMgdl, double? highMgdl, double? urgentLowMgdl}) =>
      AlertBand(
        lowMgdl: lowMgdl ?? this.lowMgdl,
        highMgdl: highMgdl ?? this.highMgdl,
        urgentLowMgdl: urgentLowMgdl ?? this.urgentLowMgdl,
      );

  Map<String, dynamic> toJson() =>
      {'low': lowMgdl, 'high': highMgdl, 'urgentLow': urgentLowMgdl};

  /// Missing keys fall back to [fallback] (the all-day row), so a partial override only
  /// changes the fields the user actually set.
  factory AlertBand.fromJson(Map<String, dynamic> j, {required AlertBand fallback}) =>
      AlertBand(
        lowMgdl: (j['low'] as num?)?.toDouble() ?? fallback.lowMgdl,
        highMgdl: (j['high'] as num?)?.toDouble() ?? fallback.highMgdl,
        urgentLowMgdl: (j['urgentLow'] as num?)?.toDouble() ?? fallback.urgentLowMgdl,
      );
}

class AlertThresholds {
  /// Shipped defaults (mg/dL). Referenced by BOTH the constructor and [fromJson] so the
  /// two can't silently drift apart (TASK-103).
  static const double defaultLowMgdl = 70;
  static const double defaultHighMgdl = 200;
  static const double defaultUrgentLowMgdl = 55;

  /// Fields are typed [Mgdl] (TASK-119); the constructor stays const-able by
  /// taking [Mgdl] directly (wrap literals as `Mgdl(80)` at the call site).
  const AlertThresholds({
    this.lowMgdl = const Mgdl(defaultLowMgdl),
    this.highMgdl = const Mgdl(defaultHighMgdl),
    this.urgentLowMgdl = const Mgdl(defaultUrgentLowMgdl),
    this.segments = const {},
  });

  final Mgdl lowMgdl;
  final Mgdl highMgdl;
  final Mgdl urgentLowMgdl;

  /// Per-segment overrides. Empty ⇒ the all-day row applies all day (the migrated state).
  final Map<AlertSegment, AlertBand> segments;

  /// The all-day row as a band.
  AlertBand get allDay => AlertBand(
        lowMgdl: lowMgdl,
        highMgdl: highMgdl,
        urgentLowMgdl: urgentLowMgdl,
      );

  /// The effective band at [at]. A [postMeal] window wins over the time-of-day segment
  /// (a post-meal high can happen overnight too); otherwise overnight vs day is decided by
  /// [defaultAsleepAt]. Segments with no override inherit the all-day row.
  AlertBand resolve({required DateTime at, bool postMeal = false}) {
    if (postMeal) {
      final b = segments[AlertSegment.postMeal];
      if (b != null) return b;
    }
    final seg = defaultAsleepAt(at) ? AlertSegment.overnight : AlertSegment.day;
    return segments[seg] ?? allDay;
  }

  /// Set (or replace) one segment override.
  AlertThresholds withSegment(AlertSegment seg, AlertBand band) =>
      copyWith(segments: {...segments, seg: band});

  /// Remove one segment override (falls back to the all-day row).
  AlertThresholds withoutSegment(AlertSegment seg) =>
      copyWith(segments: {for (final e in segments.entries) if (e.key != seg) e.key: e.value});

  AlertThresholds copyWith({
    double? lowMgdl,
    double? highMgdl,
    double? urgentLowMgdl,
    Map<AlertSegment, AlertBand>? segments,
  }) =>
      AlertThresholds(
        lowMgdl: lowMgdl == null ? this.lowMgdl : Mgdl(lowMgdl),
        highMgdl: highMgdl == null ? this.highMgdl : Mgdl(highMgdl),
        urgentLowMgdl:
            urgentLowMgdl == null ? this.urgentLowMgdl : Mgdl(urgentLowMgdl),
        segments: segments ?? this.segments,
      );

  Map<String, dynamic> toJson() => {
        'low': lowMgdl,
        'high': highMgdl,
        'urgentLow': urgentLowMgdl,
        if (segments.isNotEmpty)
          'segments': {
            for (final e in segments.entries) e.key.name: e.value.toJson()
          },
      };

  /// Migration (§4-2.3 AC#2): old flat JSON (no `segments`) parses into the all-day row
  /// with no overrides, so existing users keep their exact thresholds all day.
  factory AlertThresholds.fromJson(Map<String, dynamic> j) {
    final base = AlertThresholds(
      lowMgdl: Mgdl((j['low'] as num?)?.toDouble() ?? defaultLowMgdl),
      highMgdl: Mgdl((j['high'] as num?)?.toDouble() ?? defaultHighMgdl),
      urgentLowMgdl:
          Mgdl((j['urgentLow'] as num?)?.toDouble() ?? defaultUrgentLowMgdl),
    );
    final segJson = j['segments'] as Map<String, dynamic>?;
    if (segJson == null || segJson.isEmpty) return base;
    final segs = <AlertSegment, AlertBand>{};
    for (final s in AlertSegment.values) {
      final raw = segJson[s.name];
      if (raw is Map<String, dynamic>) {
        segs[s] = AlertBand.fromJson(raw, fallback: base.allDay);
      }
    }
    return base.copyWith(segments: segs);
  }
}
