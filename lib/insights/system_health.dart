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

  /// TASK-265: how long since the last SUCCESS is expected before a subsystem with
  /// zero recorded failures still deserves a second look — the most common and most
  /// dangerous background-failure mode is a job that silently stops being scheduled
  /// at all (an OS kill, a cancelled task): it never throws, so [SubsystemHealth.
  /// isUnhealthy] never fires, and the row shows a permanent green check. null means
  /// this subsystem has no real periodic schedule to compare against at all — see
  /// each case below for why — so it's excluded from the staleness check entirely
  /// rather than guessing a number that has no basis.
  ///
  /// There is no single global job driving these (confirmed by reading the actual
  /// trigger sites, not assumed): healthSync/predictionReconciliation/
  /// forecasterTraining all run via `AppJobs.runStartup()` on app cold-start and
  /// resume (`main_shell.dart`) — there is no fixed clock interval, only "the user
  /// opened the app". 48h is generous headroom above that reality (forecasterTraining
  /// additionally self-throttles to ~20h internally, `_forecasterTrainingDue`) so a
  /// single ordinary day without reopening the app never false-flags, while a
  /// genuine multi-day silent stall does.
  Duration? get expectedCadence => switch (this) {
        Subsystem.healthSync => const Duration(hours: 48),
        Subsystem.predictionReconciliation => const Duration(hours: 48),
        Subsystem.forecasterTraining => const Duration(hours: 48),
        // Reported via a separate native platform-channel path (garminHealthProvider
        // / PumpClient.garminHealth(), see the class doc above) with its own
        // dedicated staleness check in the UI (SystemHealthScreen's _GarminTile) --
        // this enum's own SubsystemHealth entry for garminDelivery is never
        // populated at all, so there is nothing here for a cadence to apply to.
        Subsystem.garminDelivery => null,
        // No periodic refresh exists anywhere in the codebase -- weatherProvider is
        // a plain FutureProvider with no TTL, invalidated only when the user edits
        // their city. There is no real schedule to derive a threshold from.
        Subsystem.weather => null,
        // One-shot, user-tap-triggered download, not a recurring job -- a user who
        // downloaded the model once, successfully, months ago and never revisits
        // that screen is not "unhealthy" or "stale", just done.
        Subsystem.modelDownload => null,
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

  /// TASK-265: whether it's been longer than [cadence] since the last success, with
  /// zero recorded failures in that time -- the silent-stall case [isUnhealthy]
  /// can't see (a job that stopped being scheduled entirely never throws, so
  /// consecutiveFailures never increments). Deliberately does NOT fire when
  /// [isUnhealthy] already does (a real recorded failure is worse than "just old",
  /// and the caller should check [isUnhealthy] first) or when [cadence] is null (no
  /// real schedule to compare against, see [Subsystem.expectedCadence]) or when
  /// there's no [lastSuccessAt] at all yet (that's "never run", not "stale").
  bool isStale(DateTime now, Duration? cadence) =>
      !isUnhealthy &&
      cadence != null &&
      lastSuccessAt != null &&
      now.difference(lastSuccessAt!) > cadence;

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

  /// TASK-302: a corrupt/tampered negative consecutiveFailures shouldn't display or
  /// propagate as a nonsensical negative count (isUnhealthy's `> 0` check already
  /// treats negative the same as zero, but a bare negative reaching the UI is still a
  /// display bug waiting to happen) -- clamp to a sane non-negative range.
  factory SubsystemHealth.fromJson(Map<String, dynamic> j) => SubsystemHealth(
        lastSuccessAt: j['lastSuccessAt'] == null
            ? null
            : DateTime.parse(j['lastSuccessAt'] as String),
        consecutiveFailures:
            ((j['consecutiveFailures'] as num?)?.toInt() ?? 0).clamp(0, 1 << 30),
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
