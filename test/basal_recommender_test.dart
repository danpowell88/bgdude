import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/ml/basal_recommender.dart';
import 'package:bgdude/ml/time_of_day_sensitivity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Build an 8-bucket (3h) profile from per-bucket multiplier/confidence.
TimeOfDayProfile _profile(List<double> mult, List<double> conf,
        {int trainedDays = 20}) =>
    TimeOfDayProfile(
      multipliers: mult,
      confidences: conf,
      trainedDays: trainedDays,
    );

TherapySettings _settings(List<(int, double)> segs) => TherapySettings(
      segments: [
        for (final (start, basal) in segs)
          TherapySegment(
            startMinuteOfDay: start,
            isf: 50,
            carbRatio: 10,
            targetMgdl: 110,
            basalUnitsPerHour: basal,
          ),
      ],
    );

void main() {
  final now = DateTime(2026, 7, 4, 12);
  const rec = BasalRecommender();

  test('neutral profile → no suggestions', () {
    final r = rec.recommend(
      profile: TimeOfDayProfile.neutral(),
      settings: _settings([(0, 0.8)]),
      now: now,
    );
    expect(r.hasSuggestions, isFalse);
  });

  test('too few trained days → no suggestions even if resistant', () {
    final r = rec.recommend(
      profile: _profile(List.filled(8, 1.3), List.filled(8, 0.9),
          trainedDays: 7),
      settings: _settings([(0, 0.8)]),
      now: now,
    );
    expect(r.hasSuggestions, isFalse);
  });

  test('overnight resistance suggests a higher basal there', () {
    // Buckets 0 and 1 (00:00–06:00) resistant & confident; rest neutral.
    final mult = List.filled(8, 1.0)
      ..[0] = 1.25
      ..[1] = 1.25;
    final conf = List.filled(8, 0.0)
      ..[0] = 0.8
      ..[1] = 0.8;
    // Two segments: overnight 00:00 @0.80, daytime 06:00 @1.00.
    final r = rec.recommend(
      profile: _profile(mult, conf),
      settings: _settings([(0, 0.80), (360, 1.00)]),
      now: now,
    );
    expect(r.hasSuggestions, isTrue);
    final overnight =
        r.segments.firstWhere((s) => s.startMinuteOfDay == 0);
    expect(overnight.isIncrease, isTrue);
    expect(overnight.suggestedRate, greaterThan(0.80));
    // The daytime segment (neutral, zero confidence) is not suggested.
    expect(r.segments.any((s) => s.startMinuteOfDay == 360), isFalse);
    expect(overnight.rationale, contains('resistant'));
  });

  test('sensitivity suggests a lower basal', () {
    final mult = List.filled(8, 1.0)
      ..[0] = 0.75
      ..[1] = 0.75;
    final conf = List.filled(8, 0.0)
      ..[0] = 0.85
      ..[1] = 0.85;
    final r = rec.recommend(
      profile: _profile(mult, conf),
      settings: _settings([(0, 1.00), (360, 0.90)]),
      now: now,
    );
    final overnight = r.segments.firstWhere((s) => s.startMinuteOfDay == 0);
    expect(overnight.isIncrease, isFalse);
    expect(overnight.suggestedRate, lessThan(1.00));
    expect(overnight.rationale, contains('sensitive'));
  });

  test('change is capped at maxChangeFraction for safety', () {
    // A wild 1.9× multiplier must not push more than +30%.
    final mult = List.filled(8, 1.9);
    final conf = List.filled(8, 0.9);
    final r = rec.recommend(
      profile: _profile(mult, conf),
      settings: _settings([(0, 1.00)]),
      now: now,
    );
    final s = r.segments.single;
    expect(s.suggestedRate, lessThanOrEqualTo(1.30 + 1e-9));
    expect(s.changeFraction, lessThanOrEqualTo(0.30 + 1e-9));
  });

  test('low confidence is ignored', () {
    final r = rec.recommend(
      profile: _profile(List.filled(8, 1.3), List.filled(8, 0.2)),
      settings: _settings([(0, 0.80)]),
      now: now,
    );
    expect(r.hasSuggestions, isFalse);
  });

  test('sub-threshold change is ignored', () {
    // 1.04× resistance → ~4% change, below the 10% floor.
    final r = rec.recommend(
      profile: _profile(List.filled(8, 1.04), List.filled(8, 0.9)),
      settings: _settings([(0, 0.80)]),
      now: now,
    );
    expect(r.hasSuggestions, isFalse);
  });
}
