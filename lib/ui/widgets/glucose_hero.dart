import 'package:flutter/material.dart';

import '../../core/samples.dart';
import '../../core/units.dart';
import 'glucose_colors.dart';

/// The big current-glucose display with a trend arrow and range colouring. Behind the
/// number sits a subtle sparkline of what glucose has done across the day, so the current
/// reading is shown in the context of its own trend.
class GlucoseHero extends StatelessWidget {
  const GlucoseHero({
    super.key,
    required this.mgdl,
    required this.trend,
    required this.unit,
    this.time,
    this.dayTrend = const [],
  });

  final double? mgdl;
  final GlucoseTrend trend;
  final GlucoseUnit unit;
  final DateTime? time;

  /// The day's glucose readings (mg/dL), oldest→newest, drawn faintly behind the number.
  final List<double> dayTrend;

  @override
  Widget build(BuildContext context) {
    final value = mgdl;
    final color = value == null
        ? Theme.of(context).colorScheme.outline
        : GlucoseColors.forMgdl(value);
    final display = value == null ? '—' : Mgdl(value).display(unit);
    final staleness = _staleness();

    final content = Column(
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
    );

    // TASK-150: the primary safety readout must be readable under TalkBack —
    // the glyphs alone announce as raw symbols or nothing.
    return Semantics(
      label: semanticLabelFor(
          mgdl: value, trend: trend, unit: unit, staleness: staleness),
      container: true,
      // The number/arrow/unit texts are decorative once the composed label reads.
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // The day's trend, drawn faintly across the whole card behind the number.
            if (dayTrend.length >= 2)
              Positioned.fill(
                child: CustomPaint(
                  painter: _DayTrendPainter(
                    values: dayTrend,
                    color: color,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: content,
            ),
          ],
        ),
      ),
    );
  }

  /// The screen-reader sentence: "<value> <unit>, <trend words>, <range status>"
  /// (plus staleness when present). Public so tests can pin it.
  static String semanticLabelFor({
    required double? mgdl,
    required GlucoseTrend trend,
    required GlucoseUnit unit,
    String? staleness,
  }) {
    if (mgdl == null) return 'No glucose reading';
    final range = mgdl < GlucoseThresholds.low
        ? 'low'
        : mgdl > GlucoseThresholds.high
            ? 'high'
            : 'in range';
    final parts = [
      '${Mgdl(mgdl).display(unit)} ${unit.label}',
      _trendWords(trend),
      range,
      if (staleness != null) staleness,
    ];
    return parts.join(', ');
  }

  static String _trendWords(GlucoseTrend t) => switch (t) {
        GlucoseTrend.doubleUp => 'rising fast',
        GlucoseTrend.singleUp => 'rising',
        GlucoseTrend.fortyFiveUp => 'rising slowly',
        GlucoseTrend.flat => 'steady',
        GlucoseTrend.fortyFiveDown => 'falling slowly',
        GlucoseTrend.singleDown => 'falling',
        GlucoseTrend.doubleDown => 'falling fast',
        GlucoseTrend.unknown => 'trend unknown',
      };

  String? _staleness() {
    if (time == null) return null;
    final mins = DateTime.now().difference(time!).inMinutes;
    if (mins <= 1) return 'just now';
    if (mins > 15) return '$mins min ago — stale';
    return '$mins min ago';
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

/// Paints the day's glucose as a faint line + gradient fill spanning the card, scaled to
/// the min/max of the data (with a small margin). Decorative context behind the number —
/// intentionally axis-free; the labelled charts live below on the Today tab.
class _DayTrendPainter extends CustomPainter {
  _DayTrendPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var lo = values.first, hi = values.first;
    for (final v in values) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    // A little vertical margin so the line never hugs the top/bottom edge.
    final span = (hi - lo).abs() < 1 ? 1.0 : (hi - lo);
    final pad = span * 0.15;
    lo -= pad;
    hi += pad;

    // Keep the trend in the lower ~70% of the card so it reads as a backdrop under the
    // number rather than crossing straight through it.
    final top = size.height * 0.30;
    final usableH = size.height - top;

    double x(int i) => size.width * (i / (values.length - 1));
    double y(double v) => top + usableH * (1 - (v - lo) / (hi - lo));

    final path = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_DayTrendPainter old) =>
      old.values != values || old.color != color;
}
