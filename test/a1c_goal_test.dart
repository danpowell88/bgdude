import 'package:bgdude/analytics/metrics.dart';
import 'package:bgdude/insights/a1c_goal.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal GlucoseMetrics carrying a chosen mean (only `meanMgdl`/`gmi` matter
/// to the tracker).
GlucoseMetrics _metrics(double meanMgdl) => GlucoseMetrics(
      readingCount: 288 * 14,
      meanMgdl: meanMgdl,
      sdMgdl: 40,
      timeInRange: 0.7,
      timeBelow70: 0.02,
      timeBelow54: 0.0,
      timeAbove180: 0.25,
      timeAbove250: 0.05,
      coveragePeriod: const Duration(days: 14),
      expectedReadings: 288 * 14,
      sufficient: true,
    );

void main() {
  group('A1cTracker', () {
    test('constant 154 mg/dL mean → current GMI ≈ 6.99%', () {
      final status = const A1cTracker().status(
        recent: _metrics(154),
        dailyMeanMgdlHistory: List.filled(14, 154),
        targetGmiPercent: 6.7,
      );
      expect(status.currentGmiPercent, closeTo(6.99, 0.01));
    });

    test('declining daily-mean history → projected GMI < current', () {
      // Mean falling from 180 → 150 over 14 days; trend extrapolates lower.
      final history =
          List.generate(14, (i) => 180.0 - i * (30.0 / 13)); // 180 → 150
      final status = const A1cTracker().status(
        recent: _metrics(history.last),
        dailyMeanMgdlHistory: history,
        targetGmiPercent: 6.5,
      );
      expect(status.projectedGmiPercent, isNotNull);
      expect(status.projectedGmiPercent!, lessThan(status.currentGmiPercent));
      expect(status.summary.toLowerCase(), contains('trending down'));
    });

    test('rising daily-mean history → projected GMI > current, trending up',
        () {
      final history = List.generate(10, (i) => 140.0 + i * 3.0); // rising
      final status = const A1cTracker().status(
        recent: _metrics(history.last),
        dailyMeanMgdlHistory: history,
        targetGmiPercent: 6.5,
      );
      expect(status.projectedGmiPercent!, greaterThan(status.currentGmiPercent));
      expect(status.summary.toLowerCase(), contains('trending up'));
    });

    test('fewer than 5 days → projected null', () {
      final status = const A1cTracker().status(
        recent: _metrics(160),
        dailyMeanMgdlHistory: const [160, 158, 162, 159],
        targetGmiPercent: 6.5,
      );
      expect(status.projectedGmiPercent, isNull);
      // Summary omits the trend clause when there's no projection.
      expect(status.summary.toLowerCase(), isNot(contains('trending')));
    });

    test('deltaToTarget sign + onTrack: above goal', () {
      final status = const A1cTracker().status(
        recent: _metrics(180), // GMI ≈ 7.62%
        dailyMeanMgdlHistory: List.filled(14, 180), // flat → no help
        targetGmiPercent: 6.7,
      );
      expect(status.deltaToTargetPercent, greaterThan(0));
      expect(status.currentGmiPercent, greaterThan(status.targetGmiPercent));
      expect(status.onTrack, isFalse);
      expect(status.summary.toLowerCase(), contains('above your'));
    });

    test('deltaToTarget sign + onTrack: at/under goal', () {
      final status = const A1cTracker().status(
        recent: _metrics(130), // GMI ≈ 6.42%
        dailyMeanMgdlHistory: List.filled(14, 130),
        targetGmiPercent: 6.7,
      );
      expect(status.deltaToTargetPercent, lessThan(0));
      expect(status.onTrack, isTrue);
      expect(status.summary.toLowerCase(), contains('below your'));
    });

    test('above goal now but projection reaches target → onTrack true', () {
      // Currently above 6.5% goal, but falling fast toward it.
      final history = List.generate(14, (i) => 175.0 - i * 3.0);
      final status = const A1cTracker().status(
        recent: _metrics(175),
        dailyMeanMgdlHistory: history,
        targetGmiPercent: 6.5,
      );
      expect(status.currentGmiPercent, greaterThan(6.5));
      expect(status.projectedGmiPercent!, lessThanOrEqualTo(6.5));
      expect(status.onTrack, isTrue);
    });
  });
}
