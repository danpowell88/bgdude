import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
