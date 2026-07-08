import 'package:bgdude/core/samples.dart';
import 'package:bgdude/insights/anomaly_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 5, 12);
  const detector = AnomalyDetector();

  List<CgmSample> series(List<double> mgdls, {List<int>? compressionAt}) => [
        for (var i = 0; i < mgdls.length; i++)
          CgmSample(
            // Oldest first, 5 min apart, last sample at `now`.
            time: now.subtract(Duration(minutes: 5 * (mgdls.length - 1 - i))),
            mgdl: mgdls[i],
            compressionLow: compressionAt?.contains(i) ?? false,
          ),
      ];

  test('flags a rise the model does not expect', () {
    final r = detector.detect(
      cgm: series([120, 135, 150, 165]), // +3 mg/dL/min
      expectedRocMgdlPerMin: 0, // carbs/insulin predicted ~flat
      now: now,
    );
    expect(r.detected, isTrue);
    expect(r.observedRocMgdlPerMin, closeTo(3.0, 0.01));
    expect(r.reason.toLowerCase(), contains('climbing'));
  });

  test('flags a faster-than-expected drop', () {
    final r = detector.detect(
      cgm: series([190, 175, 150, 130]), // -4 mg/dL/min
      expectedRocMgdlPerMin: 0,
      now: now,
    );
    expect(r.detected, isTrue);
    expect(r.reason.toLowerCase(), contains('dropping'));
  });

  test('no anomaly when the move matches expectation', () {
    final r = detector.detect(
      cgm: series([120, 135, 150, 165]),
      expectedRocMgdlPerMin: 3.0, // model expected exactly this rise
      now: now,
    );
    expect(r.detected, isFalse);
  });

  test('ignores small wiggles', () {
    final r = detector.detect(
      cgm: series([120, 122, 124, 125]), // move < 30 mg/dL
      expectedRocMgdlPerMin: 0,
      now: now,
    );
    expect(r.detected, isFalse);
  });

  test('excludes compression-low samples so a pressure dip is not an anomaly', () {
    final r = detector.detect(
      cgm: series([120, 120, 120, 70], compressionAt: [3]),
      expectedRocMgdlPerMin: 0,
      now: now,
    );
    expect(r.detected, isFalse);
  });

  test('needs enough samples/span', () {
    expect(detector.detect(cgm: series([120, 165]), expectedRocMgdlPerMin: 0, now: now)
        .detected, isFalse);
  });
}
