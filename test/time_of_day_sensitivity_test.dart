import 'dart:convert';

import 'package:bgdude/analytics/insulin_math.dart';
import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/ml/time_of_day_sensitivity.dart';
import 'package:flutter_test/flutter_test.dart';

const _isf = 54.0;
const _basalRate = 0.8;

TherapySettings _settings() => const TherapySettings(
      segments: [
        TherapySegment(
          startMinuteOfDay: 0,
          isf: _isf,
          carbRatio: 9,
          targetMgdl: 108,
          basalUnitsPerHour: _basalRate,
        ),
      ],
    );

/// Ground-truth resistance multiplier per 3-hour bucket used to synthesize CGM:
///   * dawn phenomenon 3–9 am (buckets 1–2): insulin underperforms, ×1.3
///   * mid-afternoon 12–18 (buckets 4–5): insulin overperforms, ×0.8
///   * evening 18–24 (buckets 6–7): mild resistance, ×1.2 (also makes the
///     midnight wrap-around interpolation non-trivial)
const _trueMult = [1.0, 1.3, 1.3, 1.0, 0.8, 0.8, 1.2, 1.2];

/// Bucket 3 (9–12) has no CGM coverage on any day → must stay neutral with
/// zero confidence.
const _observed = [true, true, true, false, true, true, true, true];

/// Synthesize one basal-only, carb-free day. Within each observed bucket the
/// trace restarts at 220 mg/dL (after a >15 min gap, which the analyzer skips)
/// and then falls by exactly (2 − trueMult) × the modelled insulin effect — the
/// same IobCalculator the analyzer uses — so per-bucket ratios are exact.
DayHistory _synthDay(DateTime day) {
  const iob = IobCalculator();
  final basal = [
    BasalSegment(
      start: day.subtract(const Duration(hours: 6)), // warm IOB at midnight
      end: day.add(const Duration(hours: 24)),
      unitsPerHour: _basalRate,
    ),
  ];
  final cgm = <CgmSample>[];
  for (var b = 0; b < 8; b++) {
    if (!_observed[b]) continue;
    final bucketStart = day.add(Duration(minutes: b * 180));
    var bg = 220.0;
    var t = bucketStart.add(const Duration(minutes: 20));
    cgm.add(CgmSample(time: t, mgdl: bg));
    while (t.difference(bucketStart).inMinutes < 175) {
      t = t.add(const Duration(minutes: 5));
      final act = iob.total(const [], basal, t).activityUnitsPerMin;
      final modelledDelta = -act * _isf * 5; // negative = drop
      bg += modelledDelta * (2 - _trueMult[b]);
      cgm.add(CgmSample(time: t, mgdl: bg));
    }
  }
  return DayHistory(
    day: day,
    cgm: cgm,
    boluses: const [],
    basal: basal,
    carbs: const [],
  );
}

List<DayHistory> _history(int days) => [
      for (var i = 0; i < days; i++)
        _synthDay(DateTime(2026, 6, 1).add(Duration(days: i))),
    ];

void main() {
  group('TimeOfDaySensitivityAnalyzer', () {
    late TimeOfDayProfile profile;

    setUpAll(() {
      profile = TimeOfDaySensitivityAnalyzer()
          .learn(days: _history(21), settings: _settings());
    });

    test('analyseDay recovers the per-bucket ground truth for one day', () {
      final day = _synthDay(DateTime(2026, 6, 1));
      final samples = TimeOfDaySensitivityAnalyzer().analyseDay(
        day: day.day,
        cgm: day.cgm,
        boluses: day.boluses,
        basal: day.basal,
        carbs: day.carbs,
        settings: _settings(),
      );
      final byBucket = {for (final s in samples) s.bucketIndex: s};
      expect(byBucket.containsKey(3), isFalse); // unobserved bucket
      expect(byBucket[1]!.multiplier, closeTo(1.3, 0.02));
      expect(byBucket[4]!.multiplier, closeTo(0.8, 0.02));
      expect(byBucket[1]!.carbFreeMinutes, greaterThanOrEqualTo(150));
    });

    test('learns dawn resistance and afternoon sensitivity from 21 days', () {
      expect(profile.isNeutral, isFalse);
      expect(profile.trainedDays, 21);
      // Dawn phenomenon: morning multipliers well above neutral.
      expect(profile.multiplierAt(DateTime(2026, 7, 4, 5)), greaterThan(1.05));
      expect(
          profile.multiplierAt(DateTime(2026, 7, 4, 6, 30)), greaterThan(1.05));
      expect(profile.multiplierAt(DateTime(2026, 7, 4, 5)), closeTo(1.3, 0.05));
      // Afternoon: insulin overperforms → multiplier below 1.
      expect(profile.multiplierAt(DateTime(2026, 7, 4, 14)), lessThan(1.0));
      expect(
          profile.multiplierAt(DateTime(2026, 7, 4, 14)), closeTo(0.8, 0.05));
      // Overnight bucket matched settings → near neutral.
      expect(
          profile.multiplierAt(DateTime(2026, 7, 4, 1, 30)), closeTo(1.0, 0.02));
    });

    test('exposes per-bucket values for the advanced UI', () {
      expect(profile.buckets.length, 8);
      expect(profile.buckets[1].startMinute, 180);
      expect(profile.buckets[1].multiplier, closeTo(1.3, 0.02));
      expect(profile.buckets[3].multiplier, 1.0); // never observed
    });

    test('confidence is higher in well-observed buckets', () {
      final observed = profile.confidenceAt(DateTime(2026, 7, 4, 4, 30));
      final unobserved = profile.confidenceAt(DateTime(2026, 7, 4, 10, 30));
      expect(observed, greaterThan(0.5));
      expect(unobserved, lessThan(0.1));
      expect(observed, greaterThan(unobserved));
    });

    test('interpolation is continuous across the midnight wrap', () {
      final before = profile.multiplierAt(DateTime(2026, 7, 4, 23, 59));
      final after = profile.multiplierAt(DateTime(2026, 7, 5, 0, 1));
      expect((before - after).abs(), lessThan(0.01));
      // The wrap sits on a real slope (evening ×1.2 → overnight ×1.0), so this
      // is not trivially 1.0 == 1.0.
      expect(before, greaterThan(1.02));
    });

    test('stays neutral with fewer than 14 days of history', () {
      final short = TimeOfDaySensitivityAnalyzer()
          .learn(days: _history(10), settings: _settings());
      expect(short.isNeutral, isTrue);
      expect(short.multiplierAt(DateTime(2026, 7, 4, 5)), 1.0);
      expect(short.confidenceAt(DateTime(2026, 7, 4, 5)), 0.0);
      final ctx = short.contextAt(DateTime(2026, 7, 4, 5));
      expect(ctx.resistanceMultiplier, 1.0);
      expect(ctx.confidence, 0.0);
      expect(ctx.reasons, isEmpty);
    });

    test('contextAt combines with the daily context', () {
      const daily = SensitivityContext(
        resistanceMultiplier: 1.1,
        confidence: 0.5,
        reasons: ['short sleep'],
      );
      final ctx = profile.contextAt(DateTime(2026, 7, 4, 5), daily: daily);
      // Multipliers multiply: 1.1 × ~1.3.
      expect(ctx.resistanceMultiplier, closeTo(1.43, 0.05));
      // Confidence is the min of the two signals.
      expect(ctx.confidence, closeTo(0.5, 1e-9));
      // Reasons merge: daily drivers + time-of-day pattern.
      expect(ctx.reasons, contains('short sleep'));
      expect(ctx.reasons, contains('dawn effect'));
    });

    test('names evening resistance and keeps tod confidence when daily is neutral',
        () {
      final ctx = profile.contextAt(DateTime(2026, 7, 4, 20));
      expect(ctx.resistanceMultiplier, greaterThan(1.1));
      expect(ctx.reasons, contains('evening resistance'));
      // A neutral daily context must not drag confidence to zero.
      expect(ctx.confidence, greaterThan(0.5));
    });

    test('JSON round-trip preserves the profile', () {
      final json = jsonDecode(jsonEncode(profile.toJson()));
      final restored =
          TimeOfDayProfile.fromJson(json as Map<String, dynamic>);
      expect(restored.bucketCount, profile.bucketCount);
      expect(restored.trainedDays, profile.trainedDays);
      for (var b = 0; b < profile.bucketCount; b++) {
        expect(restored.buckets[b].startMinute, profile.buckets[b].startMinute);
        expect(restored.buckets[b].multiplier,
            closeTo(profile.buckets[b].multiplier, 1e-9));
        expect(restored.buckets[b].confidence,
            closeTo(profile.buckets[b].confidence, 1e-9));
      }
      final probe = DateTime(2026, 7, 4, 7, 45);
      expect(restored.multiplierAt(probe),
          closeTo(profile.multiplierAt(probe), 1e-9));
      expect(restored.confidenceAt(probe),
          closeTo(profile.confidenceAt(probe), 1e-9));
    });
  });
}
