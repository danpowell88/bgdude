import 'package:bgdude/core/samples.dart';
import 'package:bgdude/insights/ketone_risk.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/samples.dart';

List<CgmSample> _sustainedHigh(DateTime now, double mgdl) =>
    sustained(end: now, mgdl: mgdl);

void main() {
  const det = KetoneRiskDetector();
  final now = DateTime(2026, 7, 4, 15);

  test('sustained high + illness → check ketones', () {
    final r = det.detect(
      cgm: _sustainedHigh(now, 300),
      iobUnits: 2.0,
      illnessActive: true,
      now: now,
    );
    expect(r.suggestCheck, isTrue);
    expect(r.reason.toLowerCase(), contains('sick'));
  });

  test('sustained high + likely site failure → check ketones', () {
    final r = det.detect(
      cgm: _sustainedHigh(now, 300),
      iobUnits: 3.0,
      illnessActive: false,
      likelySiteIssue: true,
      now: now,
    );
    expect(r.suggestCheck, isTrue);
    expect(r.reason.toLowerCase(), contains('site'));
  });

  test('very high with almost no insulin on board → check ketones', () {
    final r = det.detect(
      cgm: _sustainedHigh(now, 320),
      iobUnits: 0.1,
      illnessActive: false,
      now: now,
    );
    expect(r.suggestCheck, isTrue);
    expect(r.reason.toLowerCase(), contains('insulin'));
  });

  test('a plain high with insulin working is NOT flagged', () {
    final r = det.detect(
      cgm: _sustainedHigh(now, 300),
      iobUnits: 4.0, // correcting
      illnessActive: false,
      likelySiteIssue: false,
      now: now,
    );
    expect(r.suggestCheck, isFalse);
  });

  test('not high enough → no prompt even when unwell', () {
    final r = det.detect(
      cgm: _sustainedHigh(now, 200), // below the 270 threshold
      iobUnits: 0.0,
      illnessActive: true,
      now: now,
    );
    expect(r.suggestCheck, isFalse);
  });

  test('recovering (last reading back down) → no prompt', () {
    final cgm = [
      ..._sustainedHigh(now.subtract(const Duration(minutes: 10)), 300),
      CgmSample(time: now, mgdl: 150), // came down
    ];
    final r = det.detect(
      cgm: cgm,
      iobUnits: 0.0,
      illnessActive: true,
      now: now,
    );
    expect(r.suggestCheck, isFalse);
  });

  test('P0-7: very high AND rising → prompt even with insulin working', () {
    // Ascending series from 260 → 340 (all above the 250 base threshold), ending
    // very high (>300) and still rising, with a normal correction IOB. Old logic
    // treated this as "a correction in progress"; P0-7 flags it.
    final cgm = [
      for (var i = 0; i < 25; i++)
        CgmSample(
          time: now.subtract(Duration(minutes: 5 * i)),
          mgdl: 340 - i * 4.0, // i=0 (now) = 340, older = lower
        ),
    ];
    final r = det.detect(
      cgm: cgm,
      iobUnits: 4.0, // correcting, but still climbing
      illnessActive: false,
      likelySiteIssue: false,
      now: now,
    );
    expect(r.suggestCheck, isTrue);
    expect(r.reason.toLowerCase(), contains('rising'));
  });

  test('P0-7: sustained high at 260 + illness prompts (base threshold now 250)', () {
    final r = det.detect(
      cgm: _sustainedHigh(now, 260), // between the old 270 and new 250 thresholds
      iobUnits: 2.0,
      illnessActive: true,
      now: now,
    );
    expect(r.suggestCheck, isTrue);
  });

  test('too few readings → no prompt', () {
    final r = det.detect(
      cgm: [CgmSample(time: now, mgdl: 320)],
      iobUnits: 0.0,
      illnessActive: true,
      now: now,
    );
    expect(r.suggestCheck, isFalse);
  });
}
