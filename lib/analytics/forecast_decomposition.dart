/// "Why this forecast": attributes the predicted glucose to its drivers — insulin, carbs
/// and momentum — by re-running the forward simulation with each input zeroed and taking
/// the delta (TASK-59). Pure and cheap (a few extra deterministic runs); no persisted state.
///
/// Sign convention: each *Delta is `full − without-that-driver`, i.e. how much that driver
/// moved the forecast at the horizon. Insulin typically reads negative (it lowered the
/// forecast), carbs positive.
library;

import 'predictor.dart';

class HorizonAttribution {
  const HorizonAttribution({
    required this.horizonMinutes,
    required this.predictedMgdl,
    required this.insulinDelta,
    required this.carbsDelta,
    required this.momentumDelta,
  });

  final int horizonMinutes;
  final double predictedMgdl;
  final double insulinDelta;
  final double carbsDelta;
  final double momentumDelta;
}

class ForecastDecomposer {
  const ForecastDecomposer({this.horizons = const [30, 60, 120, 240]});

  /// Horizons (minutes from now) to attribute.
  final List<int> horizons;

  List<HorizonAttribution> decompose(
      GlucosePredictor predictor, PredictionState state) {
    final full = predictor.predict(state);
    final noInsulin =
        predictor.predict(state.copyWith(boluses: const [], basal: const []));
    final noCarbs = predictor.predict(state.copyWith(carbs: const []));
    final noMomentum = predictor.predict(state.copyWith(recentRocMgdlPerMin: 0));

    final out = <HorizonAttribution>[];
    for (final h in horizons) {
      final target = state.now.add(Duration(minutes: h));
      final f = _mgdlAt(full, target);
      out.add(HorizonAttribution(
        horizonMinutes: h,
        predictedMgdl: f,
        insulinDelta: f - _mgdlAt(noInsulin, target),
        carbsDelta: f - _mgdlAt(noCarbs, target),
        momentumDelta: f - _mgdlAt(noMomentum, target),
      ));
    }
    return out;
  }

  static double _mgdlAt(PredictionLine line, DateTime target) {
    if (line.points.isEmpty) return 0;
    var best = line.points.first;
    for (final p in line.points) {
      if (p.time.difference(target).abs() < best.time.difference(target).abs()) {
        best = p;
      }
    }
    return best.mgdl;
  }
}
