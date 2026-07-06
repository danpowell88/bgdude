import 'package:bgdude/core/time_format.dart';
import 'package:bgdude/ui/widgets/glucose_colors.dart';
import 'package:flutter_test/flutter_test.dart';

/// Logic in the TASK-107 shared helpers: the glucose colour thresholds and the time
/// formatters. The pure-presentation widgets (StatTile, chart axes) have no logic to test.
void main() {
  group('GlucoseColors.forMgdl', () {
    test('below 70 is low (red)', () {
      expect(GlucoseColors.forMgdl(69), GlucoseColors.low);
      expect(GlucoseColors.forMgdl(40), GlucoseColors.low);
    });
    test('70..180 inclusive is in-range (green)', () {
      expect(GlucoseColors.forMgdl(70), GlucoseColors.inRange);
      expect(GlucoseColors.forMgdl(120), GlucoseColors.inRange);
      expect(GlucoseColors.forMgdl(180), GlucoseColors.inRange);
    });
    test('above 180 is high (orange)', () {
      expect(GlucoseColors.forMgdl(181), GlucoseColors.high);
      expect(GlucoseColors.forMgdl(300), GlucoseColors.high);
    });
    test('the three palette colours are distinct', () {
      expect({GlucoseColors.low, GlucoseColors.inRange, GlucoseColors.high}.length, 3);
    });
  });

  group('time formatters', () {
    final t = DateTime(2026, 7, 6, 9, 5, 3);
    test('formatHhmm pads to HH:MM', () => expect(formatHhmm(t), '09:05'));
    test('formatHhmmss appends seconds', () => expect(formatHhmmss(t), '09:05:03'));
    test('formatShortDateTime is M/D HH:MM', () {
      expect(formatShortDateTime(t), '7/6 09:05');
    });
    test('midnight formats as 00:00', () {
      expect(formatHhmm(DateTime(2026, 1, 1)), '00:00');
    });
  });
}
