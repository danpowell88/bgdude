import 'package:bgdude/analytics/bolus_advisor.dart';
import 'package:bgdude/analytics/predictor.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/samples.dart';

void main() {
  final now = DateTime(2026, 7, 4, 12);
  final settings = testTherapySettings(maxBolusUnits: 15);

  PredictionState state({
    required double bg,
    double roc = 0,
    List<BolusEvent> boluses = const [],
    ControlIqState controlIq = ControlIqState.off,
  }) =>
      PredictionState(
        now: now,
        currentMgdl: bg,
        recentRocMgdlPerMin: roc,
        boluses: boluses,
        basal: const [],
        carbs: const [],
        settings: settings,
        controlIq: controlIq,
      );

  group('ControlIqState.stepDelta', () {
    test('off contributes nothing anywhere', () {
      expect(ControlIqState.off.stepDelta(300, 5), 0);
      expect(ControlIqState.off.stepDelta(50, 5), 0);
    });

    test('pulls down above the band, up below it, nothing inside', () {
      const s = ControlIqState.standard;
      expect(s.stepDelta(300, 5), lessThan(0)); // high → basal up / auto-correct
      expect(s.stepDelta(120, 5), 0); // inside 70–160 band
      expect(s.stepDelta(55, 5), greaterThan(0)); // low → basal suspended
    });

    test('Standard has stronger downward authority than Sleep (auto-corrections)', () {
      // At the same high, Standard (basal + auto-bolus) pulls down harder than Sleep
      // (basal only).
      expect(ControlIqState.standard.stepDelta(300, 5).abs(),
          greaterThan(ControlIqState.sleep.stepDelta(300, 5).abs()));
    });
  });

  group('predictor closed-loop modulation', () {
    test('Control-IQ off leaves a flat high excursion unchanged', () {
      final line = GlucosePredictor().predict(state(bg: 300));
      // No insulin/carbs/momentum and loop off → stays pinned near 300.
      expect(line.endMgdl, closeTo(300, 1));
    });

    test('Standard mode drags a sustained high back toward the band', () {
      final off = GlucosePredictor().predict(state(bg: 300));
      final ciq = GlucosePredictor()
          .predict(state(bg: 300, controlIq: ControlIqState.standard));
      expect(ciq.endMgdl, lessThan(off.endMgdl - 20));
    });

    test('Standard corrects a high faster than Sleep', () {
      final standard = GlucosePredictor()
          .predict(state(bg: 300, controlIq: ControlIqState.standard));
      final sleep = GlucosePredictor()
          .predict(state(bg: 300, controlIq: ControlIqState.sleep));
      expect(standard.endMgdl, lessThan(sleep.endMgdl));
    });

    test('the closed loop lifts the nadir of a predicted low', () {
      // A brisk downward trend carries BG below the band; the loop suspends basal and
      // softens the low so the nadir sits higher than the open-loop projection.
      final off = GlucosePredictor().predict(state(bg: 95, roc: -3.0));
      final ciq = GlucosePredictor()
          .predict(state(bg: 95, roc: -3.0, controlIq: ControlIqState.standard));
      expect(ciq.minMgdl, greaterThan(off.minMgdl));
    });
  });

  group('bolus advisor Control-IQ awareness', () {
    test('Standard mode halves a standalone correction and explains why', () {
      final off = BolusAdvisor().advise(state(bg: 250));
      final ciq = BolusAdvisor()
          .advise(state(bg: 250, controlIq: ControlIqState.standard));
      expect(ciq.correctionUnits, closeTo(off.correctionUnits / 2, 0.1));
      expect(
          ciq.notes.any((n) => n.toLowerCase().contains('auto-correct')), isTrue);
    });

    test('Sleep mode keeps the full correction but flags no auto-correction', () {
      final off = BolusAdvisor().advise(state(bg: 250));
      final ciq =
          BolusAdvisor().advise(state(bg: 250, controlIq: ControlIqState.sleep));
      expect(ciq.correctionUnits, closeTo(off.correctionUnits, 0.1));
      expect(ciq.notes.any((n) => n.toLowerCase().contains('sleep')), isTrue);
    });
  });

  group('PumpSnapshot Control-IQ parsing', () {
    test('parses closed-loop flag and user mode', () {
      final snap = PumpSnapshot.fromJson({
        'timestampEpochMs': 1,
        'closedLoopEnabled': true,
        'controlIqMode': 'EXERCISE',
      });
      expect(snap.closedLoopEnabled, true);
      expect(snap.controlIqMode, ControlIqMode.exercise);
    });

    test('missing Control-IQ fields default to unknown / null', () {
      final snap = PumpSnapshot.fromJson({'timestampEpochMs': 1});
      expect(snap.closedLoopEnabled, isNull);
      expect(snap.controlIqMode, ControlIqMode.unknown);
    });
  });
}
