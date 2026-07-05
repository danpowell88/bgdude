import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reports/report_range.dart';
import '../../state/providers.dart';

/// Horizontal preset chips (7/14/30/90 days) that drive [reportRangeProvider], shared by
/// every report screen.
class ReportRangePicker extends ConsumerWidget {
  const ReportRangePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportRangeProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final p in const [
              ReportPreset.last7,
              ReportPreset.last14,
              ReportPreset.last30,
              ReportPreset.last90,
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(p.label),
                  selected: range.preset == p,
                  onSelected: (_) => ref.read(reportRangeProvider.notifier).state =
                      ReportRange.preset(p, now: DateTime.now()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
