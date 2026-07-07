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

    test(
        'a hand-specified linear glucose fall (independent of InsulinModel) '
        'recovers a multiplier near the hand-derived expected value (TASK-174)',
        () {
      // The other cases above build their "ground truth" CGM trace by calling
      // the SAME InsulinModel Autotune later compares against (`iob.total(...)`),
      // scaled by k at every step. That means a bug in the model's activity
      // CURVE (e.g. a wrong peak time or shape) would be baked into both sides
      // identically and still read multiplier ≈ k — the round-trip can't catch
      // it. This case instead derives its expected value from basic dosing
      // math the model doesn't participate in: by definition, ISF is "1 unit
      // lowers BG by ISF mg/dL", so a single bolus's FULL modelled effect over
      // the model's own duration-of-action is `units * ISF`, independent of
      // how the model's activity is distributed across that duration (the
      // model's own doc comment guarantees its activity curve integrates to 1
      // per unit over the full duration, by construction of its normalisation
      // constant — that integral-to-1 property holds even if the curve's
      // SHAPE, e.g. its peak timing, is wrong).
      //
      // The observed CGM here is a plain straight-line fall — NOT shaped like
      // the insulin activity curve at all — totalling exactly `units * ISF`
      // over the model's full 360-minute duration. Autotune still computes its
      // per-window ratios against the REAL (curved) modelled activity
      // internally, so recovering a multiplier close to 1.0 here is a
      // genuine, independent check that the model's overall potency (not just
      // its self-consistency) is calibrated to ISF.
      const units = 3.0;
      const isf = 54.0; // TherapySettings.placeholder()'s ISF.
      const durationMinutes = 360; // InsulinModel.rapidActing.durationMinutes.
      const stepMin = 5;
      const totalSteps = durationMinutes ~/ stepMin; // 72.
      const totalDrop = 1.0 * units * isf; // k=1.0 -> settings should match.
      const perStepDrop = totalDrop / totalSteps;

      final linearBolusTime = DateTime(2026, 7, 1, 6, 0);
      final linearBoluses = [BolusEvent(time: linearBolusTime, units: units)];
      const startMgdl = 250.0;
      var g = startMgdl;
      var t = linearBolusTime;
      final cgm = [CgmSample(time: t, mgdl: g)];
      for (var i = 1; i <= totalSteps; i++) {
        t = t.add(const Duration(minutes: stepMin));
        g -= perStepDrop;
        cgm.add(CgmSample(time: t, mgdl: g));
      }
      expect(g, closeTo(startMgdl - totalDrop, 1e-9)); // sanity: hand math lines up.

      final r = Autotune().analyseDay(
        day: day,
        cgm: cgm,
        boluses: linearBoluses,
        basal: const [],
        carbs: const [],
        settings: settings,
      );
      // Looser than the exact round-trip cases above — real curve-shape
      // variation across windows (vs. this test's perfectly linear ground
      // truth) is expected noise here, not a bug: a straight-line fall reads
      // as mildly "insulin under-performing" against the real curve's
      // front-loaded ramp (observed ≈1.15 with the parameters above). The
      // point is recovering the right ballpark from a hand-derived target the
      // model never produced, not exact agreement.
      expect(r.sensitivityMultiplier, closeTo(1.0, 0.25));
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
