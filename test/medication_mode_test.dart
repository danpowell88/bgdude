import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/insights/medication_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MedicationMode overlay', () {
    const base = SensitivityContext(resistanceMultiplier: 1.0, confidence: 0.2);

    test('inactive is a no-op', () {
      const mode = MedicationMode(active: false);
      expect(mode.overlay(base).resistanceMultiplier, 1.0);
    });

    test('active raises resistance by the intensity boost and floors confidence', () {
      const mode = MedicationMode(
          active: true, intensity: MedicationIntensity.moderate);
      final ctx = mode.overlay(base);
      expect(ctx.resistanceMultiplier, closeTo(1.25, 1e-9));
      expect(ctx.confidence, greaterThanOrEqualTo(0.7));
      expect(ctx.reasons, contains('medication'));
    });

    test('boost is clamped to the sensitivity band', () {
      const mode =
          MedicationMode(active: true, intensity: MedicationIntensity.high);
      const hot = SensitivityContext(resistanceMultiplier: 1.5, confidence: 0.9);
      expect(mode.overlay(hot).resistanceMultiplier, lessThanOrEqualTo(1.6));
    });

    test('intensity boosts increase with severity', () {
      expect(MedicationIntensity.mild.resistanceBoost,
          lessThan(MedicationIntensity.moderate.resistanceBoost));
      expect(MedicationIntensity.moderate.resistanceBoost,
          lessThan(MedicationIntensity.high.resistanceBoost));
    });

    test('JSON round-trip', () {
      final mode = MedicationMode(
          active: true,
          startedAt: DateTime(2026, 7, 4),
          expiresAt: DateTime(2026, 7, 18),
          intensity: MedicationIntensity.high,
          name: 'Prednisolone');
      final r = MedicationMode.fromJson(mode.toJson());
      expect(r.active, isTrue);
      expect(r.intensity, MedicationIntensity.high);
      expect(r.name, 'Prednisolone');
      expect(r.startedAt, DateTime(2026, 7, 4));
      expect(r.expiresAt, DateTime(2026, 7, 18));
    });
  });

  group('MedicationMode.isExpired (TASK-197)', () {
    test('is false while inactive, even past the expiry instant', () {
      final mode = MedicationMode(
          active: false, expiresAt: DateTime(2026, 7, 4));
      expect(mode.isExpired(DateTime(2026, 7, 5)), isFalse);
    });

    test('is false with no expiry set (active until manually stopped)', () {
      const mode = MedicationMode(active: true);
      expect(mode.isExpired(DateTime(2099)), isFalse);
    });

    test('is false before the expiry instant, true after', () {
      final mode =
          MedicationMode(active: true, expiresAt: DateTime(2026, 7, 4, 12));
      expect(mode.isExpired(DateTime(2026, 7, 4, 11)), isFalse);
      expect(mode.isExpired(DateTime(2026, 7, 4, 13)), isTrue);
    });

    test('default course length is on the order of weeks, not indefinite', () {
      expect(MedicationMode.defaultExpectedDuration.inDays,
          greaterThanOrEqualTo(7));
    });
  });
}
