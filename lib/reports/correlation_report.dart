/// The Correlation report: how daily glycemic outcomes (time-in-range, mean glucose)
/// relate to confirmed lifestyle inputs from Health Connect — sleep, exercise, HRV and
/// resting heart rate. Each finding shows the correlation, the number of days behind it,
/// and a plain-language reading. Correlations below a minimum day count are never shown.
///
/// Correlation is not causation — findings are prompts to explore with your care team,
/// not conclusions.
library;

import 'dart:math' as math;

import '../analytics/metrics.dart';
import '../core/samples.dart';
import '../data/health_sync.dart';
import 'report_range.dart';

class CorrelationFinding {
  const CorrelationFinding({
    required this.predictorLabel,
    required this.outcomeLabel,
    required this.r,
    required this.n,
    required this.message,
  });

  final String predictorLabel;
  final String outcomeLabel;

  /// Pearson correlation coefficient, −1..1.
  final double r;

  /// Number of days both sides were present.
  final int n;
  final String message;

  double get strength => r.abs();
}

class CorrelationReport {
  const CorrelationReport({
    required this.range,
    required this.generatedAt,
    required this.findings,
    required this.daysAnalyzed,
  });

  final ReportRange range;
  final DateTime generatedAt;

  /// Strongest first.
  final List<CorrelationFinding> findings;
  final int daysAnalyzed;

  bool get hasData => findings.isNotEmpty;
}

class CorrelationReportBuilder {
  const CorrelationReportBuilder({
    this.minDays = 7,
    this.minAbsR = 0.25,
    this.minReadingsPerDay = 100,
  });

  /// A pair needs at least this many days present on both sides to be reported.
  final int minDays;

  /// Correlations weaker than this (absolute) are treated as noise.
  final double minAbsR;

  /// A day needs at least this many CGM readings to yield a trustworthy daily outcome.
  final int minReadingsPerDay;

  CorrelationReport build({
    required List<CgmSample> cgm,
    required List<HealthSample> health,
    required ReportRange range,
    required DateTime now,
  }) {
    // Daily glucose outcomes.
    final byDayCgm = <String, List<CgmSample>>{};
    for (final s in cgm) {
      if (!range.contains(s.time) || s.sensorWarmup || s.mgdl <= 0) continue;
      (byDayCgm[_dayKey(s.time)] ??= []).add(s);
    }
    const metrics = MetricsCalculator();
    final tir = <String, double>{};
    final mean = <String, double>{};
    for (final e in byDayCgm.entries) {
      if (e.value.length < minReadingsPerDay) continue;
      final m = metrics.compute(e.value);
      tir[e.key] = m.timeInRange * 100;
      mean[e.key] = m.meanMgdl;
    }

    // Daily lifestyle predictors.
    final sleep = <String, List<double>>{};
    final exercise = <String, double>{};
    final hrv = <String, List<double>>{};
    final restingHr = <String, List<double>>{};
    for (final s in health) {
      if (!range.contains(s.time)) continue;
      final k = _dayKey(s.time);
      switch (s.type) {
        case 'sleepHours':
          (sleep[k] ??= []).add(s.value);
        case 'exercise':
          exercise[k] = (exercise[k] ?? 0) + s.value;
        case 'hrvRmssd':
          (hrv[k] ??= []).add(s.value);
        case 'restingHr':
          (restingHr[k] ??= []).add(s.value);
      }
    }

    final predictors = <({String label, Map<String, double> byDay})>[
      (label: 'sleep', byDay: {for (final e in sleep.entries) e.key: _max(e.value)}),
      (label: 'exercise', byDay: exercise),
      (label: 'HRV', byDay: {for (final e in hrv.entries) e.key: _median(e.value)}),
      (
        label: 'resting HR',
        byDay: {for (final e in restingHr.entries) e.key: _median(e.value)}
      ),
    ];
    final outcomes = <({String label, Map<String, double> byDay})>[
      (label: 'time-in-range', byDay: tir),
      (label: 'mean glucose', byDay: mean),
    ];

    final findings = <CorrelationFinding>[];
    for (final p in predictors) {
      for (final o in outcomes) {
        final xs = <double>[];
        final ys = <double>[];
        for (final day in p.byDay.keys) {
          final ov = o.byDay[day];
          if (ov == null) continue;
          xs.add(p.byDay[day]!);
          ys.add(ov);
        }
        if (xs.length < minDays) continue;
        final r = _pearson(xs, ys);
        if (r.abs() < minAbsR || r.isNaN) continue;
        findings.add(CorrelationFinding(
          predictorLabel: p.label,
          outcomeLabel: o.label,
          r: r,
          n: xs.length,
          message: _message(p.label, o.label, r, xs.length),
        ));
      }
    }
    findings.sort((a, b) => b.strength.compareTo(a.strength));

    return CorrelationReport(
      range: range,
      generatedAt: now,
      findings: findings,
      daysAnalyzed: tir.length,
    );
  }

  static String _message(String predictor, String outcome, double r, int n) {
    final dir = r > 0 ? 'higher' : 'lower';
    return 'On days with more $predictor, $outcome tended to be $dir '
        '(r ${r.toStringAsFixed(2)}, $n days).';
  }

  static String _dayKey(DateTime t) => '${t.year}-${t.month}-${t.day}';

  static double _max(List<double> v) => v.reduce(math.max);

  static double _median(List<double> v) {
    final s = [...v]..sort();
    final mid = s.length ~/ 2;
    return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2;
  }

  static double _pearson(List<double> xs, List<double> ys) {
    final n = xs.length;
    final mx = xs.reduce((a, b) => a + b) / n;
    final my = ys.reduce((a, b) => a + b) / n;
    var num = 0.0, dx = 0.0, dy = 0.0;
    for (var i = 0; i < n; i++) {
      final a = xs[i] - mx;
      final b = ys[i] - my;
      num += a * b;
      dx += a * a;
      dy += b * b;
    }
    final den = math.sqrt(dx * dy);
    return den == 0 ? double.nan : num / den;
  }
}
