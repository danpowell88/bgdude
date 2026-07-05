import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/bolus_advisor.dart';
import '../state/providers.dart';
import 'widgets/common.dart';

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
  final _fat = TextEditingController();
  final _protein = TextEditingController();
  FatProteinLevel _fpLevel = FatProteinLevel.none;
  bool _cgmNoisy = false;
  BolusAdvice? _advice;

  @override
  void dispose() {
    _carbs.dispose();
    _fat.dispose();
    _protein.dispose();
    super.dispose();
  }

  void _compute() {
    final state = ref.read(livePredictionStateProvider);
    if (state == null) return;
    final unit = ref.read(glucoseUnitProvider);

    final carbs = double.tryParse(_carbs.text) ?? 0;
    final fat = double.tryParse(_fat.text) ?? 0;
    final protein = double.tryParse(_protein.text) ?? 0;
    setState(() {
      _advice = ref.read(bolusAdvisorProvider).advise(
            state,
            carbsGrams: carbs,
            fatGrams: fat,
            proteinGrams: protein,
            fatProteinLevel: _fpLevel,
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
          const SizedBox(height: 16),
          // Fat/protein for the delayed "pizza effect" rise. Pick a rough load, or enter
          // exact grams (which override the picker). Produces an extended dose suggestion.
          Text('Fat & protein (optional)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<FatProteinLevel>(
            segments: const [
              ButtonSegment(value: FatProteinLevel.none, label: Text('None')),
              ButtonSegment(value: FatProteinLevel.low, label: Text('Low')),
              ButtonSegment(value: FatProteinLevel.medium, label: Text('Med')),
              ButtonSegment(value: FatProteinLevel.high, label: Text('High')),
            ],
            selected: {_fpLevel},
            onSelectionChanged: (s) => setState(() => _fpLevel = s.first),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fat,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Fat (g)',
                      helperText: 'optional · overrides load',
                      border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _protein,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Protein (g)',
                      helperText: 'optional',
                      border: OutlineInputBorder()),
                ),
              ),
            ],
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
            if (advice.fpuUnits > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.timelapse, size: 16, color: cs.secondary),
                  const SizedBox(width: 6),
                  Text(
                    '+ ${advice.fpuUnits.toStringAsFixed(2)} U extended over '
                    '${advice.fpuExtendHours}h  ·  ${advice.fpu.toStringAsFixed(1)} FPU',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.secondary),
                  ),
                ],
              ),
            ],
            const Divider(height: 24),
            Text('Working', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            AdviceWorkingList(advice.working),
            if (advice.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              AdviceNotesList(advice.notes),
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
