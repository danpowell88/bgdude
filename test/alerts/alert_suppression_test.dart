/// Snooze, acknowledge and content dedup (issue #107).
library;

import 'package:bgdude/alerts/alert_suppression.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 7, 4, 3);
const _low = NotificationCategory.predictedLow;
const _urgent = NotificationCategory.urgentLow;

String _sig(double mgdl, {NotificationCategory c = _low}) =>
    alertSignature(category: c, valueMgdl: mgdl);

bool _allowed(
  AlertSuppressionState state, {
  NotificationCategory category = _low,
  double mgdl = 61,
  DateTime? at,
}) =>
    alertAllowed(
      category: category,
      signature: _sig(mgdl, c: category),
      state: state,
      now: at ?? _now,
    );

void main() {
  test('an unsuppressed alert fires', () {
    expect(_allowed(AlertSuppressionState.empty), isTrue);
  });

  group('snooze', () {
    test('silences the category for its duration', () {
      final state = AlertSuppressionState.empty
          .snooze(_low, _now, const Duration(minutes: 30));

      expect(_allowed(state), isFalse);
      expect(_allowed(state, at: _now.add(const Duration(minutes: 31))), isTrue);
    });

    test('silences regardless of what the alert would say', () {
      // A snooze is "leave me alone", not "dismiss on the merits".
      final state = AlertSuppressionState.empty
          .snooze(_low, _now, const Duration(minutes: 30));

      expect(_allowed(state, mgdl: 61), isFalse);
      expect(_allowed(state, mgdl: 40), isFalse);
    });

    test('does not affect other categories', () {
      final state = AlertSuppressionState.empty
          .snooze(_low, _now, const Duration(minutes: 30));

      expect(
        _allowed(state, category: NotificationCategory.predictedHigh),
        isTrue,
      );
    });

    test('an URGENT LOW can never be snoozed', () {
      // The one alert whose entire purpose is to interrupt. A mistaken tap at 3am,
      // by someone who is by definition not at their sharpest, must not defeat it.
      final state = AlertSuppressionState.empty
          .snooze(_urgent, _now, const Duration(hours: 2));

      expect(_allowed(state, category: _urgent), isTrue);
    });

    test('clear removes it', () {
      final state = AlertSuppressionState.empty
          .snooze(_low, _now, const Duration(minutes: 30))
          .clear(_low);

      expect(_allowed(state), isTrue);
    });
  });

  group('acknowledge', () {
    test('stays quiet while the alert would say the same thing', () {
      final state =
          AlertSuppressionState.empty.acknowledge(_low, _sig(61), _now);

      // Hours later — an acknowledgement is signature-based, not time-based.
      final later = _now.add(const Duration(hours: 3));
      expect(_allowed(state, mgdl: 61, at: later), isFalse);
      expect(_allowed(state, mgdl: 65, at: later), isFalse,
          reason: '61 and 65 bucket the same — same news');
    });

    test('speaks again when the situation materially changes', () {
      // "I've dealt with it" applies to the situation described, not to every future
      // version of it. A low that keeps falling is new information.
      final state =
          AlertSuppressionState.empty.acknowledge(_low, _sig(61), _now);

      expect(
        _allowed(state, mgdl: 45, at: _now.add(const Duration(hours: 1))),
        isTrue,
      );
    });

    test('a materially worse reading breaks through IMMEDIATELY', () {
      // Deliberately no time-based quiet window. A low crashing from 61 to 45 must
      // not stay silent because the user acknowledged the milder version of it two
      // minutes earlier. `snooze` is the tool for "quiet for a period regardless".
      final state =
          AlertSuppressionState.empty.acknowledge(_low, _sig(61), _now);

      expect(_allowed(state, mgdl: 45, at: _now), isTrue);
    });

    test('but the SAME news stays quiet immediately after acknowledging', () {
      final state =
          AlertSuppressionState.empty.acknowledge(_low, _sig(61), _now);

      expect(_allowed(state, mgdl: 61, at: _now), isFalse);
    });
  });

  group('alertSignature', () {
    test('buckets so a one-point wobble is the same news', () {
      expect(_sig(61), _sig(65));
      expect(_sig(61), isNot(_sig(55)));
    });

    test('different categories never collide', () {
      expect(
        alertSignature(category: _low, valueMgdl: 61),
        isNot(alertSignature(
            category: NotificationCategory.predictedHigh, valueMgdl: 61)),
      );
    });

    test('is stable for the same inputs', () {
      expect(_sig(61), _sig(61));
    });
  });

  group('materiallyWorse', () {
    test('for a low, worse means lower', () {
      expect(
        materiallyWorse(category: _low, previousMgdl: 70, nextMgdl: 55),
        isTrue,
      );
      expect(
        materiallyWorse(category: _low, previousMgdl: 70, nextMgdl: 85),
        isFalse,
        reason: 'rising is not worse for a low',
      );
    });

    test('for a high, worse means higher', () {
      const high = NotificationCategory.predictedHigh;
      expect(
        materiallyWorse(category: high, previousMgdl: 200, nextMgdl: 240),
        isTrue,
      );
      expect(
        materiallyWorse(category: high, previousMgdl: 200, nextMgdl: 180),
        isFalse,
      );
    });

    test('a small move is not material', () {
      expect(
        materiallyWorse(category: _low, previousMgdl: 70, nextMgdl: 65),
        isFalse,
      );
    });
  });

  group('persistence', () {
    test('round-trips a snooze and an acknowledgement', () {
      final state = AlertSuppressionState.empty
          .snooze(_low, _now, const Duration(minutes: 30))
          .acknowledge(NotificationCategory.predictedHigh, 'x', _now);

      final decoded = AlertSuppressionState.decode(state.encode());

      expect(decoded.suppressions[_low]!.acknowledgedSignature, isNull);
      expect(
        decoded.suppressions[NotificationCategory.predictedHigh]!
            .acknowledgedSignature,
        'x',
      );
    });

    test('corrupt state fails OPEN', () {
      // A damaged file must never silently mute an alert.
      for (final bad in [null, '', 'not json', '[]', '{"predictedLow":5}']) {
        final decoded = AlertSuppressionState.decode(bad);
        expect(decoded.suppressions, isEmpty, reason: '$bad');
        expect(_allowed(decoded), isTrue, reason: '$bad');
      }
    });

    test('suppression survives a restart', () {
      // The whole reason it is persisted: two evaluators in two processes, plus an
      // app that can be killed at any moment.
      final state = AlertSuppressionState.empty
          .snooze(_low, _now, const Duration(minutes: 30));

      expect(_allowed(AlertSuppressionState.decode(state.encode())), isFalse);
    });
  });

  group('clock changes', () {
    test('an absurdly far-future suppression is ignored', () {
      // A backwards clock change would otherwise mute a category indefinitely. A
      // stuck mute is the dangerous direction.
      final state = AlertSuppressionState.empty
          .snooze(_low, _now, const Duration(days: 30));

      expect(_allowed(state), isTrue);
    });

    test('a legitimate long snooze is still honoured', () {
      final state = AlertSuppressionState.empty
          .snooze(_low, _now, const Duration(hours: 2));

      expect(_allowed(state), isFalse);
    });
  });
}
