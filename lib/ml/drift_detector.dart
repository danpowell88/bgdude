/// Compares recent LIVE per-horizon forecast error against the residual model's
/// TRAINED per-horizon sigma to catch silent accuracy degradation (TASK-138) — a
/// new sensor, a seasonal shift, or a stale model can all make the forecast worse
/// than it was when trained, and until now nothing compared the two: the model was
/// only ever replaced on the fixed retrain schedule (`AppJobs._forecasterTrainingDue`,
/// ~20h). [UncertaintyCalibrator] already widens the *displayed* band to reflect
/// recent error, but widening the band silently isn't the same as flagging that the
/// model itself has drifted and should be retrained sooner.
library;

/// Live RMSE at or above this multiple of the trained sigma counts as "drifting"
/// at that horizon for one reconciliation run.
const double kDriftRatioThreshold = 1.5;

/// Consecutive drifting runs required before drift is considered sustained (as
/// opposed to one noisy day) and an out-of-band retrain is requested.
const int kSustainedDriftRuns = 3;

class DriftDetector {
  const DriftDetector();

  /// Ratio of live RMSE to trained sigma per horizon. Only horizons present in
  /// both maps are comparable — an untrained horizon (no stored sigma) has
  /// nothing to drift FROM, and a horizon with no recent live samples has
  /// nothing to drift WITH.
  Map<int, double> ratios(
    Map<int, double> recentRmse,
    Map<int, double> trainingSigma,
  ) {
    final out = <int, double>{};
    recentRmse.forEach((horizon, rmse) {
      final sigma = trainingSigma[horizon];
      if (sigma != null && sigma > 0) out[horizon] = rmse / sigma;
    });
    return out;
  }

  /// Whether any horizon's ratio has crossed [kDriftRatioThreshold] this run.
  bool isDriftingNow(Map<int, double> ratios) =>
      ratios.values.any((r) => r >= kDriftRatioThreshold);
}

/// Snapshot of the latest drift check, surfaced to the UI ("visible flag", AC#2)
/// and threaded into the next training run's model-run record (AC#3).
class ForecastDriftState {
  const ForecastDriftState({
    this.ratios = const {},
    this.consecutiveDriftRuns = 0,
    this.sustained = false,
  });

  /// Live-RMSE / trained-sigma per horizon from the most recent reconciliation.
  final Map<int, double> ratios;

  /// How many reconciliation runs in a row have been drifting (resets to 0 on
  /// any non-drifting run) — mirrors [SubsystemHealth.consecutiveFailures]'s
  /// "sustained, not one-off" reasoning.
  final int consecutiveDriftRuns;

  /// Whether [consecutiveDriftRuns] has reached [kSustainedDriftRuns] — the
  /// visible "forecast accuracy drifting" flag.
  final bool sustained;
}
