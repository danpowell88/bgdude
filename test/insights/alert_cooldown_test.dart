/// Alert cooldowns must survive wall-clock discontinuities. A DST
/// fall-back makes `now - lastFired` negative for an hour; the gate must fail OPEN
/// (re-alert eligible) — a suppressed urgent low during the repeated hour is a
/// safety failure. All times injected.
library;

import 'package:bgdude/alerts/alert_orchestrator.dart';
import 'package:bgdude/insights/alert_monitor.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:bgdude/ml/forecaster.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CooldownGate', () {
    const c = NotificationCategory.urgentLow;
    const repeat = Duration(minutes: 15);

    test('first fire is always eligible, repeat gated by the interval', () {
      final gate = CooldownGate();
      final t0 = DateTime(2026, 4, 5, 2, 30);
      expect(gate.passed(c, t0, repeat), isTrue);
      gate.markFired(c, t0);
      expect(gate.passed(c, t0.add(const Duration(minutes: 5)), repeat), isFalse);
      expect(gate.passed(c, t0.add(const Duration(minutes: 15)), repeat), isTrue);
    });

    test('backward clock jump (DST fall-back): urgent-low still re-fires', () {
      final gate = CooldownGate();
      // Fired at 02:30 AEDT; the 03:00 fall-back replays 02:00-03:00, so the next
      // evaluation sees wall-clock 01:40 — elapsed is NEGATIVE. Must be eligible.
      gate.markFired(c, DateTime(2026, 4, 5, 2, 30));
      expect(gate.passed(c, DateTime(2026, 4, 5, 1, 40), repeat), isTrue);
    });

    test('forward clock jump expires the cooldown (fail-open, extra alert ok)', () {
      final gate = CooldownGate();
      gate.markFired(c, DateTime(2026, 10, 4, 1, 55));
      expect(gate.passed(c, DateTime(2026, 10, 4, 3, 5), repeat), isTrue);
    });

    test('categories are tracked independently', () {
      final gate = CooldownGate();
      final t0 = DateTime(2026, 7, 4, 12);
      gate.markFired(NotificationCategory.urgentLow, t0);
      expect(
          gate.passed(NotificationCategory.predictedLow,
              t0.add(const Duration(minutes: 1)), repeat),
          isTrue);
    });
  });

  group('AlertMonitor cooldown across a backward jump', () {
    HorizonForecast low(int minutes) => HorizonForecast(
        horizonMinutes: minutes, mgdl: 50, lowerMgdl: 40, upperMgdl: 60);

    test('urgent-low re-fires when the clock has jumped back', () {
      const monitor = AlertMonitor(cooldown: Duration(minutes: 30));
      final firedAt = DateTime(2026, 4, 5, 2, 30);
      final nowAfterJump = DateTime(2026, 4, 5, 1, 40); // fall-back replay hour
      final alert = monitor.evaluate(
        forecasts: [low(20)],
        currentMgdl: 100,
        now: nowAfterJump,
        lastFired: {GlucoseAlertKind.urgentLow: firedAt},
      );
      expect(alert, isNotNull);
      expect(alert!.kind, GlucoseAlertKind.urgentLow);
    });

    test('normal cooldown still suppresses within the interval', () {
      const monitor = AlertMonitor(cooldown: Duration(minutes: 30));
      final firedAt = DateTime(2026, 7, 4, 12);
      final alert = monitor.evaluate(
        forecasts: [low(20)],
        currentMgdl: 100,
        now: firedAt.add(const Duration(minutes: 10)),
        lastFired: {GlucoseAlertKind.urgentLow: firedAt},
      );
      expect(alert, isNull);
    });
  });
}
