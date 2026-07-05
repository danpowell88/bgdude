/// A catch-all "something's out of the norm" detector. The app has specific detectors for
/// named conditions (predicted low/high, missed bolus, stubborn high, ketone risk, …); this
/// one flags the *unnamed* case: glucose moving much faster than the carbs/insulin model
/// expects — an early heads-up that something novel is happening (an unannounced meal, a
/// failing/compressed sensor, a set problem, stress, illness onset) so the user can look
/// before it becomes a low or a stubborn high.
///
/// It is deliberately conservative (a real, sustained move that the model can't explain) so
/// it doesn't cry wolf, and the caller only fires it when no specific alert already covers
/// the situation.
library;

import '../core/samples.dart';

class AnomalyResult {
  const AnomalyResult({
    required this.detected,
    this.reason = '',
    this.observedRocMgdlPerMin = 0,
  });

  final bool detected;
  final String reason;
  final double observedRocMgdlPerMin;

  static const AnomalyResult none = AnomalyResult(detected: false);
}

class AnomalyDetector {
  const AnomalyDetector({
    this.window = const Duration(minutes: 15),
    this.minMoveMgdl = 30,
    this.unexplainedRocMgdlPerMin = 2.0,
    this.minSpan = const Duration(minutes: 10),
  });

  /// How far back to measure the recent move.
  final Duration window;

  /// Ignore moves smaller than this over the window (sensor wiggle).
  final double minMoveMgdl;

  /// Flag when observed rate-of-change exceeds the model's expected rate by this much.
  final double unexplainedRocMgdlPerMin;

  /// Need at least this much time between the first and last sample to trust the slope.
  final Duration minSpan;

  /// [expectedRocMgdlPerMin] is the model's near-term expected rate (from the forecast, i.e.
  /// what carbs + insulin + momentum predict). A large gap between what glucose is actually
  /// doing and that expectation is the anomaly.
  AnomalyResult detect({
    required List<CgmSample> cgm,
    required double expectedRocMgdlPerMin,
    required DateTime now,
  }) {
    final recent = [
      for (final s in cgm)
        if (!s.time.isAfter(now) &&
            now.difference(s.time) <= window &&
            !s.sensorWarmup &&
            !s.compressionLow)
          s,
    ]..sort((a, b) => a.time.compareTo(b.time));
    if (recent.length < 3) return AnomalyResult.none;

    final first = recent.first;
    final last = recent.last;
    final spanMin = last.time.difference(first.time).inSeconds / 60.0;
    if (spanMin < minSpan.inMinutes) return AnomalyResult.none;

    final move = last.mgdl - first.mgdl;
    if (move.abs() < minMoveMgdl) return AnomalyResult.none;

    final observedRoc = move / spanMin;
    final gap = observedRoc - expectedRocMgdlPerMin;
    if (gap.abs() < unexplainedRocMgdlPerMin) return AnomalyResult.none;

    final perMin = observedRoc.abs().toStringAsFixed(1);
    final reason = observedRoc > 0
        ? 'Glucose is climbing faster (~$perMin/min) than your carbs and insulin explain — '
            'a missed dose, a sensor jump, stress or illness? Worth a look.'
        : 'Glucose is dropping faster (~$perMin/min) than expected — keep an eye out for a '
            'low, and check the sensor and site.';
    return AnomalyResult(
      detected: true,
      reason: reason,
      observedRocMgdlPerMin: observedRoc,
    );
  }
}
