import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/insights/care_detectors.dart';
import 'package:flutter_test/flutter_test.dart';

/// Single-segment therapy profile: ISF 50 mg/dL/U, CR 10 g/U (CSF = 5), target 100.
TherapySettings _settings() => const TherapySettings(
      segments: [
        TherapySegment(
          startMinuteOfDay: 0,
          isf: 50,
          carbRatio: 10,
          targetMgdl: 100,
          basalUnitsPerHour: 0.8,
        ),
      ],
    );

/// Builds a CGM trace: a linear rise from [startMgdl] to [peakMgdl] over
/// [riseMinutes], then a flat plateau at [peakMgdl] for [plateauMinutes],
/// sampled every 5 minutes starting at [start].
List<CgmSample> _rampThenFlat({
  required DateTime start,
  required double startMgdl,
  required double peakMgdl,
  required int riseMinutes,
  required int plateauMinutes,
}) {
  final out = <CgmSample>[];
  final steps = riseMinutes ~/ 5;
  final perStep = (peakMgdl - startMgdl) / steps;
  for (var i = 0; i <= steps; i++) {
    out.add(CgmSample(
      time: start.add(Duration(minutes: 5 * i)),
      mgdl: startMgdl + perStep * i,
    ));
  }
  final plateauSteps = plateauMinutes ~/ 5;
  for (var j = 1; j <= plateauSteps; j++) {
    out.add(CgmSample(
      time: start.add(Duration(minutes: riseMinutes + 5 * j)),
      mgdl: peakMgdl,
    ));
  }
  return out;
}

/// Builds a linear trace from [fromMgdl] to [toMgdl] over [minutes], every 5 min.
List<CgmSample> _linear({
  required DateTime start,
  required double fromMgdl,
  required double toMgdl,
  required int minutes,
}) {
  final out = <CgmSample>[];
  final steps = minutes ~/ 5;
  final perStep = (toMgdl - fromMgdl) / steps;
  for (var i = 0; i <= steps; i++) {
    out.add(CgmSample(
      time: start.add(Duration(minutes: 5 * i)),
      mgdl: fromMgdl + perStep * i,
    ));
  }
  return out;
}

void main() {
  final t0 = DateTime(2026, 7, 4, 12);

  group('MissedBolusDetector', () {
    // 110 -> 220 over 55 min (2.0 mg/dL/min), then flat. CSF = 5, sustain 45 min
    // captures ~90 mg/dL of rise => ~18 g estimated carbs.
    final cgm = _rampThenFlat(
      start: t0,
      startMgdl: 110,
      peakMgdl: 220,
      riseMinutes: 55,
      plateauMinutes: 35,
    );
    final now = cgm.last.time;

    test('flags a clear post-meal rise with no bolus and no carbs', () {
      final alert = const MissedBolusDetector().detect(
        cgm: cgm,
        boluses: const [],
        carbs: const [],
        basal: const [],
        settings: _settings(),
        now: now,
      );

      expect(alert, isNotNull);
      expect(alert!.estimatedCarbsGrams, greaterThan(0));
      expect(alert.estimatedCarbsGrams, greaterThanOrEqualTo(15));
      expect(alert.riseRateMgdlPerMin, greaterThan(0));
      // Meal onset should be near the start of the rise.
      expect(alert.mealTime.difference(t0).inMinutes.abs(), lessThanOrEqualTo(15));
    });

    test('does not flag the same rise when a bolus covered the meal', () {
      // Same 110->220 rise, but with a covering bolus the glucose then falls
      // (insulin working), as a real covered meal does.
      final rise = _linear(start: t0, fromMgdl: 110, toMgdl: 220, minutes: 55);
      final fall = <CgmSample>[
        for (var i = 1; i <= 8; i++)
          CgmSample(
            time: t0.add(Duration(minutes: 55 + 5 * i)),
            mgdl: 220 - (80 / 8) * i,
          ),
      ];
      final covered = [...rise, ...fall];

      final alert = const MissedBolusDetector().detect(
        cgm: covered,
        boluses: [BolusEvent(time: t0, units: 5.5, carbsGrams: 55)],
        carbs: const [],
        basal: const [],
        settings: _settings(),
        now: covered.last.time,
      );

      expect(alert, isNull);
    });

    test('does not flag when a carb entry covered the meal', () {
      final alert = const MissedBolusDetector().detect(
        cgm: cgm,
        boluses: const [],
        carbs: [CarbEntry(time: t0.add(const Duration(minutes: 5)), grams: 55)],
        basal: const [],
        settings: _settings(),
        now: now,
      );

      expect(alert, isNull);
    });
  });

  group('StubbornHighDetector', () {
    // Flat 250 mg/dL for 2.5 h.
    final flatHigh = <CgmSample>[
      for (var i = 0; i <= 30; i++)
        CgmSample(time: t0.add(Duration(minutes: 5 * i)), mgdl: 250),
    ];
    final now = flatHigh.last.time; // t0 + 150 min
    // 3 U bolus 30 min before now => meaningful IOB remaining.
    final boluses = [
      BolusEvent(time: now.subtract(const Duration(minutes: 30)), units: 3),
    ];

    test('detects a stuck high with IOB; likelySiteIssue true at 72h site age', () {
      final alert = const StubbornHighDetector().detect(
        cgm: flatHigh,
        boluses: boluses,
        basal: const [],
        settings: _settings(),
        siteAgeHours: 72,
        now: now,
      );

      expect(alert, isNotNull);
      expect(alert!.mgdl, closeTo(250, 0.001));
      expect(alert.iobUnits, greaterThan(0.5));
      expect(alert.likelySiteIssue, isTrue);
      expect(alert.since.difference(t0).inMinutes.abs(), lessThanOrEqualTo(5));
    });

    test('likelySiteIssue is false when site age is unknown', () {
      final alert = const StubbornHighDetector().detect(
        cgm: flatHigh,
        boluses: boluses,
        basal: const [],
        settings: _settings(),
        siteAgeHours: null,
        now: now,
      );

      expect(alert, isNotNull);
      expect(alert!.likelySiteIssue, isFalse);
      expect(alert.siteAgeHours, isNull);
    });

    test('does not fire when the high is clearly falling', () {
      // 300 -> 190 over 150 min (~-0.73 mg/dL/min): still above high, but falling.
      final falling = _linear(
        start: t0,
        fromMgdl: 300,
        toMgdl: 190,
        minutes: 150,
      );
      final alert = const StubbornHighDetector().detect(
        cgm: falling,
        boluses: boluses,
        basal: const [],
        settings: _settings(),
        siteAgeHours: 72,
        now: falling.last.time,
      );

      expect(alert, isNull);
    });

    test('does not fire when glucose is not high', () {
      final inRange = <CgmSample>[
        for (var i = 0; i <= 30; i++)
          CgmSample(time: t0.add(Duration(minutes: 5 * i)), mgdl: 120),
      ];
      final alert = const StubbornHighDetector().detect(
        cgm: inRange,
        boluses: boluses,
        basal: const [],
        settings: _settings(),
        siteAgeHours: 72,
        now: inRange.last.time,
      );

      expect(alert, isNull);
    });
  });
}
