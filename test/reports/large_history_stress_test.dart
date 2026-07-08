/// TASK-195: report/metrics/training over a realistic multi-year CGM history
/// (~365 days × 288 samples/day ≈ 105k rows) — several of these paths recompute over
/// the full list, and none had been exercised past a single simulated day.
///
/// Bounds below are deliberately generous (2-5x the observed local time on a normal
/// dev machine) so the test is robust to slower CI hardware while still catching a
/// genuine algorithmic regression (e.g. an accidental O(n²) pass) rather than
/// tripping on ordinary machine-to-machine variance.
library;

import 'package:bgdude/analytics/metrics.dart';
import 'package:bgdude/reports/glucose_report.dart';
import 'package:bgdude/reports/report_range.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/large_history.dart';

void main() {
  final start = DateTime(2025, 7, 8);
  final cgm = yearsOfCgm(start: start, days: 365);

  test('a year of CGM is really ~105k rows (sanity-check the generator)', () {
    expect(cgm.length, closeTo(365 * 288, 5));
  });

  test('MetricsCalculator.compute completes within 2s over a year of data', () {
    final sw = Stopwatch()..start();
    final metrics = const MetricsCalculator().compute(cgm);
    sw.stop();

    expect(metrics.readingCount, greaterThan(100000));
    expect(sw.elapsedMilliseconds, lessThan(2000),
        reason: 'BOUND (TASK-195): metrics over ~105k rows should be near-instant; '
            'a regression past 2s likely means an accidental O(n²) pass');
  });

  test('GlucoseReportBuilder.build completes within 5s over a year of data', () {
    final now = start.add(const Duration(days: 365));
    final range = ReportRange(
        from: start, to: now, preset: ReportPreset.custom);
    final sw = Stopwatch()..start();
    final report = const GlucoseReportBuilder()
        .build(cgm: cgm, annotations: const [], range: range, now: now);
    sw.stop();

    expect(report.metrics.readingCount, greaterThan(100000));
    expect(sw.elapsedMilliseconds, lessThan(5000),
        reason: 'BOUND (TASK-195): a full report (metrics + AGP + episode '
            'detection) over ~105k rows should stay well under 5s');
  });
}
