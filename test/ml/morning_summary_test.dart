import 'package:bgdude/analytics/metrics.dart';
import 'package:bgdude/insights/morning_summary.dart';
import 'package:bgdude/ml/sensitivity_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Benign context so only the hypo-risk insight is driven by LBGI.
  const context = ContextFeatures(
    sleepHours: 7.5,
    sleepEfficiency: 0.9,
    overnightHrvRmssd: 50,
    restingHr: 60,
    priorDayExerciseLoad: 0,
    menstrualLutealPhase: 0,
    illnessFlag: 0,
    baselineHrv: 50,
    baselineRestingHr: 60,
  );

  GlucoseMetrics metrics({required double lbgi}) => GlucoseMetrics(
        readingCount: 100,
        meanMgdl: 120,
        sdMgdl: 30,
        timeInRange: 0.8,
        timeInTightRange: 0.5,
        timeBelow70: 0.0, // avoid the "overnight lows" insight
        timeBelow54: 0.0,
        timeAbove180: 0.1,
        timeAbove250: 0.0,
        coveragePeriod: const Duration(hours: 8),
        expectedReadings: 96,
        sufficient: true,
        lbgi: lbgi,
      );

  MorningSummary run(double lbgi, {double baselineLbgi = 0}) =>
      const MorningSummaryGenerator().generate(
        date: DateTime(2026, 7, 4, 7),
        overnightMetrics: metrics(lbgi: lbgi),
        context: context,
        sensitivity: SensitivityContext.neutral,
        baselineLbgi: baselineLbgi,
      );

  bool hasHypoInsight(MorningSummary s) =>
      s.insights.any((i) => i.title.toLowerCase().contains('hypo risk'));

  test('§4-2.2: high LBGI emits a High hypo-risk insight', () {
    final s = run(6.0);
    expect(hasHypoInsight(s), isTrue);
    final ins = s.insights.firstWhere((i) => i.title.contains('hypo risk'));
    expect(ins.title, contains('High'));
    expect(ins.detail, contains('LBGI 6.0'));
  });

  test('§4-2.2: minimal LBGI with no baseline emits nothing', () {
    expect(hasHypoInsight(run(1.0)), isFalse);
  });

  test('§4-2.2: LBGI well above the 14-day baseline is flagged as elevated', () {
    // 2.0 is below the moderate band (2.5) but 2x the baseline → still worth a heads-up.
    final s = run(2.0, baselineLbgi: 1.0);
    expect(hasHypoInsight(s), isTrue);
    expect(
        s.insights.firstWhere((i) => i.title.contains('hypo risk')).detail,
        contains('up on your 14-day norm'));
  });
}
