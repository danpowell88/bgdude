/// User-customisable glucose alert thresholds (mg/dL internally). These feed the
/// real-time [AlertMonitor] so the low/high nudges match the user's own targets rather
/// than fixed defaults. Safety modifiers (hypo-awareness, alcohol, exercise) are layered
/// on top of [lowMgdl] at evaluation time.
library;

class AlertThresholds {
  /// Shipped defaults (mg/dL). Referenced by BOTH the constructor and [fromJson] so the
  /// two can't silently drift apart (TASK-103).
  static const double defaultLowMgdl = 70;
  static const double defaultHighMgdl = 200;
  static const double defaultUrgentLowMgdl = 55;

  const AlertThresholds({
    this.lowMgdl = defaultLowMgdl,
    this.highMgdl = defaultHighMgdl,
    this.urgentLowMgdl = defaultUrgentLowMgdl,
  });

  final double lowMgdl;
  final double highMgdl;
  final double urgentLowMgdl;

  AlertThresholds copyWith({
    double? lowMgdl,
    double? highMgdl,
    double? urgentLowMgdl,
  }) =>
      AlertThresholds(
        lowMgdl: lowMgdl ?? this.lowMgdl,
        highMgdl: highMgdl ?? this.highMgdl,
        urgentLowMgdl: urgentLowMgdl ?? this.urgentLowMgdl,
      );

  Map<String, dynamic> toJson() =>
      {'low': lowMgdl, 'high': highMgdl, 'urgentLow': urgentLowMgdl};

  factory AlertThresholds.fromJson(Map<String, dynamic> j) => AlertThresholds(
        lowMgdl: (j['low'] as num?)?.toDouble() ?? defaultLowMgdl,
        highMgdl: (j['high'] as num?)?.toDouble() ?? defaultHighMgdl,
        urgentLowMgdl: (j['urgentLow'] as num?)?.toDouble() ?? defaultUrgentLowMgdl,
      );
}
