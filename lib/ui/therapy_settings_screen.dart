import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/therapy_settings.dart';
import '../core/units.dart';
import '../state/providers.dart';

/// Editor for the pump therapy profile (IDP): time-of-day segments with basal rate,
/// ISF, carb ratio and target. These feed the what-if engine, bolus advisor and
/// predictions, so entering your real pump values matters. Enter them from your pump's
/// Personal Profiles screen.
class TherapySettingsScreen extends ConsumerWidget {
  const TherapySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(therapySettingsProvider);
    final unit = ref.watch(glucoseUnitProvider);
    final segments = [...settings.segments]
      ..sort((a, b) => a.startMinuteOfDay.compareTo(b.startMinuteOfDay));

    return Scaffold(
      appBar: AppBar(title: const Text('Therapy profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Enter the segments from your pump\'s Personal Profile. The advisor and '
            'predictions use these directly.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final s in segments)
            Card(
              child: ListTile(
                title: Text(_time(s.startMinuteOfDay)),
                subtitle: Text(
                  'Basal ${s.basalUnitsPerHour.toStringAsFixed(2)} U/h · '
                  'ISF 1U:${Mgdl(s.isf).display(unit)} · '
                  'CR 1U:${s.carbRatio.toStringAsFixed(0)}g · '
                  'Target ${Mgdl(s.targetMgdl).display(unit)}',
                ),
                trailing: segments.length > 1
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _save(
                            ref,
                            settings,
                            [...segments]..remove(s)),
                      )
                    : null,
                onTap: () => _edit(context, ref, settings, s, unit),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _edit(context, ref, settings, null, unit),
            icon: const Icon(Icons.add),
            label: const Text('Add segment'),
          ),
        ],
      ),
    );
  }

  void _save(WidgetRef ref, TherapySettings base, List<TherapySegment> segs) {
    ref.read(therapySettingsProvider.notifier).save(base.copyWith(segments: segs));
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    TherapySettings base,
    TherapySegment? existing,
    GlucoseUnit unit,
  ) async {
    final result = await showDialog<TherapySegment>(
      context: context,
      builder: (_) => _SegmentDialog(existing: existing, unit: unit),
    );
    if (result == null) return;
    final segs = [
      for (final s in base.segments)
        if (s != existing) s,
      result,
    ];
    _save(ref, base, segs);
  }

  static String _time(int minuteOfDay) {
    final h = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
    final m = (minuteOfDay % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _SegmentDialog extends StatefulWidget {
  const _SegmentDialog({required this.existing, required this.unit});
  final TherapySegment? existing;
  final GlucoseUnit unit;

  @override
  State<_SegmentDialog> createState() => _SegmentDialogState();
}

class _SegmentDialogState extends State<_SegmentDialog> {
  late final TextEditingController _hour;
  late final TextEditingController _basal;
  late final TextEditingController _isf;
  late final TextEditingController _cr;
  late final TextEditingController _target;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _hour = TextEditingController(
        text: e == null ? '0' : (e.startMinuteOfDay ~/ 60).toString());
    _basal = TextEditingController(
        text: e == null ? '0.80' : e.basalUnitsPerHour.toStringAsFixed(2));
    _isf = TextEditingController(text: e == null ? '' : _disp(e.isf));
    _cr = TextEditingController(
        text: e == null ? '' : e.carbRatio.toStringAsFixed(0));
    _target = TextEditingController(text: e == null ? '' : _disp(e.targetMgdl));
  }

  String _disp(double mgdl) => widget.unit == GlucoseUnit.mmol
      ? (mgdl / kMgdlPerMmol).toStringAsFixed(1)
      : mgdl.round().toString();

  double _toMgdl(String s) {
    final v = double.tryParse(s) ?? 0;
    return widget.unit == GlucoseUnit.mmol ? v * kMgdlPerMmol : v;
  }

  @override
  void dispose() {
    for (final c in [_hour, _basal, _isf, _cr, _target]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.unit.label;
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add segment' : 'Edit segment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_hour, 'Start hour (0–23)'),
            _field(_basal, 'Basal (U/h)'),
            _field(_isf, 'ISF (1U drops $label by)'),
            _field(_cr, 'Carb ratio (1U per g)'),
            _field(_target, 'Target ($label)'),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final hour = (int.tryParse(_hour.text) ?? 0).clamp(0, 23);
            final isf = _toMgdl(_isf.text);
            final carbRatio = double.tryParse(_cr.text) ?? 10;
            // TASK-190: ISF/CR feed straight divisors in the bolus/predictor math — a
            // zero here doesn't fail loudly, it turns into a NaN/Infinity dose or chart
            // point downstream, so reject it right at the input boundary.
            if (isf <= 0 || carbRatio <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:
                      Text('ISF and carb ratio must both be greater than zero.')));
              return;
            }
            Navigator.of(context).pop(TherapySegment(
              startMinuteOfDay: hour * 60,
              basalUnitsPerHour: double.tryParse(_basal.text) ?? 0,
              isf: isf,
              carbRatio: carbRatio,
              targetMgdl: _toMgdl(_target.text),
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              InputDecoration(labelText: label, isDense: true),
        ),
      );
}
