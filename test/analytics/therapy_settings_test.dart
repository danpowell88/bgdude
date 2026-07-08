import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SensitivityContext.withResistanceOverlay (TASK-146)', () {
    test('multiplies the base multiplier by boost and floors confidence', () {
      const base = SensitivityContext(
          resistanceMultiplier: 1.1, confidence: 0.3, reasons: ['sleep']);
      final overlaid =
          base.withResistanceOverlay(boost: 1.2, reason: 'illness');
      expect(overlaid.resistanceMultiplier, closeTo(1.1 * 1.2, 1e-9));
      expect(overlaid.confidence,
          SensitivityContext.kDefaultMinOverlayConfidence);
      expect(overlaid.reasons, ['sleep', 'illness']);
    });

    test('does not lower an already-higher confidence', () {
      const base = SensitivityContext(resistanceMultiplier: 1.0, confidence: 0.9);
      final overlaid =
          base.withResistanceOverlay(boost: 1.1, reason: 'medication');
      expect(overlaid.confidence, 0.9);
    });

    test('clamps the boosted multiplier to the plausible band', () {
      const base = SensitivityContext(resistanceMultiplier: 1.5);
      final overlaid =
          base.withResistanceOverlay(boost: 2.0, reason: 'illness');
      expect(overlaid.resistanceMultiplier,
          SensitivityContext.kOverlayResistanceCeiling);

      const lowBase = SensitivityContext(resistanceMultiplier: 0.6);
      final lowOverlaid =
          lowBase.withResistanceOverlay(boost: 0.1, reason: 'illness');
      expect(lowOverlaid.resistanceMultiplier,
          SensitivityContext.kOverlayResistanceFloor);
    });

    test('does not duplicate a reason already present', () {
      const base = SensitivityContext(reasons: ['illness']);
      final overlaid =
          base.withResistanceOverlay(boost: 1.2, reason: 'illness');
      expect(overlaid.reasons, ['illness']);
    });

    test('minConfidence can be overridden below the shared default', () {
      const base = SensitivityContext(confidence: 0.1);
      final overlaid = base.withResistanceOverlay(
          boost: 1.1, reason: 'illness', minConfidence: 0.2);
      expect(overlaid.confidence, 0.2);
    });
  });

  group('TherapySegment.fromJson (TASK-190)', () {
    test('round-trips a normal segment unchanged', () {
      final s = TherapySegment.fromJson(const {
        'startMinuteOfDay': 360,
        'isf': 45,
        'carbRatio': 12,
        'targetMgdl': 110,
        'basalUnitsPerHour': 0.9,
      });
      expect(s.isf, 45);
      expect(s.carbRatio, 12);
    });

    test('a zero ISF from a corrupt/old blob falls back to a sane default, not 0', () {
      final s = TherapySegment.fromJson(const {
        'startMinuteOfDay': 0,
        'isf': 0,
        'carbRatio': 10,
        'targetMgdl': 100,
        'basalUnitsPerHour': 0.8,
      });
      expect(s.isf, greaterThan(0));
    });

    test('a negative carb ratio falls back to a sane default, not left negative', () {
      final s = TherapySegment.fromJson(const {
        'startMinuteOfDay': 0,
        'isf': 50,
        'carbRatio': -5,
        'targetMgdl': 100,
        'basalUnitsPerHour': 0.8,
      });
      expect(s.carbRatio, greaterThan(0));
    });
  });

  group('TherapySettings.fromJson (TASK-191)', () {
    test('an empty segments list from a corrupted blob falls back to the placeholder, '
        'not left empty', () {
      final settings = TherapySettings.fromJson(const {'segments': []});
      expect(settings.segments, isNotEmpty);
      // segmentAt() must not throw (sorted.first on an empty list is the exact bug).
      expect(() => settings.segmentAt(DateTime(2026, 7, 4, 8)), returnsNormally);
    });

    test('a normal segments list round-trips unchanged', () {
      final settings = TherapySettings.fromJson(const {
        'segments': [
          {
            'startMinuteOfDay': 0,
            'isf': 50,
            'carbRatio': 10,
            'targetMgdl': 100,
            'basalUnitsPerHour': 0.8,
          },
        ],
      });
      expect(settings.segments, hasLength(1));
      expect(settings.segments.single.isf, 50);
    });
  });
}
