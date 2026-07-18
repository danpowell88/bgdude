/// "Why this forecast" — per-horizon attribution, advanced mode only (issue #73).
///
/// The forecast is a sum of physiological effects plus a learned correction. This shows
/// that sum broken apart, so a surprising number can be interrogated rather than just
/// believed or dismissed: which input drove it, how far the learned model moved it off
/// the physiological baseline, and where the uncertainty band came from.
///
/// Presentation only — no modelling, no persisted state. Its own widget rather than a
/// private one inside a screen so it can be tested without the provider graph the
/// enclosing screen pulls in.
library;

import 'package:flutter/material.dart';

import '../../analytics/forecast_decomposition.dart';
import '../../core/units.dart';
import '../../ml/forecaster.dart';

class ForecastExplainCard extends StatelessWidget {
  const ForecastExplainCard({
    super.key,
    required this.decompositions,
    required this.forecasts,
    required this.unit,
  });

  /// Per-horizon insulin/carb/momentum attribution.
  final List<HorizonAttribution> decompositions;

  /// The matching forecasts, for the residual and band provenance.
  final List<HorizonForecast> forecasts;

  final GlucoseUnit unit;

  HorizonForecast? _forecastFor(int horizon) {
    for (final f in forecasts) {
      if (f.horizonMinutes == horizon) return f;
    }
    return null;
  }

  /// Signed, in display units, so a reader can add the parts up and land on the
  /// forecast. An unsigned magnitude would make the decomposition unverifiable.
  String _signed(double mgdl) {
    final v = Mgdl(mgdl.abs()).display(unit);
    return '${mgdl < 0 ? '−' : '+'}$v';
  }

  static String bandSourceLabel(ForecastBandSource source) =>
      switch (source) {
        ForecastBandSource.trained => 'model\'s trained spread',
        ForecastBandSource.liveError => 'recent live error (wider than the model\'s)',
        ForecastBandSource.fallback => 'default spread — model not trained yet',
      };

  @override
  Widget build(BuildContext context) {
    if (decompositions.isEmpty) return const SizedBox.shrink();
    final small = Theme.of(context).textTheme.bodySmall;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Why this forecast',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Each horizon as the sum of its parts, from the same run that produced '
              'the forecast.',
              style: small,
            ),
            const SizedBox(height: 12),
            for (final d in decompositions) ...[
              Text('${d.horizonMinutes} min → ${Mgdl(d.predictedMgdl).display(unit)} '
                  '${unit.label}'),
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Insulin ${_signed(d.insulinDelta)} · '
                        'Carbs ${_signed(d.carbsDelta)} · '
                        'Momentum ${_signed(d.momentumDelta)}',
                        style: small),
                    if (_forecastFor(d.horizonMinutes) case final f?) ...[
                      Text('Learned correction ${_signed(f.residualMgdl)}',
                          style: small),
                      Text('Band: ${bandSourceLabel(f.bandSource)}', style: small),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
