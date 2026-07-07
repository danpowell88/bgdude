/// System-health surface (TASK-201): tracks last-success/failure-count per
/// background subsystem, so a recurring silent failure has a user-visible signal
/// instead of only ever landing in appLog. Pure Dart, no Flutter/Riverpod imports —
/// the persistence wrapper lives in state/providers.dart.
library;

/// Every subsystem this surface tracks. Garmin delivery is native (GarminSender.kt)
/// and reports its own in-memory (not persisted across restarts) counters via a
/// platform-channel call rather than through [SystemHealthRecorder] directly — see
/// PumpClient.garminHealth().
enum Subsystem {
  healthSync,
  forecasterTraining,
  predictionReconciliation,
  garminDelivery,
  weather,
  modelDownload;

  String get label => switch (this) {
        Subsystem.healthSync => 'Health data sync',
        Subsystem.forecasterTraining => 'Forecaster training',
        Subsystem.predictionReconciliation => 'Prediction reconciliation',
        Subsystem.garminDelivery => 'Garmin watch delivery',
        Subsystem.weather => 'Weather',
        Subsystem.modelDownload => 'Nutrition-label model download',
      };
}

/// A subsystem's health at a point in time. [consecutiveFailures] resets to 0 on
/// any success — it measures a SUSTAINED problem, not lifetime error count, since a
/// one-off blip decades ago shouldn't look the same as failing every run this week.
class SubsystemHealth {
  const SubsystemHealth({
    this.lastSuccessAt,
    this.consecutiveFailures = 0,
    this.lastError,
    this.lastAttemptAt,
  });

  /// When this subsystem last completed successfully, or null if never observed.
  final DateTime? lastSuccessAt;

  /// Consecutive failures since the last success (0 if currently healthy or never
  /// observed at all).
  final int consecutiveFailures;

  /// The most recent failure's message, for context (null once a success clears it
  /// implicitly via [consecutiveFailures] resetting to 0 — kept alongside anyway so
  /// a UI can still show "last error: ..." even right after recovery).
  final String? lastError;

  /// When this subsystem was last attempted at all (success or failure) — lets the
  /// UI distinguish "never run yet" from "healthy, ran recently".
  final DateTime? lastAttemptAt;

  static const SubsystemHealth unknown = SubsystemHealth();

  /// Whether this subsystem currently looks unhealthy: failed at least once in a
  /// row, or has never succeeded despite having been attempted.
  bool get isUnhealthy =>
      consecutiveFailures > 0 || (lastAttemptAt != null && lastSuccessAt == null);

  SubsystemHealth withSuccess(DateTime at) => SubsystemHealth(
        lastSuccessAt: at,
        consecutiveFailures: 0,
        lastError: null,
        lastAttemptAt: at,
      );

  SubsystemHealth withFailure(DateTime at, String error) => SubsystemHealth(
        lastSuccessAt: lastSuccessAt,
        consecutiveFailures: consecutiveFailures + 1,
        lastError: error,
        lastAttemptAt: at,
      );

  Map<String, dynamic> toJson() => {
        'lastSuccessAt': lastSuccessAt?.toIso8601String(),
        'consecutiveFailures': consecutiveFailures,
        'lastError': lastError,
        'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      };

  factory SubsystemHealth.fromJson(Map<String, dynamic> j) => SubsystemHealth(
        lastSuccessAt: j['lastSuccessAt'] == null
            ? null
            : DateTime.parse(j['lastSuccessAt'] as String),
        consecutiveFailures: (j['consecutiveFailures'] as num?)?.toInt() ?? 0,
        lastError: j['lastError'] as String?,
        lastAttemptAt: j['lastAttemptAt'] == null
            ? null
            : DateTime.parse(j['lastAttemptAt'] as String),
      );
}

/// The full report: one [SubsystemHealth] per [Subsystem]. Subsystems never
/// observed at all are absent from [bySubsystem] (equivalent to
/// [SubsystemHealth.unknown]) rather than stored explicitly.
class SystemHealthReport {
  const SystemHealthReport({this.bySubsystem = const {}});

  final Map<Subsystem, SubsystemHealth> bySubsystem;

  SubsystemHealth of(Subsystem s) => bySubsystem[s] ?? SubsystemHealth.unknown;

  SystemHealthReport withRecord(Subsystem s, SubsystemHealth health) =>
      SystemHealthReport(bySubsystem: {...bySubsystem, s: health});

  Map<String, dynamic> toJson() => {
        for (final e in bySubsystem.entries) e.key.name: e.value.toJson(),
      };

  factory SystemHealthReport.fromJson(Map<String, dynamic> j) {
    final map = <Subsystem, SubsystemHealth>{};
    for (final s in Subsystem.values) {
      final raw = j[s.name];
      if (raw is Map<String, dynamic>) {
        map[s] = SubsystemHealth.fromJson(raw);
      }
    }
    return SystemHealthReport(bySubsystem: map);
  }
}
