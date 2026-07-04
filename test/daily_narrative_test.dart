import 'package:bgdude/analytics/metrics.dart';
import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/core/units.dart';
import 'package:bgdude/insights/daily_narrative.dart';
import 'package:flutter_test/flutter_test.dart';

/// Build a metrics object with just the fields the narrative reads.
GlucoseMetrics metrics({
  required int readingCount,
  required double timeInRange,
  required double meanMgdl,
}) =>
    GlucoseMetrics(
      readingCount: readingCount,
      meanMgdl: meanMgdl,
      sdMgdl: 30,
      timeInRange: timeInRange,
      timeBelow70: 0,
      timeBelow54: 0,
      timeAbove180: 0,
      timeAbove250: 0,
      coveragePeriod: const Duration(hours: 6),
      expectedReadings: readingCount,
      sufficient: false,
    );

DailyNarrativeInput input({
  DateTime? now,
  double? currentMgdl = 120,
  GlucoseTrend trend = GlucoseTrend.flat,
  GlucoseMetrics? todayMetrics,
  SensitivityContext sensitivity = SensitivityContext.neutral,
  double? predictedLowMgdl,
  double? predictedHighMgdl,
  bool illnessActive = false,
  bool alcoholYesterday = false,
  GlucoseUnit unit = GlucoseUnit.mmol,
}) =>
    DailyNarrativeInput(
      now: now ?? DateTime(2026, 7, 4, 9),
      currentMgdl: currentMgdl,
      trend: trend,
      todayMetrics: todayMetrics ??
          metrics(readingCount: 200, timeInRange: 0.82, meanMgdl: 130),
      sensitivity: sensitivity,
      predictedLowMgdl: predictedLowMgdl,
      predictedHighMgdl: predictedHighMgdl,
      illnessActive: illnessActive,
      alcoholYesterday: alcoholYesterday,
      unit: unit,
    );

void main() {
  const gen = DailyNarrativeGenerator();

  test('morning vs evening framing differs', () {
    final morning = gen.generate(input(now: DateTime(2026, 7, 4, 8)));
    final evening = gen.generate(input(now: DateTime(2026, 7, 4, 20)));

    expect(morning.headline, contains('Good morning'));
    expect(evening.headline, contains('Good evening'));
    expect(morning.headline, isNot(equals(evening.headline)));
  });

  test('overnight framing is distinct from daytime', () {
    final overnight = gen.generate(input(now: DateTime(2026, 7, 4, 2)));
    expect(overnight.headline, contains('Overnight'));
  });

  test('resistant sensitivity surfaces in body and a stronger-bolus suggestion',
      () {
    const resistant = SensitivityContext(
      resistanceMultiplier: 1.3,
      confidence: 1.0,
      reasons: ['short sleep'],
    );
    // Sanity: this context is genuinely above the resistant band.
    expect(resistant.effectiveMultiplier, greaterThan(1.1));

    final n = gen.generate(input(sensitivity: resistant));

    expect(n.body.toLowerCase(), contains('resistant'));
    expect(n.body.toLowerCase(), contains('short sleep'));
    expect(
      n.suggestions.any((s) => s.toLowerCase().contains('stronger bolus')),
      isTrue,
    );
  });

  test('a predicted low yields a carb suggestion', () {
    final n = gen.generate(input(predictedLowMgdl: 62));
    expect(
      n.suggestions.any(
          (s) => s.contains('15g') && s.toLowerCase().contains('low')),
      isTrue,
    );
  });

  test('illness yields the ketone/hydration suggestion', () {
    final n = gen.generate(input(illnessActive: true));
    expect(
      n.suggestions.any((s) =>
          s.toLowerCase().contains('ketones') &&
          s.toLowerCase().contains('hydrated')),
      isTrue,
    );
  });

  test('low reading count yields the "still early" tone', () {
    final n = gen.generate(
      input(
        todayMetrics: metrics(readingCount: 3, timeInRange: 1.0, meanMgdl: 110),
      ),
    );
    expect(n.body.toLowerCase(), contains('still early'));
    // With so little data, don't make a time-in-range claim.
    expect(n.body, isNot(contains('%')));
  });

  test('no false suggestions on a clean in-range day', () {
    final n = gen.generate(
      input(
        currentMgdl: 110,
        trend: GlucoseTrend.flat,
        todayMetrics:
            metrics(readingCount: 240, timeInRange: 0.92, meanMgdl: 120),
        predictedLowMgdl: 105,
        predictedHighMgdl: 150,
      ),
    );
    expect(n.suggestions, isEmpty);
    expect(n.headline, contains('steady'));
  });

  test('glucose rendered in the requested unit', () {
    final mmol = gen.generate(input(currentMgdl: 180, unit: GlucoseUnit.mmol));
    final mgdl = gen.generate(input(currentMgdl: 180, unit: GlucoseUnit.mgdl));
    expect(mmol.body, contains('mmol/L'));
    expect(mgdl.body, contains('mg/dL'));
    expect(mgdl.body, contains('180'));
  });

  test('trend phrasing reflects the arrow', () {
    final falling = gen.generate(input(trend: GlucoseTrend.singleDown));
    final rising = gen.generate(input(trend: GlucoseTrend.singleUp));
    expect(falling.body.toLowerCase(), contains('falling'));
    expect(rising.body.toLowerCase(), contains('rising'));
  });
}
