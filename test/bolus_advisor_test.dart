import 'package:bgdude/analytics/bolus_advisor.dart';
import 'package:bgdude/analytics/predictor.dart';
import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/core/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 4, 12);
  // ISF 50 mg/dL/U, CR 10 g/U, target 100 mg/dL, basal 0.8 U/h.
  const settings = TherapySettings(
    segments: [
      TherapySegment(
        startMinuteOfDay: 0,
        isf: 50,
        carbRatio: 10,
        targetMgdl: 100,
        basalUnitsPerHour: 0.8,
      ),
    ],
    maxBolusUnits: 15,
  );

  PredictionState state({
    required double bg,
    double roc = 0,
    List<BolusEvent> boluses = const [],
    List<CarbEntry> carbs = const [],
    SensitivityContext ctx = SensitivityContext.neutral,
  }) =>
      PredictionState(
        now: now,
        currentMgdl: bg,
        recentRocMgdlPerMin: roc,
        boluses: boluses,
        basal: const [],
        carbs: carbs,
        settings: settings,
        context: ctx,
      );

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

  test('IOB is subtracted from the correction', () {
    final advice = BolusAdvisor().advise(
      state(bg: 200, boluses: [BolusEvent(time: now, units: 1.5)]),
    );
    // 2U raw correction − ~1.5U IOB ≈ 0.5U.
    expect(advice.correctionUnits, closeTo(0.5, 0.15));
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
}
