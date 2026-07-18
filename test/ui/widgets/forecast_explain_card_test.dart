/// "Why this forecast" card (issue #73, AC#2/#3).
///
/// Tested as a plain widget with hand-built inputs — no provider graph — because the
/// card is presentation only. The decomposition arithmetic has its own tests in
/// forecast_decomposition_test.dart; this pins what a reader is actually shown.
library;

import 'package:bgdude/analytics/forecast_decomposition.dart';
import 'package:bgdude/core/units.dart';
import 'package:bgdude/ml/forecaster.dart';
import 'package:bgdude/ui/widgets/forecast_explain_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

HorizonForecast _forecast(
  int h, {
  double residual = 0,
  ForecastBandSource band = ForecastBandSource.fallback,
}) =>
    HorizonForecast(
      horizonMinutes: h,
      mgdl: 140,
      lowerMgdl: 120,
      upperMgdl: 160,
      residualMgdl: residual,
      bandSource: band,
    );

Future<void> _pump(
  WidgetTester tester, {
  List<HorizonAttribution> decompositions = const [],
  List<HorizonForecast> forecasts = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(500, 1200));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ForecastExplainCard(
          decompositions: decompositions,
          forecasts: forecasts,
          unit: GlucoseUnit.mgdl,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  const attribution = HorizonAttribution(
    horizonMinutes: 60,
    predictedMgdl: 140,
    insulinDelta: -25,
    carbsDelta: 40,
    momentumDelta: 5,
  );

  testWidgets('shows each driver signed, so the parts can be added up',
      (tester) async {
    await _pump(tester,
        decompositions: const [attribution], forecasts: [_forecast(60)]);

    // Signs are the whole point: an unsigned magnitude makes the decomposition
    // impossible to reconcile with the forecast it claims to explain.
    expect(find.textContaining('Insulin −25'), findsOneWidget);
    expect(find.textContaining('Carbs +40'), findsOneWidget);
    expect(find.textContaining('Momentum +5'), findsOneWidget);
  });

  testWidgets('shows the learned correction, signed', (tester) async {
    await _pump(tester,
        decompositions: const [attribution],
        forecasts: [_forecast(60, residual: -12)]);

    expect(find.textContaining('Learned correction −12'), findsOneWidget);
  });

  testWidgets('names where the band came from, per source', (tester) async {
    await _pump(tester,
        decompositions: const [attribution],
        forecasts: [_forecast(60, band: ForecastBandSource.trained)]);
    expect(find.textContaining('trained spread'), findsOneWidget);

    await _pump(tester,
        decompositions: const [attribution],
        forecasts: [_forecast(60, band: ForecastBandSource.fallback)]);
    // The untrained case has to say so — a band that reflects no knowledge of this
    // user should not look the same as one the model learned.
    expect(find.textContaining('not trained yet'), findsOneWidget);
  });

  testWidgets('a band widened by live error says the model is underperforming',
      (tester) async {
    // The most informative case: the model is currently doing worse in practice than
    // it believed, and the band reflects that rather than staying reassuringly narrow.
    await _pump(tester,
        decompositions: const [attribution],
        forecasts: [_forecast(60, band: ForecastBandSource.liveError)]);

    expect(find.textContaining('recent live error'), findsOneWidget);
  });

  testWidgets('renders nothing with no decomposition', (tester) async {
    await _pump(tester);

    expect(find.text('Why this forecast'), findsNothing);
  });

  testWidgets('a horizon with no matching forecast still shows its drivers',
      (tester) async {
    // Defensive: the decomposer and the forecaster carry their own horizon lists, so
    // a mismatch must degrade to "drivers only" rather than dropping the row.
    await _pump(tester,
        decompositions: const [attribution], forecasts: [_forecast(120)]);

    expect(find.textContaining('Insulin −25'), findsOneWidget);
    expect(find.textContaining('Learned correction'), findsNothing);
  });
}
