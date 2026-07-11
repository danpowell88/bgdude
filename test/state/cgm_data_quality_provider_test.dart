/// TASK-141: cgmDataQualityProvider surfaces whether the MOST RECENT CGM reading
/// falls inside a detected jump/flatline/dropout-edge fault window -- a live signal
/// distinct from CgmFaultDetector itself (which just returns raw windows over history).
library;

import 'package:bgdude/core/samples.dart';
import 'package:bgdude/ml/event_detectors.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/samples.dart';

void main() {
  DayData dayData(List<CgmSample> cgm) => DayData(
        start: DateTime(2026, 7, 4),
        end: DateTime(2026, 7, 5),
        cgm: cgm,
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: testTherapySettings(),
        context: null,
        isSimulated: false,
      );

  ProviderContainer build(List<CgmSample> cgm) => ProviderContainer(overrides: [
        dayDataProvider.overrideWithValue(dayData(cgm)),
      ]);

  test('null when the latest reading is clean', () {
    final cgm = [
      for (var i = 0; i < 5; i++)
        CgmSample(
            time: DateTime(2026, 7, 4, 8, 5 * i), mgdl: 120.0 + i),
    ];
    final c = build(cgm);
    addTearDown(c.dispose);
    expect(c.read(cgmDataQualityProvider), isNull);
  });

  test('flags the current fault kind when the latest reading is inside a jump',
      () {
    final cgm = [
      CgmSample(time: DateTime(2026, 7, 4, 8, 0), mgdl: 100),
      CgmSample(time: DateTime(2026, 7, 4, 8, 5), mgdl: 100),
      CgmSample(time: DateTime(2026, 7, 4, 8, 10), mgdl: 180), // implausible jump
    ];
    final c = build(cgm);
    addTearDown(c.dispose);
    expect(c.read(cgmDataQualityProvider), CgmFaultKind.jump);
  });

  test('empty CGM -> null, no throw', () {
    final c = build(const []);
    addTearDown(c.dispose);
    expect(() => c.read(cgmDataQualityProvider), returnsNormally);
    expect(c.read(cgmDataQualityProvider), isNull);
  });
}
