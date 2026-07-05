/// Total-insulin accounting (TDD-style): bolus units + integrated basal delivery over a
/// window. Derived from the app's own history rather than read from the pump, so it works
/// with the read-only data we already sync and stays consistent with our IOB math.
library;

import '../core/samples.dart';

class InsulinTotals {
  const InsulinTotals({required this.bolus, required this.basal});

  /// Bolus units delivered in the window.
  final double bolus;

  /// Basal units delivered in the window (rate integrated over time).
  final double basal;

  double get total => bolus + basal;
  double get basalFraction => total <= 0 ? 0 : basal / total;
}

/// Sum bolus + basal delivery in `[from, to)`. Basal segments are clipped to the window,
/// so a segment straddling either edge contributes only its in-window portion.
InsulinTotals insulinTotals({
  required List<BolusEvent> boluses,
  required List<BasalSegment> basal,
  required DateTime from,
  required DateTime to,
}) {
  var bolus = 0.0;
  for (final b in boluses) {
    if (!b.time.isBefore(from) && b.time.isBefore(to)) bolus += b.units;
  }

  var basalUnits = 0.0;
  for (final seg in basal) {
    final start = seg.start.isBefore(from) ? from : seg.start;
    final end = seg.end.isAfter(to) ? to : seg.end;
    final minutes = end.difference(start).inMinutes;
    if (minutes > 0) basalUnits += seg.unitsPerHour * minutes / 60.0;
  }

  return InsulinTotals(bolus: bolus, basal: basalUnits);
}
