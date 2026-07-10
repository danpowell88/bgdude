import 'package:bgdude/core/samples.dart';
import 'package:bgdude/reports/day_pattern_report.dart';
import 'package:bgdude/reports/report_range.dart';
import 'package:flutter_test/flutter_test.dart';

ReportRange _range(DateTime from, DateTime to) =>
    ReportRange(from: from, to: to, preset: ReportPreset.custom);

/// A day of samples every 5 min from 00:00 to 23:55, flat at [mgdl] except a
/// single spike to [spikeMgdl] at [spikeHour]:00 (so "peak hour" is
/// deterministic and TIR/TBR are easy to hand-verify).
List<CgmSample> _day(DateTime day, {required double mgdl, int? spikeHour, double? spikeMgdl}) {
  final out = <CgmSample>[];
  for (var m = 0; m < 24 * 60; m += 5) {
    final t = day.add(Duration(minutes: m));
    final isSpike = spikeHour != null && t.hour == spikeHour && t.minute == 0;
    out.add(CgmSample(time: t, mgdl: isSpike ? spikeMgdl! : mgdl));
  }
  return out;
}

void main() {
  const builder = DayPatternReportBuilder();

  group('per-day features', () {
    test('computes mean/TIR/TBR/peakHour for a simple day', () {
      final day = DateTime(2026, 7, 6); // a Monday
      final cgm = _day(day, mgdl: 100, spikeHour: 14, spikeMgdl: 220);
      final range = _range(day, day.add(const Duration(days: 1)));

      final report =
          builder.build(cgm: cgm, range: range, now: DateTime(2026, 7, 7));

      expect(report.dayFeatures, hasLength(1));
      final f = report.dayFeatures.single;
      expect(f.peakHour, 14);
      expect(f.isWeekend, isFalse);
      // 287/288 samples at 100 (in range), 1 at 220 (above range) -> TIR just
      // under 1, TBR 0.
      expect(f.tir, closeTo(287 / 288, 1e-9));
      expect(f.tbr, 0);
    });

    test('a day with too few readings is excluded entirely', () {
      final day = DateTime(2026, 7, 6);
      final sparse = [
        CgmSample(time: day.add(const Duration(hours: 1)), mgdl: 100),
        CgmSample(time: day.add(const Duration(hours: 2)), mgdl: 105),
      ];
      final range = _range(day, day.add(const Duration(days: 1)));
      final report =
          builder.build(cgm: sparse, range: range, now: DateTime(2026, 7, 7));
      expect(report.dayFeatures, isEmpty);
      expect(report.hasData, isFalse);
    });
  });

  group('weekday vs weekend', () {
    test('splits days by calendar weekday/weekend and pools their AGP', () {
      final mon = DateTime(2026, 7, 6); // Monday
      final sat = DateTime(2026, 7, 11); // Saturday
      final cgm = [..._day(mon, mgdl: 100), ..._day(sat, mgdl: 160)];
      final range = _range(mon, sat.add(const Duration(days: 1)));

      final report =
          builder.build(cgm: cgm, range: range, now: DateTime(2026, 7, 12));

      final weekday =
          report.weekdayVsWeekend.firstWhere((c) => c.label == 'Weekday');
      final weekend =
          report.weekdayVsWeekend.firstWhere((c) => c.label == 'Weekend');
      expect(weekday.dayCount, 1);
      expect(weekend.dayCount, 1);
      expect(weekday.avgMeanMgdl, closeTo(100, 1e-6));
      expect(weekend.avgMeanMgdl, closeTo(160, 1e-6));
      expect(weekday.agp, isNotEmpty);
      expect(weekend.agp, isNotEmpty);
    });

    test('an empty group (no weekend days in range) has zero days, not a crash',
        () {
      final mon = DateTime(2026, 7, 6);
      final tue = DateTime(2026, 7, 7);
      final cgm = [..._day(mon, mgdl: 100), ..._day(tue, mgdl: 105)];
      final range = _range(mon, tue.add(const Duration(days: 1)));

      final report =
          builder.build(cgm: cgm, range: range, now: DateTime(2026, 7, 8));

      final weekend =
          report.weekdayVsWeekend.firstWhere((c) => c.label == 'Weekend');
      expect(weekend.dayCount, 0);
      expect(weekend.avgMeanMgdl, 0);
    });
  });

  group('k-means', () {
    test('stays null below minDaysForKMeans', () {
      final days = [
        for (var i = 0; i < DayPatternReportBuilder.minDaysForKMeans - 1; i++)
          DateTime(2026, 7, 1).add(Duration(days: i)),
      ];
      final cgm = [for (final d in days) ..._day(d, mgdl: 100)];
      final range =
          _range(days.first, days.last.add(const Duration(days: 1)));

      final report = builder.build(
          cgm: cgm, range: range, now: days.last.add(const Duration(days: 1)));

      expect(report.dayFeatures,
          hasLength(DayPatternReportBuilder.minDaysForKMeans - 1));
      expect(report.kMeansClusters, isNull);
    });

    test(
        'separates two clearly distinct glucose regimes into different clusters',
        () {
      // Half the days run flat around 90 mg/dL, the other half flat around 220
      // mg/dL -- an unambiguous 2-cluster split regardless of which day is
      // "weekday"/"weekend", proving the grouping is NOT just the calendar.
      final days = <DateTime>[];
      final cgm = <CgmSample>[];
      for (var i = 0; i < DayPatternReportBuilder.minDaysForKMeans; i++) {
        final d = DateTime(2026, 7, 1).add(Duration(days: i));
        days.add(d);
        cgm.addAll(_day(d, mgdl: i.isEven ? 90 : 220));
      }
      final range =
          _range(days.first, days.last.add(const Duration(days: 1)));

      final report = builder.build(
          cgm: cgm, range: range, now: days.last.add(const Duration(days: 1)));

      final clusters = report.kMeansClusters;
      expect(clusters, isNotNull);
      expect(clusters, hasLength(2));
      // Every day in a cluster shares (approximately) the same mean -- the
      // regimes were not mixed together.
      for (final c in clusters!) {
        final means = c.days.map((d) => d.meanMgdl).toSet();
        expect(means.length, 1,
            reason: 'a real cluster should not mix the two glucose regimes');
      }
      // The two clusters' means are the two distinct regimes, not the same
      // value twice.
      final clusterMeans = clusters.map((c) => c.days.first.meanMgdl).toSet();
      expect(clusterMeans, {90.0, 220.0});
    });

    test('is deterministic across repeated builds of the same history', () {
      final days = <DateTime>[];
      final cgm = <CgmSample>[];
      for (var i = 0; i < DayPatternReportBuilder.minDaysForKMeans; i++) {
        final d = DateTime(2026, 7, 1).add(Duration(days: i));
        days.add(d);
        cgm.addAll(_day(d, mgdl: 90 + (i % 4) * 15));
      }
      final range =
          _range(days.first, days.last.add(const Duration(days: 1)));
      final now = days.last.add(const Duration(days: 1));

      final a = builder.build(cgm: cgm, range: range, now: now);
      final b = builder.build(cgm: cgm, range: range, now: now);

      expect(
        a.kMeansClusters!.map((c) => c.days.map((d) => d.date).toList()),
        b.kMeansClusters!.map((c) => c.days.map((d) => d.date).toList()),
      );
    });
  });
}
