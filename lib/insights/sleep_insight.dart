/// Sleep ↔ glucose insight.
///
/// Correlates how long you slept with how steady your glucose ran overnight.
/// The hypothesis (well supported in the literature): more sleep → steadier
/// overnight glucose → lower coefficient of variation (CV%). We surface a
/// negative Pearson correlation between hours slept and overnight CV%, plus a
/// plain-language comparison of "good sleep" vs "short sleep" nights.
///
/// Nothing here is a medical claim — it's a personal pattern nudge computed
/// entirely on-device from Health Connect sleep + overnight CGM metrics.
library;

import 'dart:math' as math;

/// One night's paired sleep + overnight-glucose summary.
///
/// [night] is the calendar date the sleep began. [overnightCvPercent] and
/// [overnightTir] are computed from the CGM window covering that sleep
/// (typically ~22:00 → wake) — see [GlucoseMetrics].
class SleepNight {
  final DateTime night;
  final double sleepHours;
  final double overnightCvPercent;

  /// Overnight time-in-range as a fraction in 0..1.
  final double overnightTir;

  const SleepNight({
    required this.night,
    required this.sleepHours,
    required this.overnightCvPercent,
    required this.overnightTir,
  });
}

/// Result of a [SleepInsightAnalyzer.analyze] run.
class SleepInsight {
  /// True when there were enough nights and both sleep groups were populated.
  final bool hasSignal;

  /// Pearson correlation between sleep hours and overnight CV%, in [-1, 1].
  /// Expected to be negative (more sleep → lower CV). 0 when undefined.
  final double correlation;

  final String message;

  /// Number of nights considered.
  final int nights;

  const SleepInsight({
    required this.hasSignal,
    required this.correlation,
    required this.message,
    required this.nights,
  });
}

class SleepInsightAnalyzer {
  const SleepInsightAnalyzer({this.minNights = 10, this.goodSleepHours = 7});

  /// Minimum paired nights before we'll claim a signal.
  final int minNights;

  /// Threshold (hours) splitting "good sleep" from "short sleep" nights.
  final double goodSleepHours;

  SleepInsight analyze(List<SleepNight> nights) {
    final n = nights.length;
    if (n < minNights) {
      return SleepInsight(
        hasSignal: false,
        correlation: 0,
        message: 'Not enough nights yet — keep logging sleep and I\'ll spot '
            'how it moves your overnight glucose (need at least '
            '$minNights nights, have $n).',
        nights: n,
      );
    }

    final sleep = nights.map((e) => e.sleepHours).toList(growable: false);
    final cv = nights.map((e) => e.overnightCvPercent).toList(growable: false);
    final correlation = _pearson(sleep, cv);

    final good = nights
        .where((e) => e.sleepHours >= goodSleepHours)
        .toList(growable: false);
    final short = nights
        .where((e) => e.sleepHours < goodSleepHours)
        .toList(growable: false);

    if (good.isEmpty || short.isEmpty) {
      return SleepInsight(
        hasSignal: false,
        correlation: correlation,
        message: 'Not enough nights yet — I need a mix of longer and shorter '
            'sleep nights (around ${_trim(goodSleepHours)}h) to compare.',
        nights: n,
      );
    }

    final goodCv = _median(good.map((e) => e.overnightCvPercent).toList());
    final shortCv = _median(short.map((e) => e.overnightCvPercent).toList());
    final goodTir = _median(good.map((e) => e.overnightTir).toList());
    final shortTir = _median(short.map((e) => e.overnightTir).toList());
    final tirDeltaPts = (goodTir - shortTir) * 100;

    final steadier = goodCv <= shortCv;
    final sb = StringBuffer();
    if (steadier) {
      sb.write('Nights with ≥${_trim(goodSleepHours)}h sleep run steadier — '
          'median CV ${_pct(goodCv)} vs ${_pct(shortCv)}');
      if (tirDeltaPts.abs() >= 0.5) {
        final dir = tirDeltaPts >= 0 ? 'more' : 'less';
        sb.write(', and ${_pct(tirDeltaPts.abs())} $dir time in range');
      }
      sb.write('.');
    } else {
      sb.write('Interesting — your longer-sleep nights (≥'
          '${_trim(goodSleepHours)}h) don\'t run steadier: '
          'median CV ${_pct(goodCv)} vs ${_pct(shortCv)} on shorter nights. '
          'Something else may be driving overnight swings.');
    }

    return SleepInsight(
      hasSignal: true,
      correlation: correlation,
      message: sb.toString(),
      nights: n,
    );
  }

  /// Pearson correlation. Returns 0 when either series is constant
  /// (zero variance → undefined) or lengths mismatch / are empty.
  static double _pearson(List<double> xs, List<double> ys) {
    final n = xs.length;
    if (n == 0 || n != ys.length) return 0;
    final meanX = xs.reduce((a, b) => a + b) / n;
    final meanY = ys.reduce((a, b) => a + b) / n;
    var sxy = 0.0, sxx = 0.0, syy = 0.0;
    for (var i = 0; i < n; i++) {
      final dx = xs[i] - meanX;
      final dy = ys[i] - meanY;
      sxy += dx * dy;
      sxx += dx * dx;
      syy += dy * dy;
    }
    if (sxx == 0 || syy == 0) return 0;
    final r = sxy / math.sqrt(sxx * syy);
    return r.clamp(-1.0, 1.0);
  }

  static double _median(List<double> xs) {
    final s = [...xs]..sort();
    final n = s.length;
    if (n == 0) return 0;
    final mid = n ~/ 2;
    return n.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2;
  }

  static String _pct(double v) => '${v.round()}%';

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
