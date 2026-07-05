import 'package:bgdude/analytics/insulin_math.dart';
import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/ml/autotune.dart';
import 'package:flutter_test/flutter_test.dart';

/// Build a CGM trace whose observed deltas are exactly [k] × the insulin-modelled
/// deltas, so the ground-truth observed/modelled ratio is [k] by construction
/// (k = 1 → settings match; k > 1 → insulin over-performs → more sensitive).
///
/// [extraDelta] optionally injects an additional per-step deviation (e.g. a fake
/// compression low) over a step-index range, to test robustness.
List<CgmSample> _cgmWithFactor({
  required double k,
  required List<BolusEvent> boluses,
  required TherapySettings settings,
  required DateTime start,
  int steps = 48,
  double startMgdl = 200,
  double extraDelta = 0,
  int extraFrom = -1,
  int extraTo = -1,
}) {
  const iob = IobCalculator(model: InsulinModel.rapidActing);
  final cgm = [CgmSample(time: start, mgdl: startMgdl)];
  var g = startMgdl;
  var t = start;
  for (var i = 1; i <= steps; i++) {
    t = t.add(const Duration(minutes: 5));
    final act = iob.total(boluses, const [], t).activityUnitsPerMin;
    final modelled = -act * settings.segmentAt(t).isf * 5;
    g += k * modelled;
    if (i >= extraFrom && i <= extraTo) g += extraDelta;
    cgm.add(CgmSample(time: t, mgdl: g));
  }
  return cgm;
}

void main() {
  final settings = TherapySettings.placeholder();
  final day = DateTime(2026, 7, 1);
  final bolusTime = DateTime(2026, 7, 1, 6, 0);
  final start = DateTime(2026, 7, 1, 6, 30);
  final boluses = [BolusEvent(time: bolusTime, units: 3.0)];

  DayResult analyse(List<CgmSample> cgm) => Autotune().analyseDay(
        day: day,
        cgm: cgm,
        boluses: boluses,
        basal: const [],
        carbs: const [],
        settings: settings,
      );

  group('Autotune.analyseDay', () {
    test('insulin performing exactly as modelled → multiplier ≈ 1', () {
      final r = analyse(_cgmWithFactor(
          k: 1.0, boluses: boluses, settings: settings, start: start));
      expect(r.sensitivityMultiplier, closeTo(1.0, 0.05));
    });

    test('insulin over-performing (faster fall) → multiplier < 1', () {
      final r = analyse(_cgmWithFactor(
          k: 1.4, boluses: boluses, settings: settings, start: start));
      expect(r.sensitivityMultiplier, lessThan(0.95));
      expect(r.sensitivityMultiplier, greaterThanOrEqualTo(0.6));
    });

    test('insulin under-performing (slower fall) → multiplier > 1', () {
      final r = analyse(_cgmWithFactor(
          k: 0.6, boluses: boluses, settings: settings, start: start));
      expect(r.sensitivityMultiplier, greaterThan(1.05));
      expect(r.sensitivityMultiplier, lessThanOrEqualTo(1.5));
    });

    test('a single anomalous stretch cannot drag the day (median, not sums)', () {
      // Well-matched day except a fake compression low: 6 steps of an extra
      // −40 mg/dL each. A ratio-of-summed-deltas would read the whole day as
      // dramatically over-performing insulin; the duration-weighted median of
      // per-window ratios shrugs it off.
      final r = analyse(_cgmWithFactor(
        k: 1.0,
        boluses: boluses,
        settings: settings,
        start: start,
        extraDelta: -40,
        extraFrom: 20,
        extraTo: 25,
      ));
      expect(r.sensitivityMultiplier, closeTo(1.0, 0.1));
    });

    test('no usable windows (no insulin activity) → neutral multiplier', () {
      final flat = [
        for (var i = 0; i < 48; i++)
          CgmSample(
              time: start.add(Duration(minutes: 5 * i)), mgdl: 150),
      ];
      final r = Autotune().analyseDay(
        day: day,
        cgm: flat,
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: settings,
      );
      expect(r.sensitivityMultiplier, 1.0);
    });

    test('confidence scales with carb-free observation time', () {
      final short = analyse(_cgmWithFactor(
          k: 1.0,
          boluses: boluses,
          settings: settings,
          start: start,
          steps: 6));
      final long = analyse(_cgmWithFactor(
          k: 1.0, boluses: boluses, settings: settings, start: start));
      expect(short.confidence, lessThan(long.confidence));
    });
  });
}
