/// Infusion-site lifetime insights (TASK-152): correlates `siteFailure`
/// annotations and Time in Range against how many days into the current
/// infusion set's wear they occurred — turning scattered failure annotations
/// into a personal set-lifetime estimate ("failures cluster after ~2.6 days")
/// and a TIR-by-set-day curve, rather than leaving the user to notice the
/// pattern themselves.
library;

import '../analytics/metrics.dart';
import '../core/samples.dart';
import '../feedback/annotations.dart';
import '../logging/device_changes.dart';
import 'report_range.dart';

class SiteLifetimeReport {
  const SiteLifetimeReport({
    required this.range,
    required this.generatedAt,
    required this.failureAgesHours,
    required this.medianFailureAgeHours,
    required this.tirBySetDay,
  });

  final ReportRange range;
  final DateTime generatedAt;

  /// Age (hours since the site was last changed) at each `siteFailure`
  /// annotation with a known preceding change — one entry per failure.
  final List<double> failureAgesHours;

  /// Median of [failureAgesHours]. Null with fewer than 3 data points — too
  /// little to call it a personal pattern rather than noise.
  final double? medianFailureAgeHours;

  /// Day-of-set-wear (1 = the first 24h, 2 = the next 24h, …) → Time in Range
  /// that day, pooled across every site change in range with enough CGM
  /// coverage that day. Capped at day 14 — anything older is stale
  /// bookkeeping (a missed change-log entry), not a real wear pattern.
  final Map<int, double> tirBySetDay;

  bool get hasData => failureAgesHours.isNotEmpty || tirBySetDay.isNotEmpty;
}

class SiteLifetimeReportBuilder {
  const SiteLifetimeReportBuilder();

  /// Caps how many days of wear are tracked in [SiteLifetimeReport.tirBySetDay]
  /// — beyond this, "days since last logged change" almost certainly means a
  /// change was never logged, not that the set is genuinely that old.
  static const int maxTrackedSetDay = 14;

  /// Below this many failure-age data points, a median is noise rather than a
  /// real personal pattern.
  static const int minFailuresForMedian = 3;

  SiteLifetimeReport build({
    required List<Annotation> annotations,
    required List<DeviceChange> siteChanges,
    required List<CgmSample> cgm,
    required ReportRange range,
    required DateTime now,
  }) {
    final sortedChanges = [...siteChanges]
      ..sort((a, b) => a.changedAt.compareTo(b.changedAt));

    // The most recent site change at or before [t], or null if [t] predates
    // every logged change.
    DateTime? lastChangeBefore(DateTime t) {
      DateTime? best;
      for (final c in sortedChanges) {
        if (c.changedAt.isAfter(t)) break;
        best = c.changedAt;
      }
      return best;
    }

    final failures = annotations.where((a) =>
        a.kind == AnnotationKind.siteFailure && range.contains(a.start));
    final failureAges = <double>[];
    for (final f in failures) {
      final changedAt = lastChangeBefore(f.start);
      if (changedAt == null) continue;
      failureAges.add(f.start.difference(changedAt).inMinutes / 60.0);
    }
    failureAges.sort();
    double? median;
    if (failureAges.length >= minFailuresForMedian) {
      final mid = failureAges.length ~/ 2;
      median = failureAges.length.isOdd
          ? failureAges[mid]
          : (failureAges[mid - 1] + failureAges[mid]) / 2;
    }

    final byDay = <int, List<CgmSample>>{};
    for (final s in cgm) {
      if (!range.contains(s.time)) continue;
      final changedAt = lastChangeBefore(s.time);
      if (changedAt == null) continue;
      final dayIndex = s.time.difference(changedAt).inHours ~/ 24 + 1;
      if (dayIndex < 1 || dayIndex > maxTrackedSetDay) continue;
      (byDay[dayIndex] ??= []).add(s);
    }
    const calc = MetricsCalculator();
    final tirBySetDay = {
      for (final entry in byDay.entries)
        entry.key: calc.compute(entry.value).timeInRange,
    };

    return SiteLifetimeReport(
      range: range,
      generatedAt: now,
      failureAgesHours: failureAges,
      medianFailureAgeHours: median,
      tirBySetDay: tirBySetDay,
    );
  }
}
