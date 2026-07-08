import 'package:bgdude/core/units.dart';
import 'package:bgdude/insights/alert_thresholds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('§4-2.3 migration', () {
    test('old flat JSON becomes the all-day row with no overrides', () {
      final t = AlertThresholds.fromJson(
          {'low': 72.0, 'high': 190.0, 'urgentLow': 54.0});
      expect(t.lowMgdl, 72);
      expect(t.highMgdl, 190);
      expect(t.urgentLowMgdl, 54);
      expect(t.segments, isEmpty);
      // Applies the same values at every hour.
      for (final hour in [2, 9, 14, 23]) {
        final band = t.resolve(at: DateTime(2026, 7, 6, hour));
        expect(band.lowMgdl, 72);
        expect(band.highMgdl, 190);
      }
    });

    test('round-trips segments through JSON', () {
      final t = const AlertThresholds().withSegment(
        AlertSegment.overnight,
        AlertBand(lowMgdl: 85, highMgdl: 180, urgentLowMgdl: 55),
      );
      final back = AlertThresholds.fromJson(t.toJson());
      expect(back.segments[AlertSegment.overnight]!.lowMgdl, 85);
      expect(back.segments[AlertSegment.overnight]!.highMgdl, 180);
      // Unset segments still resolve to the all-day row.
      expect(back.resolve(at: DateTime(2026, 7, 6, 14)).lowMgdl,
          AlertThresholds.defaultLowMgdl);
    });

    test('a partial segment override inherits the all-day row for missing fields', () {
      // Only "high" persisted for post-meal.
      final t = AlertThresholds.fromJson({
        'low': 70.0,
        'high': 200.0,
        'urgentLow': 55.0,
        'segments': {
          'postMeal': {'high': 240.0},
        },
      });
      final band = t.resolve(at: DateTime(2026, 7, 6, 13), postMeal: true);
      expect(band.highMgdl, 240);
      expect(band.lowMgdl, 70); // inherited
      expect(band.urgentLowMgdl, 55); // inherited
    });
  });

  group('§4-2.3 resolution', () {
    final t = const AlertThresholds(
            lowMgdl: Mgdl(70), highMgdl: Mgdl(200), urgentLowMgdl: Mgdl(55))
        .withSegment(AlertSegment.overnight,
            AlertBand(lowMgdl: 85, highMgdl: 180, urgentLowMgdl: 55))
        .withSegment(AlertSegment.postMeal,
            AlertBand(lowMgdl: 70, highMgdl: 240, urgentLowMgdl: 55));

    test('overnight window uses the overnight row', () {
      expect(t.resolve(at: DateTime(2026, 7, 6, 2)).lowMgdl, 85); // 02:00
      expect(t.resolve(at: DateTime(2026, 7, 6, 23, 30)).lowMgdl, 85); // 23:30
    });

    test('daytime with no day override uses the all-day row', () {
      expect(t.resolve(at: DateTime(2026, 7, 6, 14)).lowMgdl, 70);
      expect(t.resolve(at: DateTime(2026, 7, 6, 14)).highMgdl, 200);
    });

    test('post-meal wins over the time-of-day segment, even overnight', () {
      // 02:00 but just ate → post-meal ceiling of 240, not overnight's 180.
      expect(t.resolve(at: DateTime(2026, 7, 6, 2), postMeal: true).highMgdl, 240);
    });
  });
}
