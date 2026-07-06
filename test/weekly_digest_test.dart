import 'package:bgdude/analytics/metrics.dart';
import 'package:bgdude/insights/weekly_digest.dart';
import 'package:flutter_test/flutter_test.dart';

GlucoseMetrics week({
  required double tir,
  required double mean,
  required double below,
  int readings = 2016, // ~7 days at 5-min
}) =>
    GlucoseMetrics(
      readingCount: readings,
      meanMgdl: mean,
      sdMgdl: 30,
      timeInRange: tir,
      timeInTightRange: tir * 0.7,
      timeBelow70: below,
      timeBelow54: below / 3,
      timeAbove180: 1 - tir - below,
      timeAbove250: 0.02,
      coveragePeriod: const Duration(days: 7),
      expectedReadings: 2016,
      sufficient: true,
    );

void main() {
  const gen = WeeklyDigestGenerator();

  test('summarises TIR/GMI/low with week-over-week deltas', () {
    final d = gen.generate(
      thisWeek: week(tir: 0.70, mean: 150, below: 0.03),
      lastWeek: week(tir: 0.60, mean: 160, below: 0.05),
      learnedInsight: 'Evenings run more resistant lately.',
    )!;
    expect(d.headline, contains('70%'));
    expect(d.body, contains('Time in range: 70%'));
    expect(d.body, contains('▲10')); // +10 points vs last week
    expect(d.body, contains('GMI:'));
    expect(d.body, contains('Evenings run more resistant'));
  });

  test('omits deltas when there is no prior week', () {
    final d = gen.generate(thisWeek: week(tir: 0.65, mean: 155, below: 0.04))!;
    expect(d.body, isNot(contains('vs last week')));
  });

  test('returns null with too little data', () {
    expect(
        gen.generate(thisWeek: week(tir: 0.65, mean: 155, below: 0.04, readings: 100)),
        isNull);
  });
}
