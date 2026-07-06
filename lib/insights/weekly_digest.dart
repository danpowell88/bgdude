/// Weekly digest (§4-4.5): a short week-over-week roundup — time-in-range, GMI and
/// low-glucose deltas versus the prior week, plus one learned insight. Pure and
/// framework-free so it's unit-testable; delivered as a notification by the background
/// summary task on the digest day.
library;

import '../analytics/metrics.dart';

class WeeklyDigest {
  const WeeklyDigest({required this.headline, required this.lines});

  final String headline;
  final List<String> lines;

  String get body => lines.join('\n');
}

class WeeklyDigestGenerator {
  const WeeklyDigestGenerator();

  /// Build the digest from this week's and last week's [GlucoseMetrics], plus an optional
  /// one-line [learnedInsight] (e.g. from the time-of-day sensitivity profile). Returns
  /// null when this week has too little data to summarise (< ~1 day of readings).
  WeeklyDigest? generate({
    required GlucoseMetrics thisWeek,
    GlucoseMetrics? lastWeek,
    String? learnedInsight,
  }) {
    if (thisWeek.readingCount < 288) return null;

    final tir = (thisWeek.timeInRange * 100).round();
    final hasPrior = lastWeek != null && lastWeek.readingCount >= 288;

    String delta(double now, double? prev, {int decimals = 0}) {
      if (prev == null) return '';
      final d = now - prev;
      if (d.abs() < (decimals == 0 ? 0.5 : 0.05)) return ' (≈ last week)';
      final arrow = d > 0 ? '▲' : '▼';
      return ' ($arrow${d.abs().toStringAsFixed(decimals)} vs last week)';
    }

    final lines = <String>[
      'Time in range: $tir%'
          '${delta(thisWeek.timeInRange * 100, hasPrior ? lastWeek.timeInRange * 100 : null)}',
      'GMI: ${thisWeek.gmi.toStringAsFixed(1)}%'
          '${delta(thisWeek.gmi, hasPrior ? lastWeek.gmi : null, decimals: 1)}',
      'Time low (<70): ${(thisWeek.timeBelow70 * 100).toStringAsFixed(1)}%'
          '${delta(thisWeek.timeBelow70 * 100, hasPrior ? lastWeek.timeBelow70 * 100 : null, decimals: 1)}',
    ];
    if (learnedInsight != null && learnedInsight.isNotEmpty) {
      lines.add(learnedInsight);
    }

    return WeeklyDigest(headline: 'Your week: $tir% in range', lines: lines);
  }
}
