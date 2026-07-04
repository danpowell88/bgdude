import 'package:flutter/material.dart';

import '../../core/samples.dart';
import '../../core/units.dart';

/// The big current-glucose display with a trend arrow and range colouring.
class GlucoseHero extends StatelessWidget {
  const GlucoseHero({
    super.key,
    required this.mgdl,
    required this.trend,
    required this.unit,
    this.time,
  });

  final double? mgdl;
  final GlucoseTrend trend;
  final GlucoseUnit unit;
  final DateTime? time;

  @override
  Widget build(BuildContext context) {
    final value = mgdl;
    final color = value == null
        ? Theme.of(context).colorScheme.outline
        : _rangeColor(value, context);
    final display = value == null ? '—' : Mgdl(value).display(unit);
    final staleness = _staleness();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  display,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 12),
                Icon(_trendIcon(trend), size: 40, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(unit.label, style: Theme.of(context).textTheme.bodyMedium),
            if (staleness != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(staleness,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline)),
              ),
          ],
        ),
      ),
    );
  }

  String? _staleness() {
    if (time == null) return null;
    final mins = DateTime.now().difference(time!).inMinutes;
    if (mins <= 1) return 'just now';
    if (mins > 15) return '$mins min ago — stale';
    return '$mins min ago';
  }

  static Color _rangeColor(double mgdl, BuildContext context) {
    if (mgdl < GlucoseThresholds.low) return Colors.red;
    if (mgdl > GlucoseThresholds.high) return Colors.orange;
    return Colors.green;
  }

  static IconData _trendIcon(GlucoseTrend t) => switch (t) {
        GlucoseTrend.doubleUp => Icons.keyboard_double_arrow_up,
        GlucoseTrend.singleUp => Icons.arrow_upward,
        GlucoseTrend.fortyFiveUp => Icons.north_east,
        GlucoseTrend.flat => Icons.arrow_forward,
        GlucoseTrend.fortyFiveDown => Icons.south_east,
        GlucoseTrend.singleDown => Icons.arrow_downward,
        GlucoseTrend.doubleDown => Icons.keyboard_double_arrow_down,
        GlucoseTrend.unknown => Icons.help_outline,
      };
}
