import 'package:bgdude/analytics/bolus_advisor.dart';
import 'package:bgdude/analytics/predictor.dart';
import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/core/units.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/samples.dart';

void main() {
  final now = DateTime(2026, 7, 4, 12);
  // ISF 50 mg/dL/U, CR 10 g/U, target 100 mg/dL, basal 0.8 U/h.
  final settings = testTherapySettings(maxBolusUnits: 15);

  PredictionState state({
    required double bg,
    double roc = 0,
    List<BolusEvent> boluses = const [],
    List<BasalSegment> basal = const [],
    List<CarbEntry> carbs = const [],
    SensitivityContext ctx = SensitivityContext.neutral,
  }) =>
      PredictionState(
        now: now,
        currentMgdl: bg,
        recentRocMgdlPerMin: roc,
        boluses: boluses,
        basal: basal,
        carbs: carbs,
        settings: settings,
        context: ctx,
      );

  group('zero ISF/CR never produces a NaN/Infinity dose', () {
    const zeroSettings = TherapySettings(
      segments: [
        TherapySegment(
          startMinuteOfDay: 0,
          isf: 0,
          carbRatio: 0,
          targetMgdl: 100,
          basalUnitsPerHour: 0.8,
        ),
      ],
      maxBolusUnits: 15,
    );
    PredictionState zeroState({required double bg, double carbs = 0}) =>
        PredictionState(
          now: now,
          currentMgdl: bg,
          recentRocMgdlPerMin: 0,
          boluses: const [],
          basal: const [],
          carbs: const [],
          settings: zeroSettings,
          context: SensitivityContext.neutral,
        );

    test('zero ISF: correction is finite, not Infinity', () {
      final advice = BolusAdvisor().advise(zeroState(bg: 200));
      expect(advice.correctionUnits.isFinite, isTrue);
      expect(advice.recommendedUnits.isFinite, isTrue);
    });

    test('zero carb ratio: meal dose is finite, not Infinity', () {
      final advice =
          BolusAdvisor().advise(zeroState(bg: 100, carbs: 40), carbsGrams: 40);
      expect(advice.mealUnits.isFinite, isTrue);
      expect(advice.recommendedUnits.isFinite, isTrue);
    });
  });

  test('pure correction matches hand calc: (200-100)/50 = 2U, no IOB', () {
    final advice = BolusAdvisor().advise(state(bg: 200));
    expect(advice.correctionUnits, closeTo(2.0, 0.05));
    expect(advice.mealUnits, 0);
    expect(advice.recommendedUnits, closeTo(2.0, 0.05));
    expect(advice.refused, isFalse);
  });

  test('meal + correction: 40g/CR10 = 4U meal, +2U correction = 6U', () {
    final advice = BolusAdvisor().advise(state(bg: 200), carbsGrams: 40);
    expect(advice.mealUnits, closeTo(4.0, 0.05));
    expect(advice.correctionUnits, closeTo(2.0, 0.05));
    expect(advice.recommendedUnits, closeTo(6.0, 0.1));
  });

  test('bolus IOB is subtracted from the correction', () {
    final advice = BolusAdvisor().advise(
      state(bg: 200, boluses: [BolusEvent(time: now, units: 1.5)]),
    );
    // 2U raw correction − ~1.5U bolus IOB ≈ 0.5U.
    expect(advice.correctionUnits, closeTo(0.5, 0.15));
  });

  test('P0-1: basal IOB does NOT reduce the correction', () {
    // Three hours of 0.8 U/h scheduled basal generates real basal IOB, but on a
    // Control-IQ pump that basal is already accounted for — the correction must use
    // bolus-only IOB, so it stays at the full 2.0 U.
    final advice = BolusAdvisor().advise(
      state(bg: 200, basal: [
        BasalSegment(
          start: now.subtract(const Duration(hours: 3)),
          end: now,
          unitsPerHour: 0.8,
        ),
      ]),
    );
    expect(advice.correctionUnits, closeTo(2.0, 0.05));
    expect(advice.iobUsed, closeTo(0.0, 0.001));
  });

  test('P0-4: configured DIA changes how much bolus IOB is subtracted', () {
    final bolus = [
      BolusEvent(time: now.subtract(const Duration(minutes: 90)), units: 2.0),
    ];
    TherapySettings withDia(int dia) => TherapySettings(
          segments: settings.segments,
          durationOfInsulinActionMinutes: dia,
          maxBolusUnits: 15,
        );
    PredictionState st(TherapySettings s) => PredictionState(
          now: now,
          currentMgdl: 200,
          recentRocMgdlPerMin: 0,
          boluses: bolus,
          basal: const [],
          carbs: const [],
          settings: s,
          context: SensitivityContext.neutral,
        );
    final short = BolusAdvisor().advise(st(withDia(180)));
    final long = BolusAdvisor().advise(st(withDia(360)));
    // Shorter DIA → more of the 90-min-old bolus has acted → less IOB remaining →
    // a larger correction is suggested. Proves the configured DIA flows through.
    expect(short.iobUsed, lessThan(long.iobUsed));
    expect(short.correctionUnits, greaterThan(long.correctionUnits));
  });

  test('P0-6: low-guard blocks a correction on a current low', () {
    final advice = BolusAdvisor().advise(state(bg: 60)); // 60 < low (70)
    expect(advice.correctionUnits, 0);
    expect(advice.notes.join(' ').toLowerCase(), contains('treat the low first'));
  });

  test('P0-6: suspected compression low is excluded from the low-guard', () {
    final advice =
        BolusAdvisor().advise(state(bg: 60), compressionLowSuspected: true);
    // The guard must not fire on a false (compression) low — no "treat the low first".
    expect(advice.notes.join(' ').toLowerCase(),
        isNot(contains('treat the low first')));
  });

  test('refuses a correction when CGM is noisy', () {
    final advice = BolusAdvisor().advise(state(bg: 200), cgmNoisy: true);
    expect(advice.refused, isTrue);
    expect(advice.correctionUnits, 0);
  });

  test('predicted low reduces the correction and warns', () {
    // Strongly falling BG with recent big bolus → predictor forecasts a low.
    final advice = BolusAdvisor().advise(
      state(
        bg: 120,
        roc: -3.0,
        boluses: [BolusEvent(time: now.subtract(const Duration(minutes: 20)), units: 6)],
      ),
    );
    expect(advice.notes.any((n) => n.toLowerCase().contains('low')), isTrue);
  });

  test('never exceeds the max bolus cap', () {
    final advice = BolusAdvisor().advise(state(bg: 400), carbsGrams: 300);
    expect(advice.recommendedUnits, lessThanOrEqualTo(15.0));
    expect(advice.notes.any((n) => n.contains('Capped')), isTrue);
  });

  test('resistance context increases the meal dose', () {
    const resistant = SensitivityContext(
      resistanceMultiplier: 1.3,
      confidence: 1.0,
      reasons: ['short sleep'],
    );
    final base = BolusAdvisor().advise(state(bg: 100), carbsGrams: 40);
    final adj = BolusAdvisor()
        .advise(state(bg: 100, ctx: resistant), carbsGrams: 40);
    expect(adj.mealUnits, greaterThan(base.mealUnits));
  });

  test('working breakdown is populated for display', () {
    final advice = BolusAdvisor()
        .advise(state(bg: 180), carbsGrams: 30, displayUnit: GlucoseUnit.mmol);
    expect(advice.working, isNotEmpty);
    expect(advice.working.any((s) => s.label == 'Suggested'), isTrue);
  });

  group('fat/protein (FPU) extended dose', () {
    test('exact grams: (20·9 + 30·4)/100 = 3.0 FPU → 3.0 U over 5h', () {
      // bg == target so there's no correction; meal is 40/CR10 = 4U immediate.
      final advice = BolusAdvisor().advise(
        state(bg: 100),
        carbsGrams: 40,
        fatGrams: 20,
        proteinGrams: 30,
      );
      expect(advice.fpu, closeTo(3.0, 0.01));
      expect(advice.fpuUnits, closeTo(3.0, 0.05)); // 3.0 FPU × 10g ÷ CR10
      expect(advice.fpuExtendHours, 5); // ceil(3)+2
      // Extended is kept OUT of the immediate suggestion.
      expect(advice.recommendedUnits, closeTo(4.0, 0.05));
      expect(advice.totalWithFpu, closeTo(7.0, 0.1));
      expect(advice.notes.any((n) => n.toLowerCase().contains('extended')),
          isTrue);
    });

    test('relative levels map low<medium<high', () {
      double fpuUnitsFor(FatProteinLevel l) => BolusAdvisor()
          .advise(state(bg: 100), fatProteinLevel: l)
          .fpuUnits;
      expect(fpuUnitsFor(FatProteinLevel.none), 0);
      expect(fpuUnitsFor(FatProteinLevel.low), closeTo(1.0, 0.05));
      expect(fpuUnitsFor(FatProteinLevel.medium), closeTo(2.0, 0.05));
      expect(fpuUnitsFor(FatProteinLevel.high), closeTo(3.5, 0.05));
    });

    test('exact grams override the qualitative level', () {
      final advice = BolusAdvisor().advise(
        state(bg: 100),
        fatGrams: 20,
        proteinGrams: 30, // → 3.0 FPU
        fatProteinLevel: FatProteinLevel.high, // would be 3.5 FPU
      );
      expect(advice.fpu, closeTo(3.0, 0.01));
    });

    test('no fat/protein → no extended dose, immediate unchanged', () {
      final advice = BolusAdvisor().advise(state(bg: 200), carbsGrams: 40);
      expect(advice.fpu, 0);
      expect(advice.fpuUnits, 0);
      expect(advice.fpuExtendHours, 0);
      expect(advice.recommendedUnits, closeTo(6.0, 0.1)); // 4 meal + 2 correction
    });
  });

  // The pure compute step is asserted on directly — numeric fields, no strings.
  group('computeBolus (pure numeric result)', () {
    test('correction and total without touching display strings', () {
      final c = BolusAdvisor().computeBolus(state(bg: 200));
      expect(c.correctionUnits, closeTo(2.0, 0.05));
      expect(c.mealUnits, 0);
      expect(c.total, closeTo(2.0, 0.05));
      expect(c.capped, isFalse);
      expect(c.currentlyLow, isFalse);
      expect(c.ciqHalved, isFalse);
    });

    test('meal + correction sum', () {
      final c = BolusAdvisor().computeBolus(state(bg: 200), carbsGrams: 40);
      expect(c.mealUnits, closeTo(4.0, 0.05));
      expect(c.correctionUnits, closeTo(2.0, 0.05));
      expect(c.total, closeTo(6.0, 0.1));
    });

    test('low reading trips the hard low-guard: no correction', () {
      final c = BolusAdvisor().computeBolus(state(bg: 60));
      expect(c.currentlyLow, isTrue);
      expect(c.correctionUnits, 0);
    });

    test('total is capped at the pump max bolus', () {
      // 300g of carbs at CR10 = 30U meal, well over the 15U max.
      final c = BolusAdvisor().computeBolus(state(bg: 120), carbsGrams: 300);
      expect(c.capped, isTrue);
      expect(c.total, c.cap);
      expect(c.cap, 15);
    });

    test('fat/protein yields an extended dose within the hour bounds', () {
      final c = BolusAdvisor()
          .computeBolus(state(bg: 120), carbsGrams: 30, fatGrams: 40, proteinGrams: 30);
      expect(c.fpu, greaterThan(0));
      expect(c.fpuUnits, greaterThan(0));
      expect(c.fpuExtendHours, inInclusiveRange(3, 8));
    });

    test('extend hours follow the published Pankowska table', () {
      // 1 FPU -> 3 h, 2 -> 4 h, 3 -> 5 h, >= 4 -> 8 h; partial FPU rounds up.
      expect(BolusAdvisor.pankowskaExtendHours(1), 3);
      expect(BolusAdvisor.pankowskaExtendHours(2), 4);
      expect(BolusAdvisor.pankowskaExtendHours(3), 5);
      expect(BolusAdvisor.pankowskaExtendHours(4), 8);
      expect(BolusAdvisor.pankowskaExtendHours(5), 8);
      expect(BolusAdvisor.pankowskaExtendHours(2.3), 5);
    });

    test('3 FPU extends 5 h, 4 FPU extends 8 h end-to-end', () {
      // 3 FPU: (20 g fat x 9 + 30 g protein x 4) / 100 = 3.0
      final three = BolusAdvisor()
          .computeBolus(state(bg: 120), fatGrams: 20, proteinGrams: 30);
      expect(three.fpu, closeTo(3.0, 1e-9));
      expect(three.fpuExtendHours, 5);
      // 4 FPU: (40 g fat x 9 + 10 g protein x 4) / 100 = 4.0 — the old heuristic
      // gave 6 h here, ending the extension 2 h early.
      final four = BolusAdvisor()
          .computeBolus(state(bg: 120), fatGrams: 40, proteinGrams: 10);
      expect(four.fpu, closeTo(4.0, 1e-9));
      expect(four.fpuExtendHours, 8);
    });
  });

  group('rounding direction', () {
    test('the final suggestion rounds DOWN to 0.01 U: computed 1.238 -> 1.23', () {
      // 12.38 g / CR 10 = 1.238 U, no correction (at target). Nearest-rounding
      // would show 1.24 — the advisory dose must never round upward.
      final advice = BolusAdvisor().advise(state(bg: 100), carbsGrams: 12.38);
      expect(advice.recommendedUnits, 1.23);
    });

    test('an exact 0.01 U increment is preserved, not dropped', () {
      // 12.3 g / CR 10 = 1.23 exactly; float error must not floor it to 1.22.
      final advice = BolusAdvisor().advise(state(bg: 100), carbsGrams: 12.3);
      expect(advice.recommendedUnits, 1.23);
    });

    test('FPU units round DOWN too: computed 1.247 -> 1.24', () {
      // (10.3 g fat x 9 + 8 g protein x 4) / 100 kcal = 1.247 FPU
      // x 10 g-equiv / CR 10 = 1.247 U extended.
      final c = BolusAdvisor()
          .computeBolus(state(bg: 100), fatGrams: 10.3, proteinGrams: 8);
      expect(c.fpuUnits, 1.24);
    });

    test('the working strings match the floored suggestion', () {
      final advice = BolusAdvisor().advise(state(bg: 100), carbsGrams: 12.38);
      final meal =
          advice.working.firstWhere((s) => s.label == 'Meal insulin').value;
      final suggested =
          advice.working.firstWhere((s) => s.label == 'Suggested').value;
      expect(meal, contains('1.23 U'));
      expect(suggested, contains('1.23 U'));
      expect(suggested, isNot(contains('1.24')));
    });
  });
}
