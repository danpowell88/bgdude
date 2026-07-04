/// A [CustomPaint]-based Clarke Error Grid chart for the advanced/accuracy UI.
///
/// Plots (reference vs predicted) glucose pairs on the canonical 0–400 mg/dL
/// Clarke grid, colouring each point by the zone reported by
/// [ClarkeErrorGrid.classify]. Axis labels are rendered in the caller's display
/// unit. The widget is theme-aware and degrades gracefully to an empty grid when
/// no points are supplied.
library;

import 'package:flutter/material.dart';

import '../../core/units.dart';
import '../../ml/error_grid.dart';

/// A square Clarke Error Grid scatter chart.
///
/// [points] are (reference, predicted) glucose pairs in **mg/dL** (the storage
/// unit). [unit] controls only the axis label formatting. The widget expands to
/// the available space but forces a 1:1 aspect ratio so the grid stays square.
class ErrorGridChart extends StatelessWidget {
  const ErrorGridChart({
    super.key,
    required this.points,
    this.unit = GlucoseUnit.mmol,
  });

  /// Reference/predicted pairs in mg/dL. `reference` is the ground-truth actual,
  /// `predicted` is the model estimate.
  final List<({double referenceMgdl, double predictedMgdl})> points;

  /// Display unit for the axis tick labels.
  final GlucoseUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _ErrorGridPainter(
              points: points,
              unit: unit,
              foreground: theme.colorScheme.onSurface,
              gridline: theme.colorScheme.onSurface.withValues(alpha: 0.12),
              axisLine: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              zoneBoundary: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              surface: theme.colorScheme.surface,
              textStyle: theme.textTheme.labelSmall ??
                  const TextStyle(fontSize: 10),
            ),
          );
        },
      ),
    );
  }
}

/// Fixed axis maximum for the Clarke grid (mg/dL).
const double _maxMgdl = 400.0;

/// Colours used for each Clarke zone (order matches [ClarkeZone.values]).
Color _zoneColor(ClarkeZone zone) {
  switch (zone) {
    case ClarkeZone.a:
      return const Color(0xFF2E7D32); // green — clinically accurate
    case ClarkeZone.b:
      return const Color(0xFF42A5F5); // blue — benign error
    case ClarkeZone.c:
      return const Color(0xFFF9A825); // amber — over-correction
    case ClarkeZone.d:
      return const Color(0xFFEF6C00); // orange — dangerous miss
    case ClarkeZone.e:
      return const Color(0xFFC62828); // red — wrong treatment
  }
}

String _zoneLabel(ClarkeZone zone) => switch (zone) {
      ClarkeZone.a => 'A',
      ClarkeZone.b => 'B',
      ClarkeZone.c => 'C',
      ClarkeZone.d => 'D',
      ClarkeZone.e => 'E',
    };

class _ErrorGridPainter extends CustomPainter {
  _ErrorGridPainter({
    required this.points,
    required this.unit,
    required this.foreground,
    required this.gridline,
    required this.axisLine,
    required this.zoneBoundary,
    required this.surface,
    required this.textStyle,
  });

  final List<({double referenceMgdl, double predictedMgdl})> points;
  final GlucoseUnit unit;
  final Color foreground;
  final Color gridline;
  final Color axisLine;
  final Color zoneBoundary;
  final Color surface;
  final TextStyle textStyle;

  static const ClarkeErrorGrid _grid = ClarkeErrorGrid();

  @override
  void paint(Canvas canvas, Size size) {
    // Reserve a margin on the left (Y labels) and bottom (X labels).
    const double leftPad = 34.0;
    const double bottomPad = 22.0;
    const double topPad = 6.0;
    const double rightPad = 6.0;

    final plot = Rect.fromLTRB(
      leftPad,
      topPad,
      size.width - rightPad,
      size.height - bottomPad,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    // Map an (mg/dL, mg/dL) pair to canvas coordinates. Y is inverted.
    Offset toCanvas(double refMgdl, double predMgdl) {
      final x = plot.left + (refMgdl / _maxMgdl) * plot.width;
      final y = plot.bottom - (predMgdl / _maxMgdl) * plot.height;
      return Offset(x, y);
    }

    _drawGridAndAxes(canvas, plot, toCanvas);
    _drawZoneBoundaries(canvas, plot, toCanvas);
    _drawPoints(canvas, toCanvas);
    _drawLegend(canvas, size, plot);
  }

  void _drawGridAndAxes(
    Canvas canvas,
    Rect plot,
    Offset Function(double, double) toCanvas,
  ) {
    final gridPaint = Paint()
      ..color = gridline
      ..strokeWidth = 1.0;
    final axisPaint = Paint()
      ..color = axisLine
      ..strokeWidth = 1.4;

    // Ticks every 100 mg/dL.
    const ticks = [0.0, 100.0, 200.0, 300.0, 400.0];
    for (final t in ticks) {
      // Vertical gridline (constant reference).
      final vTop = toCanvas(t, _maxMgdl);
      final vBot = toCanvas(t, 0);
      canvas.drawLine(vTop, vBot, gridPaint);
      // Horizontal gridline (constant predicted).
      final hLeft = toCanvas(0, t);
      final hRight = toCanvas(_maxMgdl, t);
      canvas.drawLine(hLeft, hRight, gridPaint);

      final labelText = _formatTick(t);
      // X axis label (below plot).
      _drawText(
        canvas,
        labelText,
        Offset(toCanvas(t, 0).dx, plot.bottom + 4),
        align: TextAlign.center,
      );
      // Y axis label (left of plot).
      _drawText(
        canvas,
        labelText,
        Offset(plot.left - 4, toCanvas(0, t).dy),
        align: TextAlign.right,
        anchorRight: true,
        anchorMiddleV: true,
      );
    }

    // Axis lines.
    canvas.drawLine(
        Offset(plot.left, plot.top), Offset(plot.left, plot.bottom), axisPaint);
    canvas.drawLine(Offset(plot.left, plot.bottom),
        Offset(plot.right, plot.bottom), axisPaint);
  }

  String _formatTick(double mgdl) {
    if (unit == GlucoseUnit.mmol) {
      return Mgdl(mgdl).mmol.toStringAsFixed(0);
    }
    return mgdl.toStringAsFixed(0);
  }

  /// Draws the canonical-ish Clarke separators so the chart reads as a Clarke
  /// grid: the identity diagonal, the ±20% A-zone wedge, and the key D/E lines.
  void _drawZoneBoundaries(
    Canvas canvas,
    Rect plot,
    Offset Function(double, double) toCanvas,
  ) {
    final linePaint = Paint()
      ..color = zoneBoundary
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    void seg(double r1, double p1, double r2, double p2) {
      canvas.drawLine(toCanvas(r1, p1), toCanvas(r2, p2), linePaint);
    }

    // Identity line (perfect prediction).
    seg(0, 0, _maxMgdl, _maxMgdl);

    // A-zone ±20% wedge: pred = 1.2*ref and pred = 0.8*ref, from ref=70 up.
    seg(70, 84, _maxMgdl, _maxMgdl * 0.8); // lower bound pred = 0.8*ref
    seg(70, 56, _maxMgdl / 1.2, _maxMgdl); // upper bound pred = 1.2*ref (clip)

    // A-zone box in the low region (both <= 70).
    seg(0, 70, 70, 70); // horizontal pred = 70 up to ref = 70
    seg(70, 0, 70, 70); // vertical ref = 70 up to pred = 70

    // E-zone separators (wrong treatment corners).
    seg(0, 180, 70, 180); // ref low, pred high
    seg(180, 0, 180, 70); // ref high, pred low
    seg(70, 180, 70, _maxMgdl); // ref = 70 vertical into upper-left
    seg(180, 70, _maxMgdl, 70); // pred = 70 horizontal into lower-right

    // D-zone separators (dangerous misses — reference far out, pred in range).
    seg(240, 70, _maxMgdl, 70); // pred = 70 line for high ref
    seg(240, 180, _maxMgdl, 180); // pred = 180 line for high ref
    seg(240, 70, 240, 180); // ref = 240 vertical band

    // C-zone separator (over-correction upper wedge).
    seg(70, 180, 180, _maxMgdl);
  }

  void _drawPoints(Canvas canvas, Offset Function(double, double) toCanvas) {
    for (final p in points) {
      final zone = _grid.classify(p.referenceMgdl, p.predictedMgdl);
      final center = toCanvas(
        p.referenceMgdl.clamp(0.0, _maxMgdl),
        p.predictedMgdl.clamp(0.0, _maxMgdl),
      );
      final fill = Paint()
        ..color = _zoneColor(zone).withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawCircle(center, 3.0, fill);
      canvas.drawCircle(center, 3.0, stroke);
    }
  }

  void _drawLegend(Canvas canvas, Size size, Rect plot) {
    // Count points per zone.
    final counts = <ClarkeZone, int>{for (final z in ClarkeZone.values) z: 0};
    for (final p in points) {
      final z = _grid.classify(p.referenceMgdl, p.predictedMgdl);
      counts[z] = (counts[z] ?? 0) + 1;
    }

    const double swatch = 8.0;
    const double gap = 3.0;
    const double rowH = 13.0;
    // Legend sits in the top-left corner of the plot area.
    double y = plot.top + 4;
    final double x = plot.left + 6;
    for (final z in ClarkeZone.values) {
      final rect = Rect.fromLTWH(x, y, swatch, swatch);
      canvas.drawRect(
        rect,
        Paint()..color = _zoneColor(z),
      );
      _drawText(
        canvas,
        '${_zoneLabel(z)} ${counts[z]}',
        Offset(x + swatch + gap, y - 1),
      );
      y += rowH;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos, {
    TextAlign align = TextAlign.left,
    bool anchorRight = false,
    bool anchorMiddleV = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
          text: text, style: textStyle.copyWith(color: foreground)),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = pos.dx;
    var dy = pos.dy;
    if (align == TextAlign.center) {
      dx -= tp.width / 2;
    } else if (anchorRight) {
      dx -= tp.width;
    }
    if (anchorMiddleV) {
      dy -= tp.height / 2;
    }
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _ErrorGridPainter old) {
    return old.points != points ||
        old.unit != unit ||
        old.foreground != foreground ||
        old.surface != surface;
  }
}
