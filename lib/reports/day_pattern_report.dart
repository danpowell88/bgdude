/// Day-type clustering (TASK-154): a flat AGP hides routine-driven patterns
/// ("weekend mornings run higher"), so this splits days by weekday/weekend and,
/// once there's enough history, also runs an on-device, deterministic k-means
/// (k=2) over per-day feature vectors (mean glucose, Time in Range, Time Below
/// Range, hour of the day's peak) — surfacing whatever grouping actually
/// separates the user's own days, not just the calendar.
///
/// No randomness (matches the rest of `ml/`'s determinism convention, see
/// `gbm.dart`): centroids are seeded from the lowest- and highest-mean-glucose
/// days rather than a random draw, so the same history always clusters the
/// same way.
library;

import 'dart:math' as math;

import '../analytics/metrics.dart';
import '../core/samples.dart';
import '../core/units.dart';
import 'report_range.dart';

/// One day's feature vector.
class DayFeatures {
  const DayFeatures({
    required this.date,
    required this.meanMgdl,
    required this.tir,
    required this.tbr,
    required this.peakHour,
  });

  final DateTime date;
  final double meanMgdl;

  /// Fraction of readings in [GlucoseThresholds.low, GlucoseThresholds.high].
  final double tir;

  /// Fraction of readings below [GlucoseThresholds.low].
  final double tbr;

  /// Hour of day (0-23) of this day's highest reading.
  final double peakHour;

  bool get isWeekend =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  List<double> toVector() => [meanMgdl, tir, tbr, peakHour];
}

/// A group of days plus their pooled AGP.
class DayCluster {
  const DayCluster({
    required this.label,
    required this.days,
    required this.agp,
  });

  final String label;
  final List<DayFeatures> days;
  final List<AgpBucket> agp;

  int get dayCount => days.length;

  double get avgMeanMgdl => _avg((d) => d.meanMgdl);
  double get avgTir => _avg((d) => d.tir);
  double get avgTbr => _avg((d) => d.tbr);

  double _avg(double Function(DayFeatures) sel) => days.isEmpty
      ? 0
      : days.map(sel).reduce((a, b) => a + b) / days.length;
}

class DayPatternReport {
  const DayPatternReport({
    required this.range,
    required this.generatedAt,
    required this.dayFeatures,
    required this.weekdayVsWeekend,
    this.kMeansClusters,
  });

  final ReportRange range;
  final DateTime generatedAt;
  final List<DayFeatures> dayFeatures;

  /// [Weekday, Weekend] — always present (a cluster can be empty).
  final List<DayCluster> weekdayVsWeekend;

  /// On-device k-means (k=2), or null when there isn't enough history yet
  /// (see [DayPatternReportBuilder.minDaysForKMeans]).
  final List<DayCluster>? kMeansClusters;

  bool get hasData => dayFeatures.isNotEmpty;
}

class DayPatternReportBuilder {
  const DayPatternReportBuilder({this.agpCalculator = const AgpCalculator()});

  final AgpCalculator agpCalculator;

  /// A day needs at least this many readings (~1h at 5-min cadence) before its
  /// features are trusted — a handful of stray samples shouldn't count as "a day".
  static const int minReadingsPerDay = 12;

  /// k-means needs enough days for k=2 groups to each carry a real signal, not
  /// just enough to run the algorithm at all.
  static const int minDaysForKMeans = 14;

  static const int kMeansK = 2;
  static const int kMeansMaxIterations = 20;

  DayPatternReport build({
    required List<CgmSample> cgm,
    required ReportRange range,
    required DateTime now,
  }) {
    final byDay = <DateTime, List<CgmSample>>{};
    for (final s in cgm) {
      if (!range.contains(s.time)) continue;
      if (s.sensorWarmup || s.isCalibration || s.mgdl <= 0) continue;
      final day = DateTime(s.time.year, s.time.month, s.time.day);
      (byDay[day] ??= []).add(s);
    }

    final dayFeatures = <DayFeatures>[];
    for (final entry in byDay.entries) {
      final samples = entry.value;
      if (samples.length < minReadingsPerDay) continue;
      final mean = samples.map((s) => s.mgdl.toDouble()).reduce((a, b) => a + b) /
          samples.length;
      final tir = samples
              .where((s) =>
                  s.mgdl >= GlucoseThresholds.low &&
                  s.mgdl <= GlucoseThresholds.high)
              .length /
          samples.length;
      final tbr =
          samples.where((s) => s.mgdl < GlucoseThresholds.low).length /
              samples.length;
      final peak = samples.reduce((a, b) => a.mgdl > b.mgdl ? a : b);
      dayFeatures.add(DayFeatures(
        date: entry.key,
        meanMgdl: mean,
        tir: tir,
        tbr: tbr,
        peakHour: peak.time.hour.toDouble(),
      ));
    }
    dayFeatures.sort((a, b) => a.date.compareTo(b.date));

    DayCluster buildCluster(String label, List<DayFeatures> days) {
      final samples = [for (final d in days) ...byDay[d.date]!];
      return DayCluster(
          label: label, days: days, agp: agpCalculator.compute(samples));
    }

    final weekday = [for (final d in dayFeatures) if (!d.isWeekend) d];
    final weekend = [for (final d in dayFeatures) if (d.isWeekend) d];
    final weekdayVsWeekend = [
      buildCluster('Weekday', weekday),
      buildCluster('Weekend', weekend),
    ];

    List<DayCluster>? kMeansClusters;
    if (dayFeatures.length >= minDaysForKMeans) {
      final assignment = _kMeans(dayFeatures, k: kMeansK);
      final groups = <int, List<DayFeatures>>{};
      for (var i = 0; i < dayFeatures.length; i++) {
        (groups[assignment[i]] ??= []).add(dayFeatures[i]);
      }
      // Deterministic display order: smaller cluster first, so "the unusual
      // pattern" reads first regardless of which centroid index it landed on.
      final sortedKeys = groups.keys.toList()
        ..sort((a, b) => groups[a]!.length.compareTo(groups[b]!.length));
      kMeansClusters = [
        for (var i = 0; i < sortedKeys.length; i++)
          buildCluster('Pattern ${i + 1}', groups[sortedKeys[i]]!),
      ];
    }

    return DayPatternReport(
      range: range,
      generatedAt: now,
      dayFeatures: dayFeatures,
      weekdayVsWeekend: weekdayVsWeekend,
      kMeansClusters: kMeansClusters,
    );
  }

  /// Deterministic Lloyd's-algorithm k-means over z-scored feature vectors.
  /// Centroids are seeded from the lowest- and highest-mean-glucose days
  /// (mean glucose is the feature most likely to actually separate routine
  /// patterns) rather than a random draw, so the same input always produces
  /// the same clustering.
  List<int> _kMeans(List<DayFeatures> days, {required int k}) {
    final vectors = _standardize([for (final d in days) d.toVector()]);
    final order = List<int>.generate(days.length, (i) => i)
      ..sort((a, b) => days[a].meanMgdl.compareTo(days[b].meanMgdl));
    final centroids = <List<double>>[
      for (var c = 0; c < k; c++)
        vectors[order[k == 1 ? 0 : (c * (order.length - 1) / (k - 1)).round()]],
    ];

    final assignment = List<int>.filled(days.length, -1);
    for (var iter = 0; iter < kMeansMaxIterations; iter++) {
      var changed = false;
      for (var i = 0; i < vectors.length; i++) {
        var best = 0;
        var bestDist = double.infinity;
        for (var c = 0; c < k; c++) {
          final d = _sqDist(vectors[i], centroids[c]);
          if (d < bestDist) {
            bestDist = d;
            best = c;
          }
        }
        if (assignment[i] != best) {
          assignment[i] = best;
          changed = true;
        }
      }
      if (!changed) break;
      for (var c = 0; c < k; c++) {
        final members = [
          for (var i = 0; i < vectors.length; i++)
            if (assignment[i] == c) vectors[i],
        ];
        if (members.isEmpty) continue; // keep the previous centroid
        centroids[c] = [
          for (var f = 0; f < vectors[0].length; f++)
            members.map((v) => v[f]).reduce((a, b) => a + b) / members.length,
        ];
      }
    }
    return assignment;
  }

  static List<List<double>> _standardize(List<List<double>> vectors) {
    final n = vectors.length;
    final dims = vectors.first.length;
    final means = List.filled(dims, 0.0);
    for (final v in vectors) {
      for (var f = 0; f < dims; f++) {
        means[f] += v[f];
      }
    }
    for (var f = 0; f < dims; f++) {
      means[f] /= n;
    }
    final stds = List.filled(dims, 0.0);
    for (final v in vectors) {
      for (var f = 0; f < dims; f++) {
        stds[f] += math.pow(v[f] - means[f], 2).toDouble();
      }
    }
    for (var f = 0; f < dims; f++) {
      stds[f] = math.sqrt(stds[f] / n);
    }
    return [
      for (final v in vectors)
        [
          for (var f = 0; f < dims; f++)
            stds[f] == 0 ? 0.0 : (v[f] - means[f]) / stds[f],
        ],
    ];
  }

  static double _sqDist(List<double> a, List<double> b) {
    var s = 0.0;
    for (var i = 0; i < a.length; i++) {
      final d = a[i] - b[i];
      s += d * d;
    }
    return s;
  }
}
