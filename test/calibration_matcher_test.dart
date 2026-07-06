import 'package:bgdude/analytics/calibration_matcher.dart';
import 'package:bgdude/core/samples.dart';
import 'package:flutter_test/flutter_test.dart';

/// TASK-63 AC#1: the ±15-min / ±20% calibration matching heuristic.
void main() {
  const matcher = CalibrationMatcher();
  final t = DateTime(2026, 7, 7, 8);

  CgmSample sensor(int min, double mgdl) =>
      CgmSample(time: t.add(Duration(minutes: min)), mgdl: mgdl);
  CgmSample meter(int min, double mgdl) => CgmSample(
      time: t.add(Duration(minutes: min)),
      mgdl: mgdl,
      isCalibration: true,
      source: GlucoseSource.meter);

  test('matches a finger-prick to the nearest sensor reading within 15 min', () {
    final matches = matcher.match([
      sensor(0, 100),
      sensor(10, 110), // nearest to the 12-min meter reading
      sensor(20, 130),
      meter(12, 118),
    ]);
    expect(matches, hasLength(1));
    expect(matches.single.sensorMgdl, 110);
    expect(matches.single.gap, const Duration(minutes: 2));
  });

  test('agrees within 20%, disagrees beyond it', () {
    final ok = matcher.match([sensor(0, 100), meter(1, 118)]).single; // +18%
    expect(matcher.agrees(ok), isTrue);
    final off = matcher.match([sensor(0, 100), meter(1, 130)]).single; // +30%
    expect(matcher.agrees(off), isFalse);
  });

  test('a finger-prick with no sensor reading within the window is skipped', () {
    final matches = matcher.match([sensor(0, 100), meter(40, 120)]); // 40 min gap
    expect(matches, isEmpty);
  });

  test('calibrations are never treated as the sensor side of a match', () {
    // Two meter readings, one sensor: only the meter↔sensor pair matches, not meter↔meter.
    final matches = matcher.match([meter(0, 90), sensor(2, 100), meter(4, 110)]);
    expect(matches, hasLength(2));
    for (final m in matches) {
      expect(m.sensorMgdl, 100);
    }
  });
}
