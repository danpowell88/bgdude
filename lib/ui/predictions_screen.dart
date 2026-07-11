import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/predictor.dart';
import '../analytics/therapy_settings.dart';
import '../core/units.dart';
import '../ml/forecaster.dart';
import '../ml/threshold_duration.dart';
import '../state/providers.dart';
import 'widgets/on_board_forecast_chart.dart';
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

    final forecasts = ref.watch(calibratedForecastsProvider); // shared (TASK-122)
    final predictor = ref.watch(predictorProvider);
    final ctx = ref.watch(effectiveSensitivityProvider);
    final whatIf = (_carbs > 0 || _units > 0)
        ? predictor.whatIf(state, addCarbs: _carbs, addUnits: _units)
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text('Forecast', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            const _BandCoverageChip(),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final f in forecasts) ...[
              Expanded(child: _HorizonCard(forecast: f, unit: unit)),
              if (f != forecasts.last) const SizedBox(width: 8),
            ],
          ],
        ),
        if (forecasts.isNotEmpty)
          _DurationCard(forecasts: forecasts, currentMgdl: state.currentMgdl),
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
        Text(
            'Each line is the same glucose forecast (y-axis in ${unit.label}) under a '
            'different assumption about what\'s driving your glucose. They spread apart '
            'because those assumptions differ — the gap between them is the uncertainty:\n'
            '• IOB — insulin on board only (no carbs)\n'
            '• COB — insulin + the carbs you\'ve logged\n'
            '• UAM — an unannounced meal is pushing you up\n'
            '• Zero-temp — what happens if basal were suspended\n'
            'The bold "Predicted" line is the best single estimate. Tap anywhere on the '
            'chart to read every line\'s value at that time — the tooltip now names each one.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        const SizedBox(height: 220, child: PredictionChart(showScenarios: true)),
        const SizedBox(height: 6),
        const PredictionChartLegend(scenarios: true),
        const SizedBox(height: 20),
        Text('On board', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
            'The insulin (IOB) and carbs (COB) already working, plus scheduled basal, over '
            'the next ${predictor.horizonMinutes ~/ 60} h — the drivers behind the '
            'forecast above. Insulin uses the left axis (U, U/h), carbs the right (g).',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        OnBoardForecastChart(horizonMinutes: predictor.horizonMinutes),
        const SizedBox(height: 6),
        const OnBoardForecastLegend(),
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

/// TASK-143: "predicted low for ~25 min" — the clinically actionable readout a
/// point forecast alone can't answer (treat-now vs ride-it-out). Hidden
/// entirely when the point trajectory predicts no time below/above threshold.
class _DurationCard extends StatelessWidget {
  const _DurationCard({required this.forecasts, required this.currentMgdl});
  final List<HorizonForecast> forecasts;
  final double currentMgdl;

  @override
  Widget build(BuildContext context) {
    const estimator = ThresholdDurationEstimator();
    final low = estimator.minutesBelow(
        forecasts, currentMgdl, GlucoseThresholds.low);
    final high = estimator.minutesAbove(
        forecasts, currentMgdl, GlucoseThresholds.high);
    if (!low.isPredicted && !high.isPredicted) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        color: low.isPredicted ? cs.errorContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (low.isPredicted)
                _durationRow(context, Icons.trending_down,
                    'Predicted low for ~${low.pointMinutes} min', low),
              if (high.isPredicted)
                _durationRow(context, Icons.trending_up,
                    'Predicted high for ~${high.pointMinutes} min', high),
            ],
          ),
        ),
      ),
    );
  }

  Widget _durationRow(
      BuildContext context, IconData icon, String text, ThresholdDuration d) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              d.confidentMinutes < d.pointMinutes
                  ? '$text (at least ${d.confidentMinutes} min likely)'
                  : text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
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

/// TASK-56: a small trust chip — how often the actual reading landed inside the forecast
/// band over the last 7 days. Hidden until enough predictions have reconciled.
class _BandCoverageChip extends ConsumerWidget {
  const _BandCoverageChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverage = ref.watch(bandCoverageProvider).valueOrNull;
    if (coverage == null || !coverage.hasData || coverage.total < 5) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message:
          'The forecast band caught ${coverage.covered} of your last ${coverage.total} '
          'reconciled readings (past 7 days).',
      child: Chip(
        visualDensity: VisualDensity.compact,
        avatar: Icon(Icons.verified_outlined, size: 16, color: cs.primary),
        label: Text('Band ${(coverage.fraction * 100).round()}%'),
      ),
    );
  }
}

class _SensitivityCard extends StatelessWidget {
  const _SensitivityCard({required this.context0});
  final SensitivityContext context0;

  @override
  Widget build(BuildContext context) {
    final mult = context0.effectiveMultiplier;
    final reasons = context0.reasons;
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
