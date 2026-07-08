import 'package:bgdude/insights/alert_monitor.dart';
import 'package:bgdude/ml/forecaster.dart';
import 'package:flutter_test/flutter_test.dart';

/// Matrix tests for the pure alert decision core. Given a forecast + current
/// reading, [AlertMonitor.evaluate] must pick the right alert (or none), deterministically.
void main() {
  const monitor = AlertMonitor(
    lowMgdl: 70,
    urgentLowMgdl: 55,
    highMgdl: 200,
    cooldown: Duration.zero,
  );
  final now = DateTime(2026, 7, 7, 12);

  HorizonForecast fc(double m) =>
      HorizonForecast(horizonMinutes: 30, mgdl: m, lowerMgdl: m, upperMgdl: m);

  GlucoseAlert? decide({required double current, required double forecastMin}) =>
      monitor.evaluate(
        forecasts: [fc(forecastMin)],
        currentMgdl: current,
        now: now,
        lastFired: const {},
      );

  group('decision matrix', () {
    const cases = <({double current, double forecastMin, GlucoseAlertKind? kind})>[
      // Forecast dips below the urgent line (and we're above it now) → urgent low.
      (current: 90, forecastMin: 50, kind: GlucoseAlertKind.urgentLow),
      // Forecast dips below low (but not urgent) → predicted low.
      (current: 90, forecastMin: 65, kind: GlucoseAlertKind.predictedLow),
      // Forecast climbs above high (and we're below it) → predicted high.
      (current: 150, forecastMin: 220, kind: GlucoseAlertKind.predictedHigh),
      // Comfortably in range, no excursion → nothing.
      (current: 120, forecastMin: 115, kind: null),
      // Already below the low line: the dip-from-above guard suppresses a fresh low alert.
      (current: 60, forecastMin: 50, kind: null),
    ];

    for (final c in cases) {
      test('current ${c.current}, forecast ${c.forecastMin} → ${c.kind}', () {
        final alert = decide(current: c.current, forecastMin: c.forecastMin);
        expect(alert?.kind, c.kind);
      });
    }
  });

  group('§4-x exercise suppresses highs, never lows', () {
    GlucoseAlert? decideEx({
      required double current,
      required double forecastExtreme,
      required bool exercising,
    }) =>
        monitor.evaluate(
          forecasts: [fc(forecastExtreme)],
          currentMgdl: current,
          now: now,
          lastFired: const {},
          suppressPredictedHigh: exercising,
        );

    test('a predicted high is muted during a workout', () {
      expect(decideEx(current: 150, forecastExtreme: 220, exercising: false)?.kind,
          GlucoseAlertKind.predictedHigh);
      expect(decideEx(current: 150, forecastExtreme: 220, exercising: true), isNull);
    });

    test('a predicted/urgent low still fires during a workout', () {
      expect(decideEx(current: 90, forecastExtreme: 65, exercising: true)?.kind,
          GlucoseAlertKind.predictedLow);
      expect(decideEx(current: 90, forecastExtreme: 50, exercising: true)?.kind,
          GlucoseAlertKind.urgentLow);
    });
  });

  test('cooldown suppresses a repeat within the window', () {
    const cooled = AlertMonitor(
      urgentLowMgdl: 55,
      lowMgdl: 70,
      highMgdl: 200,
      cooldown: Duration(minutes: 30),
    );
    final forecasts = [fc(50)];
    final first = cooled.evaluate(
        forecasts: forecasts, currentMgdl: 90, now: now, lastFired: const {});
    expect(first?.kind, GlucoseAlertKind.urgentLow);
    // A fire 5 min ago is still within the 30-min cooldown → suppressed.
    final second = cooled.evaluate(
      forecasts: forecasts,
      currentMgdl: 90,
      now: now,
      lastFired: {GlucoseAlertKind.urgentLow: now.subtract(const Duration(minutes: 5))},
    );
    expect(second, isNull);
  });

  group('TASK-303: urgentLow fires independently of lowMgdl (defense-in-depth '
      'against a mis-ordered/corrupt threshold config)', () {
    test(
        'a mis-ordered config (lowMgdl BELOW urgentLowMgdl) still fires '
        'urgentLow for a dip between the two -- the exact suppress-a-genuine-'
        'hypo bug this guards against', () {
      // AlertThresholds.fromJson now rejects a mis-ordered persisted triple back
      // to defaults (TASK-303), so this specific AlertMonitor config shouldn't
      // arise from a normal restore any more -- but AlertMonitor itself must not
      // rely on that upstream guard alone. Constructing it directly here is
      // exactly what a corrupt/tampered value bypassing that guard would look
      // like from AlertMonitor's point of view.
      const misordered = AlertMonitor(
        lowMgdl: 40, // corrupted below urgentLowMgdl
        urgentLowMgdl: 55,
        highMgdl: 200,
        cooldown: Duration.zero,
      );
      final alert = misordered.evaluate(
        forecasts: [fc(50)], // between the two -- genuinely urgent
        currentMgdl: 90,
        now: now,
        lastFired: const {},
      );

      expect(alert?.kind, GlucoseAlertKind.urgentLow,
          reason: 'the old nested check gated urgentLow on `minF.mgdl < '
              'lowMgdl` -- with lowMgdl=40, 50 < 40 is false, so the whole '
              'branch was skipped and NEITHER alert fired for a genuine ~50 '
              'mg/dL predicted low');
    });

    test(
        'the same mis-ordered config still fires nothing for a dip that is '
        'above BOTH thresholds', () {
      const misordered = AlertMonitor(
        lowMgdl: 40,
        urgentLowMgdl: 55,
        highMgdl: 200,
        cooldown: Duration.zero,
      );
      final alert = misordered.evaluate(
        forecasts: [fc(60)], // above both 40 and 55 -- not actually a low
        currentMgdl: 90,
        now: now,
        lastFired: const {},
      );

      expect(alert, isNull);
    });

    test(
        'a correctly-ordered config fires identically to before the '
        'restructure -- the independent urgentLow check does not change '
        'normal behaviour', () {
      // Same cases as the top-level decision matrix, re-asserted here so a
      // future change to the branch order/gating is caught by this group too.
      expect(decide(current: 90, forecastMin: 50)?.kind,
          GlucoseAlertKind.urgentLow);
      expect(decide(current: 90, forecastMin: 65)?.kind,
          GlucoseAlertKind.predictedLow);
      expect(decide(current: 60, forecastMin: 50), isNull,
          reason: 'already below the low line -- the dip-from-above guard '
              'must still suppress a fresh low alert, unchanged');
    });
  });
}
