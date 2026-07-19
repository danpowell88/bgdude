/// Headless alert evaluation (issues #51 / #28, stage 3).
///
/// The isolate wiring needs a device; the decision does not, and the decision is where
/// a mistake means a missed urgent low or a duplicate 3am alert.
library;

import 'package:bgdude/alerts/headless_alert_watch.dart';
import 'package:bgdude/insights/alert_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 7, 4, 3);

/// Readings every 5 minutes ending at [_now], falling by [perStep] each step.
List<({DateTime time, double mgdl})> _falling(
  double from, {
  double perStep = -10,
  int count = 6,
}) =>
    [
      for (var i = count - 1; i >= 0; i--)
        (
          time: _now.subtract(Duration(minutes: 5 * i)),
          mgdl: from + perStep * (count - 1 - i),
        ),
    ];

void main() {
  group('AlertFireLog', () {
    test('round-trips through JSON', () {
      final log = AlertFireLog.empty
          .withFired(GlucoseAlertKind.urgentLow, _now)
          .withFired(GlucoseAlertKind.predictedLow, _now);

      final decoded = AlertFireLog.decode(log.encode());

      expect(decoded.lastFired[GlucoseAlertKind.urgentLow], _now);
      expect(decoded.lastFired[GlucoseAlertKind.predictedLow], _now);
    });

    test('a corrupt log fails OPEN, not closed', () {
      // Treating an unreadable log as "recently fired" would silently suppress an
      // urgent low — the exact failure this feature exists to prevent.
      for (final bad in [null, '', 'not json', '[]', '{"urgentLow":"soon"}']) {
        expect(AlertFireLog.decode(bad).lastFired, isEmpty, reason: '$bad');
      }
    });

    test('withFired does not mutate the original', () {
      const original = AlertFireLog.empty;
      original.withFired(GlucoseAlertKind.urgentLow, _now);

      expect(original.lastFired, isEmpty);
    });
  });

  group('shouldEvaluateHeadless', () {
    test('stands down when the foreground app evaluated recently', () {
      // The running app has better inputs; a background pass second-guessing it is
      // noise.
      expect(
        shouldEvaluateHeadless(
          lastForegroundEvaluation: _now.subtract(const Duration(minutes: 3)),
          now: _now,
        ),
        isFalse,
      );
    });

    test('evaluates once the foreground has gone quiet', () {
      expect(
        shouldEvaluateHeadless(
          lastForegroundEvaluation: _now.subtract(const Duration(minutes: 20)),
          now: _now,
        ),
        isTrue,
      );
    });

    test('no record at all means evaluate', () {
      // "No evidence the app is alive" must not read as "the app is handling it".
      expect(
        shouldEvaluateHeadless(lastForegroundEvaluation: null, now: _now),
        isTrue,
      );
    });

    test('a clock change fails open', () {
      // Evaluating twice is a nuisance; missing an urgent low is not.
      expect(
        shouldEvaluateHeadless(
          lastForegroundEvaluation: _now.add(const Duration(hours: 2)),
          now: _now,
        ),
        isTrue,
      );
    });
  });

  group('projectFromRecent', () {
    test('projects a falling trend forward', () {
      final f = projectFromRecent(_falling(120), now: _now);

      expect(f, hasLength(2));
      // Falling 10 per 5 min = -2/min; 30 min out from 70 lands near 10, clamped.
      expect(f.last.mgdl.value, lessThan(f.first.mgdl.value));
    });

    test('refuses to extrapolate from a single reading', () {
      final f = projectFromRecent(
        [(time: _now, mgdl: 100)],
        now: _now,
      );

      expect(f, isEmpty);
    });

    test('refuses to extrapolate STALE data', () {
      // A reading from 25 minutes ago projected forward 30 is a guess about an hour
      // that already happened.
      final stale = [
        (time: _now.subtract(const Duration(minutes: 30)), mgdl: 120.0),
        (time: _now.subtract(const Duration(minutes: 25)), mgdl: 110.0),
      ];

      expect(projectFromRecent(stale, now: _now), isEmpty);
    });

    test('ignores readings from the future', () {
      final f = projectFromRecent(
        [
          (time: _now.add(const Duration(minutes: 10)), mgdl: 50.0),
          ..._falling(120),
        ],
        now: _now,
      );

      expect(f, isNotEmpty);
      // The future reading must not drag the projection down.
      expect(f.first.mgdl.value, greaterThan(20));
    });

    test('clamps to a physiological range', () {
      final f = projectFromRecent(_falling(90, perStep: -30), now: _now);

      expect(f.every((h) => h.mgdl.value >= 20), isTrue);
    });

    test('the band is wide, because this is an extrapolation', () {
      final f = projectFromRecent(_falling(150, perStep: -2), now: _now).first;

      expect(f.upperMgdl.value - f.lowerMgdl.value, greaterThanOrEqualTo(50));
    });

    test('empty input yields no forecast', () {
      expect(projectFromRecent(const [], now: _now), isEmpty);
    });
  });

  group('evaluateHeadless', () {
    test('fires on a steep fall toward a low', () {
      // Starts at 150 and ends at 100 — still ABOVE the low threshold, which is the
      // only case a *predicted* low applies to. (A trace already below 70 is a
      // current low, handled elsewhere; the monitor correctly declines it.)
      final alert = evaluateHeadless(
        readings: _falling(150),
        fireLog: AlertFireLog.empty,
        now: _now,
        lastForegroundEvaluation: null,
      );

      expect(alert, isNotNull);
      expect(
        alert!.kind,
        anyOf(GlucoseAlertKind.predictedLow, GlucoseAlertKind.urgentLow),
      );
    });

    test('does not fire when the foreground app is alive', () {
      // Same readings that DO fire below — the difference is only the heartbeat.
      final alert = evaluateHeadless(
        readings: _falling(150),
        fireLog: AlertFireLog.empty,
        now: _now,
        lastForegroundEvaluation: _now.subtract(const Duration(minutes: 2)),
      );

      expect(alert, isNull);
    });

    test('respects the shared cooldown from the persisted log', () {
      // The whole reason the log is persisted: two evaluators in two processes must
      // not each fire the same alert.
      final justFired = AlertFireLog.empty
          .withFired(GlucoseAlertKind.predictedLow, _now)
          .withFired(GlucoseAlertKind.urgentLow, _now);

      final alert = evaluateHeadless(
        readings: _falling(150),
        fireLog: justFired,
        now: _now,
        lastForegroundEvaluation: null,
      );

      expect(alert, isNull);
      // Guard against passing vacuously: the SAME readings with an empty log must
      // fire, or this test proves nothing about the cooldown.
      expect(
        evaluateHeadless(
          readings: _falling(150),
          fireLog: AlertFireLog.empty,
          now: _now,
          lastForegroundEvaluation: null,
        ),
        isNotNull,
      );
    });

    test('a steady in-range trace fires nothing', () {
      final alert = evaluateHeadless(
        readings: _falling(120, perStep: 0),
        fireLog: AlertFireLog.empty,
        now: _now,
        lastForegroundEvaluation: null,
      );

      expect(alert, isNull);
    });

    test('predicted HIGH is suppressed headlessly', () {
      // No exercise state is available here, so a predicted high cannot be told from
      // workout noise. A false high at 3am erodes trust in the alerts that matter.
      final alert = evaluateHeadless(
        readings: _falling(200, perStep: 15),
        fireLog: AlertFireLog.empty,
        now: _now,
        lastForegroundEvaluation: null,
      );

      expect(alert?.kind, isNot(GlucoseAlertKind.predictedHigh));
    });

    test('no readings fires nothing', () {
      expect(
        evaluateHeadless(
          readings: const [],
          fireLog: AlertFireLog.empty,
          now: _now,
          lastForegroundEvaluation: null,
        ),
        isNull,
      );
    });
  });

  group('AlertWatchStore', () {
    test('the heartbeat round-trips', () {
      final beat = AlertWatchStore.encodeBeat(_now);
      expect(AlertWatchStore.decodeBeat(beat), _now);
    });

    test('an unreadable heartbeat decodes to null, so the watch evaluates', () {
      // "Cannot tell whether the app is alive" must resolve to evaluating, not to
      // assuming the app has it covered.
      for (final bad in [null, '', '  ', 'not a date']) {
        expect(AlertWatchStore.decodeBeat(bad), isNull, reason: '$bad');
        expect(
          shouldEvaluateHeadless(
            lastForegroundEvaluation: AlertWatchStore.decodeBeat(bad),
            now: _now,
          ),
          isTrue,
        );
      }
    });

    test('the two keys are distinct', () {
      // One key holding both would make a heartbeat clobber the cooldown log.
      expect(AlertWatchStore.fireLogKey,
          isNot(AlertWatchStore.foregroundBeatKey));
    });
  });
}
