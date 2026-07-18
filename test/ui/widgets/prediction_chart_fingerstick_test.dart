/// Finger-pricks are drawn as their own marks, not folded into the CGM trace (issue #77).
library;

import 'package:bgdude/core/samples.dart';
import 'package:flutter/material.dart';
import 'package:bgdude/ui/widgets/prediction_chart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a meter-sourced reading is a fingerstick', () {
    expect(
      PredictionChart.isFingerstick(
          CgmSample(time: DateTime(2026), mgdl: 100, source: GlucoseSource.meter)),
      isTrue,
    );
  });

  test('a calibration-flagged reading is a fingerstick', () {
    // Entered to calibrate rather than imported from a meter: same kind of
    // measurement, different flag depending on how it arrived.
    expect(
      PredictionChart.isFingerstick(
          CgmSample(time: DateTime(2026), mgdl: 100, isCalibration: true)),
      isTrue,
    );
  });

  test('an ordinary sensor reading is not', () {
    expect(
      PredictionChart.isFingerstick(CgmSample(time: DateTime(2026), mgdl: 100)),
      isFalse,
    );
  });

  test('a Nightscout-sourced reading is not a fingerstick', () {
    // Guards the check being written as "not sensor" — a follower-mode reading is
    // still a sensor measurement and must stay in the CGM trace.
    expect(
      PredictionChart.isFingerstick(CgmSample(
          time: DateTime(2026), mgdl: 100, source: GlucoseSource.sensor)),
      isFalse,
    );
  });

  test('the fingerstick colour is distinct from every other series', () {
    // Sharing a colour with a forecast line would make a meter reading look like a
    // scenario, which is the confusion this whole change exists to remove.
    const scheme = ColorScheme.light();
    final fingerstick = PredictionChart.seriesColor('Fingerstick', scheme);
    for (final other in ['Predicted', 'IOB', 'COB', 'UAM', 'Zero-temp']) {
      expect(PredictionChart.seriesColor(other, scheme), isNot(fingerstick),
          reason: other);
    }
  });
}
