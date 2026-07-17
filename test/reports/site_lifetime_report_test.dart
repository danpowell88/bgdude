import 'package:bgdude/core/samples.dart';
import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/logging/device_changes.dart';
import 'package:bgdude/reports/report_range.dart';
import 'package:bgdude/reports/site_lifetime_report.dart';
import 'package:flutter_test/flutter_test.dart';

ReportRange _range(DateTime from, DateTime to) =>
    ReportRange(from: from, to: to, preset: ReportPreset.custom);

DeviceChange _change(DateTime at) =>
    DeviceChange(kind: DeviceKind.site, changedAt: at);

Annotation _siteFailure(DateTime start) => Annotation(
      id: 'f-${start.millisecondsSinceEpoch}',
      kind: AnnotationKind.siteFailure,
      start: start,
      end: start.add(const Duration(hours: 1)),
    );

void main() {
  const builder = SiteLifetimeReportBuilder();
  final range = _range(DateTime(2026, 7, 1), DateTime(2026, 7, 15));

  group('failure ages', () {
    test('computes the age of each failure relative to the preceding site '
        'change', () {
      final changedAt = DateTime(2026, 7, 3, 8);
      final failureAt = changedAt.add(const Duration(hours: 60)); // 2.5 days

      final report = builder.build(
        annotations: [_siteFailure(failureAt)],
        siteChanges: [_change(changedAt)],
        cgm: const [],
        range: range,
        now: DateTime(2026, 7, 15),
      );

      expect(report.failureAgesHours, [60.0]);
      // Below minFailuresForMedian (3) -> no median yet.
      expect(report.medianFailureAgeHours, isNull);
    });

    test('a failure with no preceding site change is skipped, not counted '
        'as age zero', () {
      final report = builder.build(
        annotations: [_siteFailure(DateTime(2026, 7, 5))],
        siteChanges: const [], // no changes logged at all
        cgm: const [],
        range: range,
        now: DateTime(2026, 7, 15),
      );
      expect(report.failureAgesHours, isEmpty);
      expect(report.hasData, isFalse);
    });

    test('median requires at least minFailuresForMedian data points', () {
      final base = DateTime(2026, 7, 1);
      final changes = [
        _change(base),
        _change(base.add(const Duration(days: 3))),
        _change(base.add(const Duration(days: 6))),
      ];
      final failures = [
        _siteFailure(base.add(const Duration(hours: 48))), // 48h
        _siteFailure(base.add(const Duration(days: 3, hours: 60))), // 60h
        _siteFailure(base.add(const Duration(days: 6, hours: 72))), // 72h
      ];
      final report = builder.build(
        annotations: failures,
        siteChanges: changes,
        cgm: const [],
        range: range,
        now: DateTime(2026, 7, 15),
      );
      expect(report.failureAgesHours, hasLength(3));
      expect(report.medianFailureAgeHours, closeTo(60.0, 1e-9));
    });

    test('an even number of failures takes the mean of the middle pair', () {
      final base = DateTime(2026, 7, 1);
      final changes = [
        for (var i = 0; i < 4; i++) _change(base.add(Duration(days: 3 * i))),
      ];
      // Ages 40h, 50h, 70h, 80h -> median (50 + 70) / 2 = 60h.
      final failures = [
        for (final (i, age) in const [40, 50, 70, 80].indexed)
          _siteFailure(base.add(Duration(days: 3 * i, hours: age))),
      ];
      final report = builder.build(
        annotations: failures,
        siteChanges: changes,
        cgm: const [],
        range: range,
        now: DateTime(2026, 7, 15),
      );
      expect(report.failureAgesHours, hasLength(4));
      expect(report.medianFailureAgeHours, closeTo(60.0, 1e-9));
    });

    test('a siteFailure annotation outside the report range is excluded', () {
      final changedAt = DateTime(2026, 6, 1);
      final report = builder.build(
        annotations: [
          _siteFailure(changedAt.add(const Duration(hours: 48))), // in June
        ],
        siteChanges: [_change(changedAt)],
        cgm: const [],
        range: range, // July 1-15
        now: DateTime(2026, 7, 15),
      );
      expect(report.failureAgesHours, isEmpty);
    });
  });

  group('TIR by set day', () {
    test('buckets CGM samples by day-of-wear relative to the last site '
        'change before each sample', () {
      final changedAt = DateTime(2026, 7, 5, 8);
      final cgm = [
        // Day 1 (first 24h): a clean, in-range reading.
        CgmSample(
            time: changedAt.add(const Duration(hours: 2)), mgdl: 110),
        // Day 2: a high reading (out of range).
        CgmSample(
            time: changedAt.add(const Duration(hours: 30)), mgdl: 220),
      ];
      final report = builder.build(
        annotations: const [],
        siteChanges: [_change(changedAt)],
        cgm: cgm,
        range: range,
        now: DateTime(2026, 7, 15),
      );
      expect(report.tirBySetDay[1], 1.0); // the one day-1 reading was in range
      expect(report.tirBySetDay[2], 0.0); // the one day-2 reading was high
    });

    test('a sample before any logged site change is excluded from the '
        'curve', () {
      final changedAt = DateTime(2026, 7, 5);
      final cgm = [
        CgmSample(
            time: changedAt.subtract(const Duration(hours: 1)), mgdl: 110),
      ];
      final report = builder.build(
        annotations: const [],
        siteChanges: [_change(changedAt)],
        cgm: cgm,
        range: range,
        now: DateTime(2026, 7, 15),
      );
      expect(report.tirBySetDay, isEmpty);
    });

    test('a day of wear beyond maxTrackedSetDay is not bucketed', () {
      final changedAt = DateTime(2026, 7, 1);
      final wideRange = _range(DateTime(2026, 7, 1), DateTime(2026, 7, 31));
      final cgm = [
        CgmSample(
            time: changedAt.add(const Duration(days: 20)), mgdl: 110),
      ];
      final report = builder.build(
        annotations: const [],
        siteChanges: [_change(changedAt)],
        cgm: cgm,
        range: wideRange,
        now: DateTime(2026, 7, 25),
      );
      expect(report.tirBySetDay, isEmpty);
    });
  });

  test('no failures, no CGM -> no data', () {
    final report = builder.build(
      annotations: const [],
      siteChanges: const [],
      cgm: const [],
      range: range,
      now: DateTime(2026, 7, 15),
    );
    expect(report.hasData, isFalse);
  });
}
