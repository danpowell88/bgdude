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

import '../core/samples.dart';
import '../core/sleep_window.dart';
import '../core/units.dart';

/// TASK-231: whether a carb entry within the last 2h makes [now] "post-meal" for
/// [AlertThresholds.resolve]'s segment selection. The single source of truth for this
/// window — both the alert cycle (`alert_orchestrator.dart`) and the coaching path
/// (`effectiveLowThresholdProvider` in `providers.dart`) call this rather than each
/// re-deriving their own `Duration(hours: 2)` check, so the two can't silently diverge.
bool isPostMealWindow(Iterable<CarbEntry> carbs, DateTime now) => carbs.any(
    (c) => !c.time.isAfter(now) && now.difference(c.time) <= const Duration(hours: 2));

/// The parts of the day a threshold row can apply to. `day` is everything that isn't the
/// overnight window; `postMeal` takes precedence over both while a meal is digesting.
enum AlertSegment { overnight, day, postMeal }

/// TASK-302: a corrupt/tampered stored value that still parses (e.g. urgentLowMgdl =
/// -5, or 1.79e308) must not silently become this app's real alert threshold --
/// AlertThresholds drives real-time low/high/urgent-low firing, so a bad value here
/// could suppress a genuine alert or fire spuriously. REJECT (fall back to
/// [fallback], never clamp toward a fabricated in-range number) outside a plausible
/// THRESHOLD band -- reject-not-clamp rationale as pump_snapshot.dart's
/// _rejectOutOfRangeDouble (TASK-273): clamping -5 to the floor would still be a
/// plausible-looking, actionable threshold for a value that was never legitimately
/// set. TASK-303: tightened from 20-600 (a plausible-BG-READING band, borrowed from
/// pump_snapshot's cgmMgdl bound) to 40-400 -- a THRESHOLD is a value someone
/// deliberately configured, not a raw sensor reading, so it should sit inside a
/// clinically-plausible range, not merely inside "somewhere a CGM could ever report".
double _sanitizeMgdl(double? v, double fallback) =>
    v == null || v.isNaN || v < 40 || v > 400 ? fallback : v;

/// TASK-303: per-field range sanitising ([_sanitizeMgdl]) alone isn't enough -- a
/// corrupt-but-individually-in-range triple (e.g. a persisted low corrupted to 40,
/// which passes the per-field band unchanged, paired with the default urgentLow=55)
/// can still violate urgentLow < low < high. AlertMonitor.evaluate's low branch used
/// to gate the ENTIRE low/urgentLow decision on `minF.mgdl < lowMgdl`, so a lower-
/// than-urgentLow lowMgdl made urgentLow unreachable -- a genuine hypo at ~50 mg/dL
/// would fire NEITHER alert. (AlertMonitor now also evaluates urgentLow
/// independently as defense-in-depth, but this layer -- rejecting a mis-ordered
/// triple at the persistence boundary -- is the one that should normally catch it.)
/// Checked on the fully-sanitised triple, not per-field: a mix of one sanitised
/// value and two untouched defaults could just as easily violate ordering on its
/// own. On violation, the WHOLE triple falls back to [fallbackLow]/[fallbackHigh]/
/// [fallbackUrgentLow] -- never a partial mix that could itself be mis-ordered.
({double low, double high, double urgentLow}) _sanitizeThresholdTriple({
  required double? rawLow,
  required double? rawHigh,
  required double? rawUrgentLow,
  required double fallbackLow,
  required double fallbackHigh,
  required double fallbackUrgentLow,
}) {
  final low = _sanitizeMgdl(rawLow, fallbackLow);
  final high = _sanitizeMgdl(rawHigh, fallbackHigh);
  final urgentLow = _sanitizeMgdl(rawUrgentLow, fallbackUrgentLow);
  if (urgentLow < low && low < high) {
    return (low: low, high: high, urgentLow: urgentLow);
  }
  return (low: fallbackLow, high: fallbackHigh, urgentLow: fallbackUrgentLow);
}

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
  /// changes the fields the user actually set. TASK-302: an out-of-range value (not
  /// just a missing one) falls back the same way -- see [_sanitizeMgdl]. TASK-303: a
  /// mis-ordered triple (even if every field is individually in-range) falls back to
  /// [fallback] entirely -- see [_sanitizeThresholdTriple].
  factory AlertBand.fromJson(Map<String, dynamic> j, {required AlertBand fallback}) {
    final t = _sanitizeThresholdTriple(
      rawLow: (j['low'] as num?)?.toDouble(),
      rawHigh: (j['high'] as num?)?.toDouble(),
      rawUrgentLow: (j['urgentLow'] as num?)?.toDouble(),
      fallbackLow: fallback.lowMgdl,
      fallbackHigh: fallback.highMgdl,
      fallbackUrgentLow: fallback.urgentLowMgdl,
    );
    return AlertBand(lowMgdl: t.low, highMgdl: t.high, urgentLowMgdl: t.urgentLow);
  }
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
  /// with no overrides, so existing users keep their exact thresholds all day. TASK-302:
  /// an out-of-range value (not just a missing one) falls back to the shipped default --
  /// see [_sanitizeMgdl]. TASK-303: a mis-ordered triple falls back to the shipped
  /// defaults entirely -- see [_sanitizeThresholdTriple].
  factory AlertThresholds.fromJson(Map<String, dynamic> j) {
    final t = _sanitizeThresholdTriple(
      rawLow: (j['low'] as num?)?.toDouble(),
      rawHigh: (j['high'] as num?)?.toDouble(),
      rawUrgentLow: (j['urgentLow'] as num?)?.toDouble(),
      fallbackLow: defaultLowMgdl,
      fallbackHigh: defaultHighMgdl,
      fallbackUrgentLow: defaultUrgentLowMgdl,
    );
    final base = AlertThresholds(
      lowMgdl: Mgdl(t.low),
      highMgdl: Mgdl(t.high),
      urgentLowMgdl: Mgdl(t.urgentLow),
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
