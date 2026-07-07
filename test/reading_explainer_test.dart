import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/insights/reading_explainer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/samples.dart';

void main() {
  final noon = DateTime(2026, 7, 4, 12);
  final settings = testTherapySettings();
  final explainer = ReadingExplainer();

  List<CgmSample> trace(
    DateTime start,
    List<double> values, {
    int stepMin = 5,
  }) =>
      [
        for (var i = 0; i < values.length; i++)
          CgmSample(
              time: start.add(Duration(minutes: i * stepMin)),
              mgdl: values[i]),
      ];

  test('unannounced steep rise with no insulin ranks missed carbs first', () {
    // Flat 110 for an hour, then a sustained sharp climb to 250 over 70 min.
    final values = [
      ...List.filled(12, 110.0),
      for (var i = 1; i <= 14; i++) 110.0 + i * 10,
    ];
    final start = noon.subtract(Duration(minutes: (values.length - 1) * 5));
    final at = noon;
    final result = explainer.explain(
      at: at,
      cgm: trace(start, values),
      boluses: const [],
      basal: const [],
      carbs: const [],
      settings: settings,
    );
    expect(result, isNotEmpty);
    expect(result.first.kind, ExplanationKind.missedCarbs);
    expect(result.first.suggestedAnnotation, isNotNull);
    expect(result.first.suggestedAnnotation!.carbsGrams, greaterThan(0));
  });

  test('nocturnal V-shaped dip ranks compression low when asleep', () {
    // Steady 120, plunge to 55 in 10 min, straight back to 115.
    final values = [
      ...List.filled(10, 120.0),
      85.0,
      55.0,
      90.0,
      115.0,
      ...List.filled(6, 118.0),
    ];
    final start = DateTime(2026, 7, 4, 2);
    final at = start.add(const Duration(minutes: 55)); // the nadir sample
    final result = explainer.explain(
      at: at,
      cgm: trace(start, values),
      boluses: const [],
      basal: const [],
      carbs: const [],
      settings: settings,
      wasAsleep: true,
    );
    expect(result, isNotEmpty);
    expect(result.first.kind, ExplanationKind.compressionLow);
  });

  test('stubborn multi-hour rise despite high IOB puts site failure in top 2',
      () {
    // 3h grind from 150 → 280 while 8U from a recent bolus should be dropping it.
    final values = [for (var i = 0; i < 36; i++) 150.0 + i * 3.7];
    final start = noon.subtract(const Duration(hours: 3));
    final result = explainer.explain(
      at: noon,
      cgm: trace(start, values),
      boluses: [
        BolusEvent(time: start.add(const Duration(minutes: 15)), units: 8),
      ],
      basal: const [],
      carbs: const [],
      settings: settings,
    );
    expect(result, isNotEmpty);
    final topTwo = result.take(2).map((e) => e.kind).toList();
    expect(topTwo, contains(ExplanationKind.siteFailure));
  });

  // TASK-247: a zero ISF (a placeholder/copyWith-built segment that bypassed
  // TherapySegment.fromJson's own guard) used to turn absorbedUnits into Infinity,
  // rendering literally "roughly Infinity U of insulin was absorbed" in the UI.
  test('a zero-ISF segment suppresses the site-failure story instead of emitting '
      'Infinity/NaN', () {
    // Two segments: a normal ISF for most of the 3h window (so the expected-drop
    // accumulation is still large enough to clear the early "meaningful IOB
    // activity" gate), but the segment active AT `noon` itself (settings.segmentAt(at)
    // -- the one the site-failure division actually uses) is zero-ISF.
    const zeroAtNoonSettings = TherapySettings(segments: [
      TherapySegment(
        startMinuteOfDay: 0,
        isf: 50,
        carbRatio: 10,
        targetMgdl: 100,
        basalUnitsPerHour: 0.8,
      ),
      TherapySegment(
        startMinuteOfDay: 715, // 11:55am -- active by the time `at` (noon) is reached
        isf: 0,
        carbRatio: 10,
        targetMgdl: 100,
        basalUnitsPerHour: 0.8,
      ),
    ]);
    // Same stubborn multi-hour rise that produces siteFailure with a normal ISF.
    final values = [for (var i = 0; i < 36; i++) 150.0 + i * 3.7];
    final start = noon.subtract(const Duration(hours: 3));
    final result = explainer.explain(
      at: noon,
      cgm: trace(start, values),
      boluses: [
        BolusEvent(time: start.add(const Duration(minutes: 15)), units: 8),
      ],
      basal: const [],
      carbs: const [],
      settings: zeroAtNoonSettings,
    );

    expect(result.map((e) => e.kind), isNot(contains(ExplanationKind.siteFailure)));
    for (final e in result) {
      expect(e.detail, isNot(contains('Infinity')));
      expect(e.detail, isNot(contains('NaN')));
    }
  });

  test('low after overlapping boluses ranks insulin stacking highly', () {
    // Descend from 140 to 62 with two recent stacked boluses and no carbs.
    final values = [for (var i = 0; i < 24; i++) 140.0 - i * 3.4];
    final start = noon.subtract(const Duration(hours: 2));
    final result = explainer.explain(
      at: noon,
      cgm: trace(start, values),
      boluses: [
        BolusEvent(time: start.subtract(const Duration(minutes: 30)), units: 4),
        BolusEvent(time: start.add(const Duration(minutes: 45)), units: 3.5),
      ],
      basal: const [],
      carbs: const [],
      settings: settings,
    );
    expect(result, isNotEmpty);
    final kinds = result.map((e) => e.kind).toList();
    expect(kinds, contains(ExplanationKind.insulinStacking));
  });

  test('quiet flat trace yields only the fallback', () {
    final values = List.filled(48, 115.0);
    final start = noon.subtract(const Duration(hours: 4));
    final result = explainer.explain(
      at: noon,
      cgm: trace(start, values),
      boluses: const [],
      basal: const [],
      carbs: const [],
      settings: settings,
    );
    expect(result, hasLength(1));
    expect(result.single.kind, ExplanationKind.unexplained);
    expect(result.single.suggestedAnnotation, isNull);
  });

  test('returns at most maxExplanations, all above minScore, sorted', () {
    // A messy trace that could trip several hypotheses at once.
    final values = [
      ...List.filled(6, 100.0),
      for (var i = 1; i <= 20; i++) 100.0 + i * 8,
      for (var i = 1; i <= 10; i++) 260.0 - i * 4,
    ];
    final start = noon.subtract(Duration(minutes: (values.length - 1) * 5));
    final result = explainer.explain(
      at: noon,
      cgm: trace(start, values),
      boluses: [BolusEvent(time: start, units: 5)],
      basal: const [],
      carbs: [CarbEntry(time: start, grams: 20)],
      settings: settings,
    );
    expect(result.length, lessThanOrEqualTo(ReadingExplainer.maxExplanations));
    for (final e in result) {
      expect(e.score, greaterThanOrEqualTo(ReadingExplainer.minScore));
    }
    for (var i = 1; i < result.length; i++) {
      expect(result[i - 1].score, greaterThanOrEqualTo(result[i].score));
    }
  });
}
