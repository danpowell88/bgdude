import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/health_sync.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/reports/correlation_report.dart';
import 'package:bgdude/reports/model_report.dart';
import 'package:bgdude/reports/report_range.dart';
import 'package:flutter_test/flutter_test.dart';

ReportRange _range(DateTime from, DateTime to) =>
    ReportRange(from: from, to: to, preset: ReportPreset.custom);

void main() {
  group('CorrelationReportBuilder', () {
    test('finds a sleep↔TIR association across enough days', () {
      final base = DateTime(2026, 7, 1);
      final cgm = <CgmSample>[];
      final health = <HealthSample>[];
      // 8 days: as the day index rises, more readings sit above range (TIR falls),
      // while logged sleep rises → a strong negative sleep↔TIR correlation.
      for (var d = 0; d < 8; d++) {
        final day = base.add(Duration(days: d));
        for (var i = 0; i < 120; i++) {
          final t = day.add(Duration(minutes: 5 * i));
          final high = i < d * 15; // more highs on later days
          cgm.add(CgmSample(time: t, mgdl: high ? 250 : 120));
        }
        health.add(HealthSample(
            time: day.add(const Duration(hours: 7)),
            type: 'sleepHours',
            value: 6 + d * 0.5));
      }

      final report = const CorrelationReportBuilder().build(
        cgm: cgm,
        health: health,
        range: _range(base, base.add(const Duration(days: 8))),
        now: base.add(const Duration(days: 8)),
      );

      expect(report.daysAnalyzed, 8);
      expect(report.hasData, isTrue);
      final f = report.findings.firstWhere(
        (x) => x.predictorLabel == 'sleep' && x.outcomeLabel == 'time-in-range',
      );
      expect(f.r, lessThan(0)); // more sleep days had lower TIR here
      expect(f.n, 8);
    });

    test('too few days → no findings', () {
      final base = DateTime(2026, 7, 1);
      final cgm = [
        for (var i = 0; i < 120; i++)
          CgmSample(time: base.add(Duration(minutes: 5 * i)), mgdl: 120),
      ];
      final report = const CorrelationReportBuilder().build(
        cgm: cgm,
        health: [
          HealthSample(time: base, type: 'sleepHours', value: 7),
        ],
        range: _range(base, base.add(const Duration(days: 2))),
        now: base.add(const Duration(days: 2)),
      );
      expect(report.hasData, isFalse);
    });
  });

  group('ModelReportBuilder', () {
    final base = DateTime(2026, 7, 4, 8);
    final range = _range(DateTime(2026, 7, 1), DateTime(2026, 7, 5));

    test('scores matured predictions with calibration + error grid', () {
      final preds = [
        for (var i = 0; i < 20; i++)
          StoredPrediction(
            madeAt: base.add(Duration(minutes: 5 * i)),
            horizonMinutes: 30,
            predictedMgdl: 120,
            lowerMgdl: 100,
            upperMgdl: 140,
            modelId: 'residual',
            actualMgdl: 122, // inside interval, near prediction → zone A
          ),
      ];
      final report = const ModelReportBuilder().build(
        predictions: preds,
        modelRuns: const [],
        range: range,
        now: DateTime(2026, 7, 5),
      );
      expect(report.hasData, isTrue);
      expect(report.scored, 20);
      expect(report.intervalCalibration, 1.0);
      expect(report.accuracy.byHorizon[30], isNotNull);
      expect(report.errorGrid.abFraction, 1.0);
    });

    test('no matured predictions → no data', () {
      final report = const ModelReportBuilder().build(
        predictions: [
          StoredPrediction(
            madeAt: base,
            horizonMinutes: 30,
            predictedMgdl: 120,
            lowerMgdl: 100,
            upperMgdl: 140,
            modelId: 'residual',
          ), // no actual yet
        ],
        modelRuns: const [],
        range: range,
        now: DateTime(2026, 7, 5),
      );
      expect(report.hasData, isFalse);
    });
  });
}
