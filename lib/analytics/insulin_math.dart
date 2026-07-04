/// Insulin activity and insulin-on-board (IOB) math.
///
/// Uses the exponential insulin model (Loop / LoopKit "ExponentialInsulinModel"),
/// which fits manufacturer PK data far better than the old bilinear/walsh curves.
/// The model is fully defined by two parameters:
///   * DIA (duration of insulin action), default 6h
///   * peak activity time, default ~75 min for rapid-acting analogues (Novorapid/Humalog)
///
/// Reference: https://loopkit.github.io/loopdocs/operation/algorithm/prediction/
/// and the LoopKit InsulinKit ExponentialInsulinModel derivation.
library;

import 'dart:math' as math;

import '../core/samples.dart';

/// Parameters of the exponential insulin activity curve.
class InsulinModel {
  const InsulinModel({
    this.durationMinutes = 360,
    this.peakMinutes = 75,
  }) : assert(peakMinutes > 0 && peakMinutes < durationMinutes);

  final int durationMinutes;
  final int peakMinutes;

  /// Rapid-acting analogue default (Novorapid / Humalog), Loop's common setting.
  static const InsulinModel rapidActing = InsulinModel();

  /// Fraction (0..1) of a delivered unit still active [minutesAgo] after delivery.
  ///
  /// Returns 1.0 for a bolus not yet delivered (minutesAgo <= 0) and 0.0 once the
  /// duration has fully elapsed.
  double iobFraction(double minutesAgo) {
    if (minutesAgo <= 0) return 1.0;
    if (minutesAgo >= durationMinutes) return 0.0;

    final td = durationMinutes.toDouble();
    final tp = peakMinutes.toDouble();
    final t = minutesAgo;

    // Derived constants (see LoopKit ExponentialInsulinModel).
    final tau = tp * (1 - tp / td) / (1 - 2 * tp / td);
    final a = 2 * tau / td;
    final s = 1 / (1 - a + (1 + a) * math.exp(-td / tau));

    return 1 -
        s *
            (1 - a) *
            ((t * t / (tau * td * (1 - a)) - t / tau - 1) * math.exp(-t / tau) +
                1);
  }

  /// Instantaneous insulin *activity* (fraction of a unit being absorbed per
  /// minute) at [minutesAgo]. Integrates to 1 over the full duration. Used to
  /// build the glucose-effect curve for prediction.
  double activity(double minutesAgo) {
    if (minutesAgo <= 0 || minutesAgo >= durationMinutes) return 0.0;

    final td = durationMinutes.toDouble();
    final tp = peakMinutes.toDouble();
    final t = minutesAgo;

    final tau = tp * (1 - tp / td) / (1 - 2 * tp / td);
    final s = 1 / (1 - (2 * tau / td) + (1 + 2 * tau / td) * math.exp(-td / tau));

    return (s / (tau * tau)) * t * (1 - t / td) * math.exp(-t / tau);
  }
}

/// Result of an IOB computation at a point in time.
class IobResult {
  const IobResult({required this.units, required this.activityUnitsPerMin});

  /// Units of insulin still on board.
  final double units;

  /// Rate at which IOB is currently lowering glucose, in units/min of insulin
  /// activity (multiply by ISF to get mg/dL per min).
  final double activityUnitsPerMin;
}

/// Computes IOB independently from bolus + basal history, rather than trusting only
/// the pump's own IOB figure. Boluses contribute directly; basal is decomposed into
/// per-minute micro-boluses. This lets the what-if engine reason about IOB even when
/// the pump read is stale.
class IobCalculator {
  const IobCalculator({this.model = InsulinModel.rapidActing});

  final InsulinModel model;

  /// Total IOB at [at] from discrete bolus events.
  IobResult fromBoluses(Iterable<BolusEvent> boluses, DateTime at) {
    var units = 0.0;
    var activity = 0.0;
    for (final b in boluses) {
      final minutesAgo = at.difference(b.time).inMinutes.toDouble();
      if (minutesAgo < 0 || minutesAgo >= model.durationMinutes) continue;
      units += b.units * model.iobFraction(minutesAgo);
      activity += b.units * model.activity(minutesAgo);
    }
    return IobResult(units: units, activityUnitsPerMin: activity);
  }

  /// IOB contribution from basal delivery, treating each basal segment as a stream
  /// of small deliveries. Only basal *in excess of* nothing is modelled here; for a
  /// closed-loop what-if you typically care about deviation from scheduled basal,
  /// but for raw IOB we count all delivered basal.
  ///
  /// [stepMinutes] controls the discretisation granularity (5 min is plenty).
  IobResult fromBasal(
    Iterable<BasalSegment> segments,
    DateTime at, {
    int stepMinutes = 5,
  }) {
    var units = 0.0;
    var activity = 0.0;
    final horizon = model.durationMinutes;
    for (final seg in segments) {
      // Walk the segment in steps, attributing units/step as a micro-bolus at the
      // step midpoint.
      final unitsPerStep = seg.unitsPerHour * stepMinutes / 60.0;
      var cursor = seg.start;
      while (cursor.isBefore(seg.end)) {
        final mid = cursor.add(Duration(minutes: stepMinutes ~/ 2));
        final minutesAgo = at.difference(mid).inMinutes.toDouble();
        cursor = cursor.add(Duration(minutes: stepMinutes));
        if (minutesAgo < 0 || minutesAgo >= horizon) continue;
        units += unitsPerStep * model.iobFraction(minutesAgo);
        activity += unitsPerStep * model.activity(minutesAgo);
      }
    }
    return IobResult(units: units, activityUnitsPerMin: activity);
  }

  /// Combined bolus + basal IOB.
  IobResult total(
    Iterable<BolusEvent> boluses,
    Iterable<BasalSegment> basal,
    DateTime at,
  ) {
    final b = fromBoluses(boluses, at);
    final s = fromBasal(basal, at);
    return IobResult(
      units: b.units + s.units,
      activityUnitsPerMin: b.activityUnitsPerMin + s.activityUnitsPerMin,
    );
  }
}
