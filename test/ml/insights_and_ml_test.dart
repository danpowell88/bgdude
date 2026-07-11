import 'package:bgdude/analytics/metrics.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/feedback/retraining.dart';
import 'package:bgdude/insights/morning_summary.dart';
import 'package:bgdude/ml/model_registry.dart';
import 'package:bgdude/ml/sensitivity_model.dart';
import 'package:flutter_test/flutter_test.dart';

GlucoseMetrics _metrics({double tir = 0.9, double tbr = 0.0}) {
  // Build a small synthetic set matching desired fractions.
  final start = DateTime(2026, 7, 3, 22);
  final samples = <CgmSample>[];
  for (var i = 0; i < 100; i++) {
    final low = i < (tbr * 100);
    samples.add(CgmSample(
      time: start.add(Duration(minutes: 5 * i)),
      mgdl: low ? 60 : (i < tir * 100 + tbr * 100 ? 120 : 250),
    ));
  }
  return const MetricsCalculator().compute(samples);
}

void main() {
  group('MorningSummary', () {
    ContextFeatures ctx({
      double sleep = 7.5,
      double hrv = 60,
      double baselineHrv = 60,
    }) =>
        ContextFeatures(
          sleepHours: sleep,
          sleepEfficiency: 0.9,
          overnightHrvRmssd: hrv,
          restingHr: 55,
          priorDayExerciseLoad: 0,
          menstrualLutealPhase: 0,
          illnessFlag: 0,
          baselineHrv: baselineHrv,
          baselineRestingHr: 55,
        );

    test('emits a short-sleep insight only when sleep is short', () {
      const gen = MorningSummaryGenerator();
      final good = gen.generate(
        date: DateTime(2026, 7, 4),
        overnightMetrics: _metrics(),
        context: ctx(sleep: 8),
        sensitivity: SensitivityContext.neutral,
      );
      expect(good.insights.any((i) => i.title == 'Short sleep'), isFalse);

      final short = gen.generate(
        date: DateTime(2026, 7, 4),
        overnightMetrics: _metrics(),
        context: ctx(sleep: 5),
        sensitivity: SensitivityContext.neutral,
      );
      expect(short.insights.any((i) => i.title == 'Short sleep'), isTrue);
    });

    test('flags overnight lows as caution', () {
      const gen = MorningSummaryGenerator();
      final s = gen.generate(
        date: DateTime(2026, 7, 4),
        overnightMetrics: _metrics(tir: 0.6, tbr: 0.1),
        context: ctx(),
        sensitivity: SensitivityContext.neutral,
      );
      expect(
          s.insights.any((i) =>
              i.title == 'Overnight lows' &&
              i.severity == InsightSeverity.caution),
          isTrue);
    });

    test('headline reflects a resistant sensitivity context', () {
      const gen = MorningSummaryGenerator();
      final s = gen.generate(
        date: DateTime(2026, 7, 4),
        overnightMetrics: _metrics(),
        context: ctx(),
        sensitivity: const SensitivityContext(
          resistanceMultiplier: 1.25,
          confidence: 1.0,
          reasons: ['short sleep'],
        ),
      );
      expect(s.headline.toLowerCase(), contains('resistant'));
    });
  });

  group('Retraining robustness', () {
    test('excludes annotated site-failure windows and clips outliers', () {
      const pipeline = RetrainingPipeline(
        RetrainingConfig(huberDeltaMgdl: 30),
      );
      final asOf = DateTime(2026, 7, 4, 12);
      final raw = [
        (time: asOf.subtract(const Duration(hours: 1)), features: [1.0], residual: 5.0),
        (time: asOf.subtract(const Duration(hours: 2)), features: [1.0], residual: 200.0), // outlier
        (time: asOf.subtract(const Duration(hours: 3)), features: [1.0], residual: 10.0),
      ];
      final annotations = [
        Annotation(
          id: 'a1',
          kind: AnnotationKind.siteFailure,
          start: asOf.subtract(const Duration(hours: 3, minutes: 10)),
          end: asOf.subtract(const Duration(hours: 2, minutes: 50)),
        ),
      ];
      final set = pipeline.buildTrainingSet(
        rawSamples: raw,
        annotations: annotations,
        asOf: asOf,
      );
      // The 3-hours-ago sample is inside the excluded window → dropped.
      expect(set.length, 2);
      // The 200 mg/dL outlier residual is Huber-clipped to ±30.
      final clipped = set.firstWhere((s) => s.target.abs() == 30);
      expect(clipped.target, 30);
    });
  });

  group('Model promotion gate', () {
    test('rejects a candidate that fails the error-grid threshold', () {
      final registry = ModelRegistry();
      final candidate = ModelVersion(
        id: 'c1',
        stage: ModelStage.candidate,
        createdAt: DateTime(2026, 7, 4),
        trainedOnDays: 30,
        metrics: const ModelEvaluation(
          rmseMgdl: 25,
          mardPercent: 5.0,
          abFraction: 0.80, // below 0.95 gate
          dangerousFraction: 0.05,
          hypoSensitivity: 0.5,
          hypoFalseAlarmRate: 0.2,
          sampleCount: 500,
        ),
      );
      final result = registry.tryPromote(candidate);
      expect(result.promoted, isFalse);
      expect(result.reasons, isNotEmpty);
      expect(registry.active, isNull);
    });

    test('promotes a candidate that passes all thresholds', () {
      final registry = ModelRegistry();
      final candidate = ModelVersion(
        id: 'c2',
        stage: ModelStage.candidate,
        createdAt: DateTime(2026, 7, 4),
        trainedOnDays: 30,
        metrics: const ModelEvaluation(
          rmseMgdl: 18,
          mardPercent: 5.0,
          abFraction: 0.97,
          dangerousFraction: 0.01,
          hypoSensitivity: 0.85,
          hypoFalseAlarmRate: 0.1,
          sampleCount: 500,
        ),
      );
      final result = registry.tryPromote(candidate);
      expect(result.promoted, isTrue);
      expect(registry.active?.id, 'c2');
    });

    test('hypo-free evaluation window skips the sensitivity criterion', () {
      // No true lows in the window → hypoSensitivity is null ("nothing to
      // detect"), which must not read as 0% and spuriously block promotion.
      final registry = ModelRegistry();
      final candidate = ModelVersion(
        id: 'c3',
        stage: ModelStage.candidate,
        createdAt: DateTime(2026, 7, 4),
        trainedOnDays: 30,
        metrics: const ModelEvaluation(
          rmseMgdl: 18,
          mardPercent: 5.0,
          abFraction: 0.97,
          dangerousFraction: 0.01,
          hypoSensitivity: null,
          hypoFalseAlarmRate: 0.0,
          sampleCount: 500,
        ),
      );
      final result = registry.tryPromote(candidate);
      expect(result.promoted, isTrue);
    });
  });
}
