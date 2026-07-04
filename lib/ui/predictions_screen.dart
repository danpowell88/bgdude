import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/predictor.dart';
import '../core/units.dart';
import '../ml/forecaster.dart';
import '../state/providers.dart';
import 'widgets/prediction_chart.dart';

/// Every model's forward-looking output in one place: the BG forecaster horizons
/// (with uncertainty), the decomposed scenario lines, a what-if explorer, an overnight
/// risk read-out, and the sensitivity-readiness figure the dosing math is using.
class PredictionsScreen extends ConsumerStatefulWidget {
  const PredictionsScreen({super.key});

  @override
  ConsumerState<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends ConsumerState<PredictionsScreen> {
  double _carbs = 0;
  double _units = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(livePredictionStateProvider);
    final unit = ref.watch(glucoseUnitProvider);

    if (state == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Predictions need a glucose reading. Connect the pump or '
              'turn on dev mode in settings to explore with simulated data.',
              textAlign: TextAlign.center),
        ),
      );
    }

    final forecasts = ref.watch(forecasterProvider).forecast(state);
    final predictor = ref.watch(predictorProvider);
    final ctx = ref.watch(effectiveSensitivityProvider);
    final whatIf = (_carbs > 0 || _units > 0)
        ? predictor.whatIf(state, addCarbs: _carbs, addUnits: _units)
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Forecast', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final f in forecasts) ...[
              Expanded(child: _HorizonCard(forecast: f, unit: unit)),
              if (f != forecasts.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          ref.watch(forecasterProvider).residualTrained
              ? 'Physiological model + learned personal correction.'
              : 'Physiological model. A learned correction is added once ~2 weeks of '
                  'your data have trained and passed the safety gate.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 20),
        Text('Scenario lines', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('How glucose could move under insulin-only (IOB), with carbs (COB), '
            'unannounced-meal (UAM), and no-basal (zero-temp) assumptions.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        const SizedBox(height: 220, child: PredictionChart(showScenarios: true)),
        const SizedBox(height: 20),
        _SensitivityCard(context0: ctx),
        const SizedBox(height: 20),
        _OvernightCard(state: state, predictor: predictor, unit: unit),
        const SizedBox(height: 20),
        Text('What-if explorer', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _WhatIfControls(
          carbs: _carbs,
          units: _units,
          onCarbs: (v) => setState(() => _carbs = v),
          onUnits: (v) => setState(() => _units = v),
        ),
        if (whatIf != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(whatIf.label,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text('Projected range over the next '
                      '${predictor.horizonMinutes ~/ 60} h: '
                      '${Mgdl(whatIf.minMgdl).display(unit)}–'
                      '${Mgdl(whatIf.maxMgdl).display(unit)} ${unit.label}, '
                      'ending ${Mgdl(whatIf.endMgdl).display(unit)} ${unit.label}.'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HorizonCard extends StatelessWidget {
  const _HorizonCard({required this.forecast, required this.unit});
  final HorizonForecast forecast;
  final GlucoseUnit unit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text('+${forecast.horizonMinutes}m',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(Mgdl(forecast.mgdl).display(unit),
                style: Theme.of(context).textTheme.headlineSmall),
            Text(
              '${Mgdl(forecast.lowerMgdl).display(unit)}–'
              '${Mgdl(forecast.upperMgdl).display(unit)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SensitivityCard extends StatelessWidget {
  const _SensitivityCard({required this.context0});
  final dynamic context0;

  @override
  Widget build(BuildContext context) {
    final mult = context0.effectiveMultiplier as double;
    final reasons = (context0.reasons as List).cast<String>();
    final pct = ((mult - 1) * 100).round();
    final label = pct.abs() < 3
        ? 'Typical sensitivity today'
        : pct > 0
            ? '~$pct% more insulin-resistant today'
            : '~${pct.abs()}% more insulin-sensitive today';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.battery_charging_full),
                const SizedBox(width: 8),
                Text('Sensitivity readiness',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            if (reasons.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Drivers: ${reasons.join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 6),
            Text('The bolus advisor scales ISF and carb ratio by ×'
                '${mult.toStringAsFixed(2)} to match.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _OvernightCard extends StatelessWidget {
  const _OvernightCard({
    required this.state,
    required this.predictor,
    required this.unit,
  });
  final PredictionState state;
  final GlucosePredictor predictor;
  final GlucoseUnit unit;

  @override
  Widget build(BuildContext context) {
    final line = predictor.predict(state);
    final min = line.minMgdl;
    final max = line.maxMgdl;
    final lowRisk = min < GlucoseThresholds.low;
    final highRisk = max > GlucoseThresholds.high;
    final msg = lowRisk
        ? 'Low risk ahead — projected down to ${Mgdl(min).display(unit)} ${unit.label}. '
            'A small snack may head it off.'
        : highRisk
            ? 'Trending high — projected up to ${Mgdl(max).display(unit)} ${unit.label}.'
            : 'Projected to stay in range over the next few hours.';
    return Card(
      color: lowRisk
          ? Theme.of(context).colorScheme.errorContainer
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(lowRisk ? Icons.trending_down : Icons.nightlight_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    );
  }
}

class _WhatIfControls extends StatelessWidget {
  const _WhatIfControls({
    required this.carbs,
    required this.units,
    required this.onCarbs,
    required this.onUnits,
  });
  final double carbs;
  final double units;
  final ValueChanged<double> onCarbs;
  final ValueChanged<double> onUnits;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 70, child: Text('Carbs')),
                Expanded(
                  child: Slider(
                    value: carbs,
                    max: 100,
                    divisions: 20,
                    label: '${carbs.round()} g',
                    onChanged: onCarbs,
                  ),
                ),
                SizedBox(width: 44, child: Text('${carbs.round()} g')),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 70, child: Text('Insulin')),
                Expanded(
                  child: Slider(
                    value: units,
                    max: 10,
                    divisions: 40,
                    label: '${units.toStringAsFixed(1)} U',
                    onChanged: onUnits,
                  ),
                ),
                SizedBox(width: 44, child: Text('${units.toStringAsFixed(1)}U')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
