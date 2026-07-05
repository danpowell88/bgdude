import 'package:bgdude/ml/sensitivity_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContextFeatures — expanded Health Connect signals feed the model', () {
    test('feature vector and names line up (11 features)', () {
      const f = ContextFeatures(
        sleepHours: 7,
        sleepEfficiency: 0.9,
        overnightHrvRmssd: 50,
        restingHr: 60,
        priorDayExerciseLoad: 0,
        menstrualLutealPhase: 0,
        illnessFlag: 0,
        baselineHrv: 50,
        baselineRestingHr: 60,
      );
      expect(f.toVector().length, ContextFeatures.featureNames.length);
      expect(f.toVector().length, 11);
    });

    test('extended signals are relative to baseline (fever/resp/spo2/energy)', () {
      const f = ContextFeatures(
        sleepHours: 7,
        sleepEfficiency: 0.9,
        overnightHrvRmssd: 50,
        restingHr: 60,
        priorDayExerciseLoad: 0,
        menstrualLutealPhase: 0,
        illnessFlag: 0,
        baselineHrv: 50,
        baselineRestingHr: 60,
        overnightRespiratoryRate: 18,
        baselineRespiratoryRate: 15,
        spo2: 95,
        baselineSpo2: 98,
        bodyTempC: 38.0,
        baselineBodyTempC: 36.8,
        activeEnergyKcal: 600,
        baselineActiveEnergyKcal: 400,
      );
      final v = f.toVector();
      // respiratory rate vs baseline = (18-15)/15 = 0.2
      expect(v[7], closeTo(0.2, 1e-9));
      // SpO2 absolute delta = 95 - 98 = -3
      expect(v[8], closeTo(-3, 1e-9));
      // body-temp delta = 38.0 - 36.8 = 1.2
      expect(v[9], closeTo(1.2, 1e-9));
      // active energy vs baseline = (600-400)/400 = 0.5
      expect(v[10], closeTo(0.5, 1e-9));
    });

    test('zero baselines contribute no signal (older data stays neutral)', () {
      const f = ContextFeatures(
        sleepHours: 7,
        sleepEfficiency: 0.9,
        overnightHrvRmssd: 50,
        restingHr: 60,
        priorDayExerciseLoad: 0,
        menstrualLutealPhase: 0,
        illnessFlag: 0,
        baselineHrv: 50,
        baselineRestingHr: 60,
        // No extended baselines provided → those features must be exactly 0.
      );
      final v = f.toVector();
      expect(v[7], 0);
      expect(v[8], 0);
      expect(v[9], 0);
      expect(v[10], 0);
    });

    test('fever + elevated respiratory rate raise the resistance multiplier', () {
      const healthy = ContextFeatures(
        sleepHours: 7,
        sleepEfficiency: 0.9,
        overnightHrvRmssd: 50,
        restingHr: 60,
        priorDayExerciseLoad: 0,
        menstrualLutealPhase: 0,
        illnessFlag: 0,
        baselineHrv: 50,
        baselineRestingHr: 60,
        bodyTempC: 36.8,
        baselineBodyTempC: 36.8,
        overnightRespiratoryRate: 15,
        baselineRespiratoryRate: 15,
      );
      const feverish = ContextFeatures(
        sleepHours: 7,
        sleepEfficiency: 0.9,
        overnightHrvRmssd: 50,
        restingHr: 60,
        priorDayExerciseLoad: 0,
        menstrualLutealPhase: 0,
        illnessFlag: 0,
        baselineHrv: 50,
        baselineRestingHr: 60,
        bodyTempC: 37.8, // +1.0°C
        baselineBodyTempC: 36.8,
        overnightRespiratoryRate: 18, // +20%
        baselineRespiratoryRate: 15,
      );
      expect(heuristicSensitivity(feverish).resistanceMultiplier,
          greaterThan(heuristicSensitivity(healthy).resistanceMultiplier));
    });
  });
}
