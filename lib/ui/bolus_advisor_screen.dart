import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/bolus_advisor.dart';
import '../analytics/predictor.dart';
import '../core/samples.dart';
import '../state/providers.dart';

/// Interactive bolus advisor. Enter carbs (optional); it computes a suggestion from the
/// live CGM/IOB + context-adjusted settings and shows every step of the maths. The user
/// enters the dose on the pump themselves — this screen never delivers insulin.
class BolusAdvisorScreen extends ConsumerStatefulWidget {
  const BolusAdvisorScreen({super.key});

  @override
  ConsumerState<BolusAdvisorScreen> createState() => _BolusAdvisorScreenState();
}

class _BolusAdvisorScreenState extends ConsumerState<BolusAdvisorScreen> {
  final _carbs = TextEditingController();
  bool _cgmNoisy = false;
  BolusAdvice? _advice;

  @override
  void dispose() {
    _carbs.dispose();
    super.dispose();
  }

  void _compute() {
    final snapshot = ref.read(pumpSnapshotProvider).valueOrNull;
    final mgdl = snapshot?.cgmMgdl?.toDouble();
    if (mgdl == null) return;
    final settings = ref.read(therapySettingsProvider);
    final ctx = ref.read(sensitivityContextProvider);
    final unit = ref.read(glucoseUnitProvider);

    final state = PredictionState(
      now: snapshot!.cgmTime ?? DateTime.now(),
      currentMgdl: mgdl,
      recentRocMgdlPerMin: (snapshot.cgmTrend ?? GlucoseTrend.flat).mgdlPerMin,
      boluses: const [],
      basal: const [],
      carbs: const [],
      settings: settings,
      context: ctx,
    );

    final carbs = double.tryParse(_carbs.text) ?? 0;
    setState(() {
      _advice = ref.read(bolusAdvisorProvider).advise(
            state,
            carbsGrams: carbs,
            cgmNoisy: _cgmNoisy,
            displayUnit: unit,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final advice = _advice;
    return Scaffold(
      appBar: AppBar(title: const Text('Bolus advisor')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _carbs,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Carbs (g)',
              hintText: 'Leave blank for a correction only',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('CGM noisy / warming up'),
            subtitle: const Text('Skip the correction from this reading'),
            value: _cgmNoisy,
            onChanged: (v) => setState(() => _cgmNoisy = v),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _compute,
            icon: const Icon(Icons.calculate),
            label: const Text('Calculate suggestion'),
          ),
          const SizedBox(height: 20),
          if (advice != null) _AdviceCard(advice: advice),
        ],
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.advice});
  final BolusAdvice advice;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (advice.refused)
              Text('No suggestion', style: Theme.of(context).textTheme.titleLarge)
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(advice.recommendedUnits.toStringAsFixed(2),
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(color: cs.primary)),
                  const SizedBox(width: 6),
                  const Text('U'),
                  const Spacer(),
                  _ConfidenceChip(confidence: advice.confidence),
                ],
              ),
            const Divider(height: 24),
            Text('Working', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final step in advice.working)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 110,
                        child: Text(step.label,
                            style: Theme.of(context).textTheme.bodySmall)),
                    Expanded(child: Text(step.value)),
                  ],
                ),
              ),
            if (advice.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final note in advice.notes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: cs.tertiary),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(note,
                              style: Theme.of(context).textTheme.bodySmall)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pan_tool_alt, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Enter this on your pump yourself. This app never delivers insulin.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({required this.confidence});
  final AdviceConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (confidence) {
      AdviceConfidence.high => ('high confidence', Colors.green),
      AdviceConfidence.moderate => ('moderate', Colors.orange),
      AdviceConfidence.low => ('low confidence', Colors.deepOrange),
      AdviceConfidence.refused => ('refused', Colors.grey),
    };
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
    );
  }
}
