import 'package:bgdude/insights/alert_monitor.dart';
import 'package:bgdude/ml/forecaster.dart';
import 'package:flutter_test/flutter_test.dart';

/// TASK-37 AC#1: matrix tests for the pure alert decision core. Given a forecast + current
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

  group('§4-x TASK-93: exercise suppresses highs, never lows', () {
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
}
