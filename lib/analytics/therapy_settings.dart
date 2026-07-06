/// User therapy settings: the parameters that drive dosing math. These mirror the
/// pump's IDP (Insulin Delivery Profile) but are held app-side so the what-if engine
/// and bolus advisor can apply context-based adjustments without touching the pump.
///
/// All glucose values are mg/dL internally.
library;

/// A time-of-day segment with its own targets/ratios (pumps store 1..N of these).
class TherapySegment {
  const TherapySegment({
    required this.startMinuteOfDay,
    required this.isf,
    required this.carbRatio,
    required this.targetMgdl,
    required this.basalUnitsPerHour,
  });

  /// Minutes since local midnight this segment starts at.
  final int startMinuteOfDay;

  /// Insulin Sensitivity Factor: mg/dL drop per unit of insulin.
  final double isf;

  /// Carb ratio: grams of carb covered by one unit.
  final double carbRatio;

  /// Correction target, mg/dL.
  final double targetMgdl;

  final double basalUnitsPerHour;

  Map<String, dynamic> toJson() => {
        'startMinuteOfDay': startMinuteOfDay,
        'isf': isf,
        'carbRatio': carbRatio,
        'targetMgdl': targetMgdl,
        'basalUnitsPerHour': basalUnitsPerHour,
      };

  factory TherapySegment.fromJson(Map<String, dynamic> j) => TherapySegment(
        startMinuteOfDay: (j['startMinuteOfDay'] as num).toInt(),
        isf: (j['isf'] as num).toDouble(),
        carbRatio: (j['carbRatio'] as num).toDouble(),
        targetMgdl: (j['targetMgdl'] as num).toDouble(),
        basalUnitsPerHour: (j['basalUnitsPerHour'] as num).toDouble(),
      );
}

class TherapySettings {
  /// [segments] must be non-empty; `segmentAt` assumes at least one entry.
  const TherapySettings({
    required this.segments,
    this.durationOfInsulinActionMinutes = 360,
    this.maxBolusUnits = 25,
    this.insulinPeakMinutes = 75,
  });

  final List<TherapySegment> segments;
  final int durationOfInsulinActionMinutes;
  final int insulinPeakMinutes;

  /// A safety cap the advisor never exceeds regardless of computed dose.
  final double maxBolusUnits;

  /// Segment active at [time]'s local time-of-day.
  TherapySegment segmentAt(DateTime time) {
    final minuteOfDay = time.hour * 60 + time.minute;
    // Segments are sorted by start; find the last one that has started.
    final sorted = [...segments]
      ..sort((a, b) => a.startMinuteOfDay.compareTo(b.startMinuteOfDay));
    var active = sorted.first;
    for (final s in sorted) {
      if (s.startMinuteOfDay <= minuteOfDay) {
        active = s;
      } else {
        break;
      }
    }
    return active;
  }

  TherapySettings copyWith({List<TherapySegment>? segments, double? maxBolusUnits}) =>
      TherapySettings(
        segments: segments ?? this.segments,
        durationOfInsulinActionMinutes: durationOfInsulinActionMinutes,
        maxBolusUnits: maxBolusUnits ?? this.maxBolusUnits,
        insulinPeakMinutes: insulinPeakMinutes,
      );

  Map<String, dynamic> toJson() => {
        'segments': [for (final s in segments) s.toJson()],
        'dia': durationOfInsulinActionMinutes,
        'maxBolus': maxBolusUnits,
        'peak': insulinPeakMinutes,
      };

  factory TherapySettings.fromJson(Map<String, dynamic> j) => TherapySettings(
        segments: [
          for (final s in (j['segments'] as List))
            TherapySegment.fromJson((s as Map).cast<String, dynamic>()),
        ],
        durationOfInsulinActionMinutes: (j['dia'] as num?)?.toInt() ?? 360,
        maxBolusUnits: (j['maxBolus'] as num?)?.toDouble() ?? 25,
        insulinPeakMinutes: (j['peak'] as num?)?.toInt() ?? 75,
      );

  /// A sensible default profile for bootstrapping before the user configures theirs.
  /// These are illustrative only — the onboarding/settings flow imports the real IDP.
  static TherapySettings placeholder() => const TherapySettings(
        segments: [
          TherapySegment(
            startMinuteOfDay: 0,
            isf: 54, // 3.0 mmol/L per unit
            carbRatio: 9,
            targetMgdl: 108, // 6.0 mmol/L
            basalUnitsPerHour: 0.8,
          ),
        ],
      );
}

/// A multiplicative context adjustment applied on top of the base therapy settings,
/// produced by the sensitivity model (Phase 3). >1 means *more resistant* today
/// (needs more insulin); <1 means more sensitive (needs less).
class SensitivityContext {
  const SensitivityContext({
    this.resistanceMultiplier = 1.0,
    this.confidence = 0.0,
    this.reasons = const [],
  }) : assert(resistanceMultiplier >= 0.5 && resistanceMultiplier <= 1.6);

  /// Multiply the base insulin requirement by this. Applied to ISF as a *divisor*
  /// (more resistance => smaller effective ISF => bigger correction) and to CR as a
  /// divisor (more resistance => smaller effective CR => more insulin per carb).
  final double resistanceMultiplier;

  /// 0..1 confidence in this adjustment; low confidence => advisor uses it only
  /// weakly and says so.
  final double confidence;

  /// Human-readable drivers ("short sleep", "low HRV", "post-exercise").
  final List<String> reasons;

  static const SensitivityContext neutral = SensitivityContext();

  double get effectiveMultiplier {
    // Blend toward 1.0 by confidence so a low-confidence signal barely moves dosing.
    return 1.0 + (resistanceMultiplier - 1.0) * confidence.clamp(0.0, 1.0);
  }
}
