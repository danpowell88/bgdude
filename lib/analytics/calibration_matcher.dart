/// Matches finger-prick (meter/calibration) readings against the CGM sensor trace so the
/// two can be compared for accuracy without one corrupting the other (TASK-63). Pure and
/// deterministic. A match is the nearest sensor reading within [window] of the finger-prick;
/// the pair "agrees" when they're within [agreementFraction] of each other.
library;

import '../core/samples.dart';

class CalibrationMatch {
  const CalibrationMatch({
    required this.meterTime,
    required this.meterMgdl,
    required this.sensorTime,
    required this.sensorMgdl,
    required this.gap,
  });

  final DateTime meterTime;
  final double meterMgdl;
  final DateTime sensorTime;
  final double sensorMgdl;

  /// |meterTime − sensorTime|.
  final Duration gap;

  /// Signed fractional difference of the finger-prick relative to the sensor.
  double get fractionalDiff =>
      sensorMgdl == 0 ? 0 : (meterMgdl - sensorMgdl) / sensorMgdl;
}

class CalibrationMatcher {
  const CalibrationMatcher({
    this.window = const Duration(minutes: 15),
    this.agreementFraction = 0.20,
  });

  /// A finger-prick matches the nearest sensor reading within this window.
  final Duration window;

  /// The pair agrees when the finger-prick is within this fraction of the sensor value.
  final double agreementFraction;

  bool agrees(CalibrationMatch m) => m.fractionalDiff.abs() <= agreementFraction;

  /// Match every finger-prick (source == meter, or flagged calibration) in [readings] to the
  /// nearest real sensor reading within [window]. Finger-pricks with no sensor reading in
  /// range are skipped. Newest match last.
  List<CalibrationMatch> match(List<CgmSample> readings) {
    final sensor = [
      for (final s in readings)
        if (!s.isCalibration &&
            s.source == GlucoseSource.sensor &&
            !s.sensorWarmup &&
            s.mgdl > 0)
          s,
    ]..sort((a, b) => a.time.compareTo(b.time));
    final meters = [
      for (final s in readings)
        if ((s.isCalibration || s.source == GlucoseSource.meter) && s.mgdl > 0) s,
    ]..sort((a, b) => a.time.compareTo(b.time));

    final out = <CalibrationMatch>[];
    for (final m in meters) {
      CgmSample? best;
      var bestGap = window + const Duration(seconds: 1);
      for (final s in sensor) {
        final g = s.time.difference(m.time).abs();
        if (g <= window && g < bestGap) {
          best = s;
          bestGap = g;
        }
      }
      if (best == null) continue;
      out.add(CalibrationMatch(
        meterTime: m.time,
        meterMgdl: m.mgdl,
        sensorTime: best.time,
        sensorMgdl: best.mgdl,
        gap: bestGap,
      ));
    }
    return out;
  }
}
