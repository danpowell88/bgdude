/// User-customisable glucose alert thresholds (mg/dL internally). These feed the
/// real-time [AlertMonitor] so the low/high nudges match the user's own targets rather
/// than fixed defaults. Safety modifiers (hypo-awareness, alcohol, exercise) are layered
/// on top of [lowMgdl] at evaluation time.
library;

class AlertThresholds {
  const AlertThresholds({
    this.lowMgdl = 70,
    this.highMgdl = 200,
    this.urgentLowMgdl = 55,
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
        lowMgdl: (j['low'] as num?)?.toDouble() ?? 70,
        highMgdl: (j['high'] as num?)?.toDouble() ?? 200,
        urgentLowMgdl: (j['urgentLow'] as num?)?.toDouble() ?? 55,
      );
}
