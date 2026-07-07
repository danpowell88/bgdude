import 'package:bgdude/analytics/metrics.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/health_sync.dart';
import 'package:bgdude/reports/cycle_report.dart';
import 'package:bgdude/reports/report_range.dart';
import 'package:flutter_test/flutter_test.dart';

ReportRange _range(DateTime from, DateTime to) =>
    ReportRange(from: from, to: to, preset: ReportPreset.custom);

void main() {
  group('TITR + CV flag', () {
    test('time in tight range counts 70–140 only', () {
      final samples = <CgmSample>[
        for (var i = 0; i < 10; i++)
          CgmSample(time: DateTime(2026, 7, 4, 0, i * 5), mgdl: 120), // tight
        for (var i = 0; i < 10; i++)
          CgmSample(time: DateTime(2026, 7, 4, 1, i * 5), mgdl: 170), // in 180 but not tight
      ];
      final m = const MetricsCalculator().compute(samples);
      expect(m.timeInRange, closeTo(1.0, 1e-9)); // all within 70–180
      expect(m.timeInTightRange, closeTo(0.5, 1e-9)); // only the 120s
    });

    test('CV≥36% trips the variability flag', () {
      // Alternate 60 and 200 → high spread → CV well above 36%.
      final samples = <CgmSample>[
        for (var i = 0; i < 40; i++)
          CgmSample(
              time: DateTime(2026, 7, 4, 0, i * 5),
              mgdl: i.isEven ? 60 : 240),
      ];
      final m = const MetricsCalculator().compute(samples);
      expect(m.variabilityHigh, isTrue);
      expect(m.cvPercent, greaterThan(36));
    });

    test('steady glucose is not flagged', () {
      final samples = [
        for (var i = 0; i < 40; i++)
          CgmSample(time: DateTime(2026, 7, 4, 0, i * 5), mgdl: 120),
      ];
      expect(const MetricsCalculator().compute(samples).variabilityHigh, isFalse);
    });
  });

  group('CycleReportBuilder', () {
    test('period detection and phase classification', () {
      final health = [
        // A period starting 7/1 (3 flow days), then a gap, then next period 7/29.
        HealthSample(time: DateTime(2026, 7, 1), type: HealthMetric.menstruationFlow, value: 2),
        HealthSample(time: DateTime(2026, 7, 2), type: HealthMetric.menstruationFlow, value: 2),
        HealthSample(time: DateTime(2026, 7, 3), type: HealthMetric.menstruationFlow, value: 1),
        HealthSample(time: DateTime(2026, 7, 29), type: HealthMetric.menstruationFlow, value: 2),
      ];
      final starts = periodStarts(health);
      expect(starts, hasLength(2));
      expect(phaseFor(starts, DateTime(2026, 7, 5)), CyclePhase.follicular); // day 4
      expect(phaseFor(starts, DateTime(2026, 7, 20)), CyclePhase.luteal); // day 19
    });

    test('compares follicular vs luteal TIR when both have enough days', () {
      final health = [
        HealthSample(time: DateTime(2026, 7, 1), type: HealthMetric.menstruationFlow, value: 2),
      ];
      final cgm = <CgmSample>[];
      // Follicular days 7/2–7/5: steady 120 (high TIR).
      for (var d = 2; d <= 5; d++) {
        for (var i = 0; i < 120; i++) {
          cgm.add(CgmSample(
              time: DateTime(2026, 7, d).add(Duration(minutes: 5 * i)), mgdl: 120));
        }
      }
      // Luteal days 7/15–7/18: lots of highs (low TIR).
      for (var d = 15; d <= 18; d++) {
        for (var i = 0; i < 120; i++) {
          cgm.add(CgmSample(
              time: DateTime(2026, 7, d).add(Duration(minutes: 5 * i)),
              mgdl: i < 80 ? 240 : 120));
        }
      }
      final report = const CycleReportBuilder().build(
        cgm: cgm,
        health: health,
        range: _range(DateTime(2026, 7, 1), DateTime(2026, 7, 20)),
        now: DateTime(2026, 7, 20),
      );
      expect(report.hasData, isTrue);
      expect(report.follicular.days, 4);
      expect(report.luteal.days, 4);
      expect(report.tirDropToLuteal, greaterThan(10)); // luteal ran worse
    });
  });
}
