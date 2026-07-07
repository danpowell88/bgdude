/// Carbohydrate absorption and carbs-on-board (COB) math.
///
/// Uses a piecewise-linear absorption model with a nonlinear "bilinear" ramp
/// (Loop-style): absorption ramps up, holds, then ramps down over the entry's
/// absorption time. The dynamic variant can stretch/shrink the absorption time from
/// observed glucose deviation, but the base COB uses the declared absorption time.
///
/// Carb *effect* on glucose = absorbed grams × (ISF / CR), i.e. the glucose rise one
/// gram of carb produces given the user's insulin sensitivity and carb ratio (this is
/// the Carb Sensitivity Factor, CSF).
library;

import '../core/samples.dart';
import '../core/units.dart';

class CarbModel {
  const CarbModel({this.minAbsorptionMinutes = 30});

  /// Absorption never modelled as faster than this, for stability.
  final int minAbsorptionMinutes;

  /// Fraction (0..1) of a carb entry still *unabsorbed* [minutesAgo] after eating,
  /// using a symmetric bilinear absorption profile over [absorptionMinutes].
  double cobFraction(double minutesAgo, double absorptionMinutes) {
    final t = minutesAgo;
    final td = absorptionMinutes < minAbsorptionMinutes
        ? minAbsorptionMinutes.toDouble()
        : absorptionMinutes;
    if (t <= 0) return 1.0;
    if (t >= td) return 0.0;

    // Bilinear: absorption rate ramps linearly to a peak at td/2 then back down.
    // Cumulative absorbed fraction is the integral of that triangle.
    final half = td / 2;
    if (t < half) {
      // Rising limb: absorbed = t^2 / (td*half) ... normalised so total=1.
      return 1 - (t * t) / (td * half);
    } else {
      final rem = td - t;
      return (rem * rem) / (td * half);
    }
  }

  /// Grams still on board at [at] across all entries.
  double cob(Iterable<CarbEntry> entries, DateTime at) {
    var grams = 0.0;
    for (final e in entries) {
      final minutesAgo = at.difference(e.time).inMinutes.toDouble();
      if (minutesAgo < 0) continue;
      grams += e.grams * cobFraction(minutesAgo, e.absorptionMinutes.toDouble());
    }
    return grams;
  }

  /// Instantaneous carb absorption in grams/min at [minutesAgo] for one entry.
  double absorptionRate(
    double minutesAgo,
    double grams,
    double absorptionMinutes,
  ) {
    final td = absorptionMinutes < minAbsorptionMinutes
        ? minAbsorptionMinutes.toDouble()
        : absorptionMinutes;
    final t = minutesAgo;
    if (t <= 0 || t >= td) return 0.0;
    final half = td / 2;
    // Triangle peak height so area = grams: peak rate = 2*grams/td.
    final peak = 2 * grams / td;
    final rate = t < half ? peak * (t / half) : peak * ((td - t) / half);
    return rate;
  }
}

/// Carb Sensitivity Factor: mg/dL rise per gram of carb = ISF / CR.
double carbSensitivityFactor({required double isf, required double carbRatio}) {
  // TASK-190: carbRatio is guarded at the input boundary (therapy_settings_screen,
  // TherapySegment.fromJson), but an assert alone is stripped in release/profile
  // builds — safeDivide keeps a stray zero from turning into an Infinity CSF that
  // then poisons a whole forecast line via `rate * csf` (0 * Infinity = NaN).
  return safeDivide(isf, carbRatio);
}
