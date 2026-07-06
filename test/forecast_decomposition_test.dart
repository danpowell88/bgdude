import 'package:bgdude/analytics/forecast_decomposition.dart';
import 'package:bgdude/analytics/predictor.dart';
import 'package:bgdude/core/samples.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/samples.dart';

/// TASK-59 AC#1: the forecast is attributed to insulin / carbs / momentum by re-running
/// with each input zeroed.
void main() {
  final predictor = GlucosePredictor();
  const decomposer = ForecastDecomposer(horizons: [30, 60, 120]);
  final now = DateTime(2026, 7, 7, 12);
  final settings = testTherapySettings();

  PredictionState state({
    List<BolusEvent> boluses = const [],
    List<CarbEntry> carbs = const [],
    double roc = 0,
  }) =>
      PredictionState(
        now: now,
        currentMgdl: 150,
        recentRocMgdlPerMin: roc,
        boluses: boluses,
        basal: const [],
        carbs: carbs,
        settings: settings,
      );

  test('produces one attribution per horizon', () {
    final d = decomposer.decompose(predictor, state());
    expect(d.map((a) => a.horizonMinutes).toList(), [30, 60, 120]);
  });

  test('a recent bolus reads as a negative insulin contribution', () {
    final withBolus = state(
        boluses: [BolusEvent(time: now.subtract(const Duration(minutes: 5)), units: 4)]);
    final d = decomposer.decompose(predictor, withBolus);
    // Insulin pulls the forecast down at the longer horizons.
    expect(d.last.insulinDelta, lessThan(0));
  });

  test('carbs read as a positive contribution', () {
    final withCarbs = state(
        carbs: [CarbEntry(time: now.subtract(const Duration(minutes: 5)), grams: 40)]);
    final d = decomposer.decompose(predictor, withCarbs);
    expect(d.first.carbsDelta, greaterThan(0));
  });

  test('upward momentum reads as a positive momentum contribution near-term', () {
    final rising = state(roc: 2.0); // +2 mg/dL/min
    final flat = state(roc: 0);
    final dRising = decomposer.decompose(predictor, rising);
    final dFlat = decomposer.decompose(predictor, flat);
    expect(dRising.first.momentumDelta, greaterThan(0));
    expect(dFlat.first.momentumDelta, closeTo(0, 1e-9));
  });
}
