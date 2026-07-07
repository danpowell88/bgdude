import 'package:bgdude/analytics/context_builder.dart';
import 'package:bgdude/data/health_sync.dart';
import 'package:bgdude/profile/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfile', () {
    final now = DateTime(2026, 7, 4);

    test('derives age, duration, cycle flag and BMI', () {
      const p = UserProfile(
        sex: BiologicalSex.female,
        birthYear: 1990,
        diagnosisYear: 2005,
        weightKg: 70,
        heightCm: 175,
      );
      expect(p.ageAt(now), 36);
      expect(p.diabetesDurationYears(now), 21);
      expect(p.hasMenstrualCycle, isTrue);
      expect(p.bmi, closeTo(70 / (1.75 * 1.75), 1e-6));
    });

    test('non-female profiles have no menstrual cycle', () {
      expect(const UserProfile(sex: BiologicalSex.male).hasMenstrualCycle, isFalse);
      expect(const UserProfile().hasMenstrualCycle, isFalse); // unspecified
    });

    test('JSON round-trips and omits null optionals', () {
      const p = UserProfile(
        name: 'Sam',
        sex: BiologicalSex.female,
        birthYear: 1988,
        diabetesType: DiabetesType.type1,
      );
      final restored = UserProfile.fromJson(p.toJson());
      expect(restored.name, 'Sam');
      expect(restored.sex, BiologicalSex.female);
      expect(restored.birthYear, 1988);
      expect(restored.weightKg, isNull);
    });

    test('copyWith can clear an optional via null', () {
      const p = UserProfile(birthYear: 1990);
      expect(p.copyWith(birthYear: null).birthYear, isNull);
      expect(p.copyWith(name: 'x').birthYear, 1990); // untouched
    });

    test('isEmpty detects a blank profile', () {
      expect(const UserProfile().isEmpty, isTrue);
      expect(const UserProfile(birthYear: 1990).isEmpty, isFalse);
    });
  });

  group('HypoAwarenessRisk', () {
    const risk = HypoAwarenessRisk();
    final now = DateTime(2026, 7, 4);

    test('older age and long duration each add a bump, capped', () {
      expect(risk.lowThresholdBump(const UserProfile(), now), 0);
      expect(
          risk.lowThresholdBump(const UserProfile(birthYear: 1990), now), 0); // age 36
      expect(
          risk.lowThresholdBump(const UserProfile(birthYear: 1955), now), // age 71
          5);
      // Older AND long-standing → both bumps, capped at max (8).
      final both = risk.lowThresholdBump(
          const UserProfile(birthYear: 1950, diagnosisYear: 1980), now);
      expect(both, 8);
    });
  });

  group('ContextBuilder menstrual gating', () {
    final now = DateTime(2026, 7, 25);
    // A period started 20 days ago → luteal window (days 14–28).
    final health = [
      HealthSample(time: DateTime(2026, 7, 5), type: HealthMetric.menstruationFlow, value: 2),
      HealthSample(time: now, type: HealthMetric.sleepHours, value: 7),
    ];

    test('luteal inferred when the profile has a cycle', () {
      final f = ContextBuilder.build(
          today: health, baseline: const [], now: now, hasMenstrualCycle: true);
      expect(f!.menstrualLutealPhase, 1.0);
    });

    test('luteal suppressed when the profile has no cycle', () {
      final f = ContextBuilder.build(
          today: health, baseline: const [], now: now, hasMenstrualCycle: false);
      expect(f!.menstrualLutealPhase, 0.0);
    });
  });
}
