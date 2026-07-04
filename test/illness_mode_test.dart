import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/insights/illness_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 7, 4, 9);

  group('IllnessModeController overlay', () {
    test('boosts resistance with floored confidence and an illness reason', () {
      final c = IllnessModeController()
        ..activate(now: t0, expectedResistanceBoost: 1.2);
      final out = c.overlay(SensitivityContext.neutral);
      expect(out.resistanceMultiplier, closeTo(1.2, 1e-9));
      expect(out.confidence, greaterThanOrEqualTo(0.7));
      expect(out.reasons, contains('illness'));
      // effectiveMultiplier blends by confidence: 1 + 0.2*0.7 = 1.14.
      expect(out.effectiveMultiplier, closeTo(1.14, 0.01));
    });

    test('stacks multiplicatively on an already-resistant base, clamped', () {
      final c = IllnessModeController()
        ..activate(now: t0, expectedResistanceBoost: 1.5);
      const base = SensitivityContext(
        resistanceMultiplier: 1.3,
        confidence: 0.9,
        reasons: ['short sleep'],
      );
      final out = c.overlay(base);
      // 1.3 × 1.5 = 1.95 → clamped to the SensitivityContext band ceiling (1.6).
      expect(out.resistanceMultiplier, 1.6);
      expect(out.reasons, containsAll(['short sleep', 'illness']));
    });

    test('is a no-op while inactive', () {
      final c = IllnessModeController();
      const base = SensitivityContext.neutral;
      expect(identical(c.overlay(base), base), isTrue);
      expect(c.adviceNotes, isEmpty);
    });
  });

  group('IllnessModeController lifecycle', () {
    test('deactivation emits an annotation spanning the sick period', () {
      final c = IllnessModeController()..activate(now: t0, notes: 'head cold');
      final end = t0.add(const Duration(days: 2));
      final annotation = c.deactivate(end);
      expect(annotation, isNotNull);
      expect(annotation!.kind, AnnotationKind.illness);
      expect(annotation.start, t0);
      expect(annotation.end, end);
      expect(annotation.note, 'head cold');
      expect(c.mode.active, isFalse);
    });

    test('expiry auto-deactivates', () {
      final c = IllnessModeController()
        ..activate(now: t0, expectedDuration: const Duration(days: 3));
      expect(c.deactivateIfExpired(t0.add(const Duration(days: 1))), isNull);
      final ann = c.deactivateIfExpired(t0.add(const Duration(days: 4)));
      expect(ann, isNotNull);
      expect(c.mode.active, isFalse);
    });

    test('JSON round-trip preserves state', () {
      final c = IllnessModeController()
        ..activate(now: t0, expectedResistanceBoost: 1.35, notes: 'gastro');
      final restored = IllnessMode.decode(c.mode.encode());
      expect(restored.active, isTrue);
      expect(restored.startedAt, t0);
      expect(restored.expectedResistanceBoost, closeTo(1.35, 1e-9));
      expect(restored.notes, 'gastro');
    });
  });

  group('IllnessDetector', () {
    const detector = IllnessDetector();

    test('scores high for elevated BG + high RHR + low HRV', () {
      final s = detector.detect(
        meanGlucoseMgdl: 190, // ~27% above baseline
        baselineGlucoseMgdl: 150,
        restingHr: 62, // 12.7% above
        baselineRestingHr: 55,
        hrvRmssd: 40, // 33% below
        baselineHrv: 60,
      );
      expect(s.score, greaterThanOrEqualTo(0.6));
      expect(s.suggestActivation, isTrue);
      expect(s.reasons, isNotEmpty);
    });

    test('scores near zero for normal data', () {
      final s = detector.detect(
        meanGlucoseMgdl: 152,
        baselineGlucoseMgdl: 150,
        restingHr: 55,
        baselineRestingHr: 55,
        hrvRmssd: 61,
        baselineHrv: 60,
        dailySteps: 9000,
        baselineDailySteps: 9500,
      );
      expect(s.score, lessThan(0.1));
      expect(s.suggestActivation, isFalse);
    });

    test('renormalizes when only glucose data is present', () {
      final s = detector.detect(
        meanGlucoseMgdl: 195, // 30% above → full glucose credit
        baselineGlucoseMgdl: 150,
      );
      // With only the glucose signal, a full-credit deviation scores 1.0.
      expect(s.score, closeTo(1.0, 1e-9));
      expect(s.suggestActivation, isTrue);
    });

    test('returns none when no baselines exist', () {
      expect(detector.detect().suggestActivation, isFalse);
      expect(detector.detect().score, 0);
    });
  });
}
