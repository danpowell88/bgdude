/// Net-basal insulin effect (issue #16).
///
/// The predictor treated every delivered basal unit as active drug with nothing
/// representing endogenous glucose production, so a well-tuned fasting user looked
/// permanently, extremely insulin-resistant and corrections collapsed toward zero.
/// `netBasalSegments` re-expresses delivered basal as deviation-from-schedule, which
/// encodes "scheduled basal offsets EGP".
///
/// The headline test is the fasting case: it fails on the old gross-basal behaviour
/// (a real, large downward insulin activity) and passes only once basal is netted.
library;

import 'package:bgdude/analytics/insulin_math.dart';
import 'package:bgdude/analytics/predictor.dart';
import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/core/samples.dart';
import 'package:flutter_test/flutter_test.dart';

/// A flat schedule so expected values stay hand-checkable.
TherapySettings _flat(double basalRate) => TherapySettings(
      segments: [
        TherapySegment(
          startMinuteOfDay: 0,
          isf: 50,
          carbRatio: 10,
          targetMgdl: 110,
          basalUnitsPerHour: basalRate,
        ),
      ],
    );

/// Morning 0.8 U/h, from 12:00 1.4 U/h — for the boundary-splitting test.
TherapySettings get _twoSegment => const TherapySettings(
      segments: [
        TherapySegment(
            startMinuteOfDay: 0,
            isf: 50,
            carbRatio: 10,
            targetMgdl: 110,
            basalUnitsPerHour: 0.8),
        TherapySegment(
            startMinuteOfDay: 12 * 60,
            isf: 50,
            carbRatio: 10,
            targetMgdl: 110,
            basalUnitsPerHour: 1.4),
      ],
    );

void main() {
  const iob = IobCalculator();

  group('netBasalSegments', () {
    test('basal delivered exactly as scheduled nets to zero', () {
      final start = DateTime(2026, 7, 4, 2);
      final delivered = [
        BasalSegment(
            start: start, end: start.add(const Duration(hours: 6)), unitsPerHour: 1.0),
      ];

      final net = netBasalSegments(delivered, _flat(1.0));

      expect(net, isNotEmpty);
      for (final s in net) {
        expect(s.unitsPerHour, closeTo(0.0, 1e-9));
      }
    });

    test('over-delivery nets positive, under-delivery nets negative', () {
      final start = DateTime(2026, 7, 4, 2);
      BasalSegment seg(double rate) => BasalSegment(
          start: start, end: start.add(const Duration(hours: 1)), unitsPerHour: rate);

      expect(netBasalSegments([seg(1.5)], _flat(1.0)).first.unitsPerHour,
          closeTo(0.5, 1e-9));
      // A suspend is a real upward force relative to the baseline the body expects,
      // so the sign has to survive — clamping at zero would silently discard it.
      expect(netBasalSegments([seg(0.0)], _flat(1.0)).first.unitsPerHour,
          closeTo(-1.0, 1e-9));
    });

    test('a segment spanning a schedule change is split at the boundary', () {
      // 11:00 -> 13:00 crosses the 12:00 step from 0.8 to 1.4 U/h.
      final delivered = [
        BasalSegment(
            start: DateTime(2026, 7, 4, 11),
            end: DateTime(2026, 7, 4, 13),
            unitsPerHour: 1.0),
      ];

      final net = netBasalSegments(delivered, _twoSegment);

      final before =
          net.where((s) => s.start.isBefore(DateTime(2026, 7, 4, 12))).toList();
      final after =
          net.where((s) => !s.start.isBefore(DateTime(2026, 7, 4, 12))).toList();
      expect(before, isNotEmpty);
      expect(after, isNotEmpty);
      // Netting against ONE rate for the whole span would give a single wrong answer;
      // the split is what makes each slice net against the rate actually scheduled.
      for (final s in before) {
        expect(s.unitsPerHour, closeTo(0.2, 1e-9)); // 1.0 - 0.8
      }
      for (final s in after) {
        expect(s.unitsPerHour, closeTo(-0.4, 1e-9)); // 1.0 - 1.4
      }
    });

    test('total duration and slice continuity are preserved', () {
      final start = DateTime(2026, 7, 4, 8);
      final delivered = [
        BasalSegment(
            start: start, end: start.add(const Duration(minutes: 47)), unitsPerHour: 1.0),
      ];

      final net = netBasalSegments(delivered, _flat(0.9));

      // No time invented or lost — an off-grid length must not be rounded away.
      final covered = net.fold<int>(
          0, (sum, s) => sum + s.end.difference(s.start).inMinutes);
      expect(covered, 47);
      expect(net.first.start, start);
      expect(net.last.end, start.add(const Duration(minutes: 47)));
      for (var i = 1; i < net.length; i++) {
        expect(net[i].start, net[i - 1].end, reason: 'slices must not gap or overlap');
      }
    });

    test('a zero-length or inverted segment is dropped, not emitted', () {
      final t = DateTime(2026, 7, 4, 8);
      expect(netBasalSegments([BasalSegment(start: t, end: t, unitsPerHour: 1)],
              _flat(1.0)),
          isEmpty);
      expect(
          netBasalSegments([
            BasalSegment(
                start: t, end: t.subtract(const Duration(hours: 1)), unitsPerHour: 1)
          ], _flat(1.0)),
          isEmpty);
    });
  });

  group('the bug this fixes', () {
    test(
        'a well-tuned fasting user has ~zero insulin activity from basal, instead '
        'of a large phantom downward force', () {
      // Fasting: no boluses, no carbs, basal delivered exactly as scheduled for a
      // full insulin duration (6h) before the moment we evaluate.
      final at = DateTime(2026, 7, 4, 8);
      final delivered = [
        BasalSegment(
          start: at.subtract(const Duration(hours: 8)),
          end: at,
          unitsPerHour: 1.0,
        ),
      ];
      final settings = _flat(1.0);

      final gross = iob.fromBasal(delivered, at);
      final net = iob.fromBasal(netBasalSegments(delivered, settings), at);

      // The old behaviour: a substantial standing insulin activity that the model
      // had to explain away as the user being extremely insulin-resistant.
      expect(gross.activityUnitsPerMin, greaterThan(0.002),
          reason: 'guards the premise — if gross activity were already ~0 this test '
              'would pass for the wrong reason');
      // The fix: netted against schedule, a fasting well-tuned user exerts no net
      // insulin force, so nothing has to be explained away.
      expect(net.activityUnitsPerMin, closeTo(0.0, 1e-9));
      expect(net.units, closeTo(0.0, 1e-9));
    });

    test('a real bolus still produces its full effect after netting', () {
      // Netting must not damp genuine insulin — only the scheduled-basal baseline.
      final at = DateTime(2026, 7, 4, 8);
      final settings = _flat(1.0);
      final delivered = [
        BasalSegment(
            start: at.subtract(const Duration(hours: 8)), end: at, unitsPerHour: 1.0),
      ];
      final boluses = [
        BolusEvent(time: at.subtract(const Duration(minutes: 75)), units: 4.0),
      ];

      final bolusOnly = iob.fromBoluses(boluses, at);
      final combined = iob.total(
          boluses, netBasalSegments(delivered, settings), at);

      expect(combined.activityUnitsPerMin,
          closeTo(bolusOnly.activityUnitsPerMin, 1e-9));
      expect(combined.units, closeTo(bolusOnly.units, 1e-9));
    });

    test('the Zero-temp line stays at or above the ordinary line', () {
      // The safety property of that line: suspending basal can only remove downward
      // insulin force, so its trajectory must never sit BELOW the normal one. Before
      // #16 the line modelled suspension by deleting basal, which under net semantics
      // would mean "delivered exactly as scheduled" — the opposite — and would flatten
      // the one line whose job is showing whether suspending rescues a low.
      final now = DateTime(2026, 7, 4, 8);
      final settings = _flat(1.0);
      final state = PredictionState(
        now: now,
        currentMgdl: 90,
        recentRocMgdlPerMin: -0.5,
        boluses: [BolusEvent(time: now.subtract(const Duration(minutes: 40)), units: 2)],
        basal: [
          BasalSegment(
              start: now.subtract(const Duration(hours: 6)), end: now, unitsPerHour: 1.0),
        ],
        carbs: const [],
        settings: settings,
      );

      final lines = GlucosePredictor().scenarioLines(state);
      final normal = lines.firstWhere((l) => l.label == 'COB');
      final zeroTemp = lines.firstWhere((l) => l.label == 'Zero-temp');

      expect(zeroTemp.points.length, normal.points.length);
      for (var i = 0; i < normal.points.length; i++) {
        expect(zeroTemp.points[i].mgdl,
            greaterThanOrEqualTo(normal.points[i].mgdl - 1e-9),
            reason: 'suspending basal must never predict LOWER glucose (step $i)');
      }
      // And it must actually differ — an identical line would mean the suspension
      // isn't being modelled at all, which is the regression this guards.
      expect(zeroTemp.points.last.mgdl,
          greaterThan(normal.points.last.mgdl + 1e-6));
    });

    test('a pump suspend during fasting shows as net-negative insulin', () {
      // The mirror image of the headline case, and the reason the sign is kept:
      // suspending basal is a real upward pressure the model must be able to see.
      final at = DateTime(2026, 7, 4, 8);
      final settings = _flat(1.0);
      final suspended = [
        BasalSegment(
            start: at.subtract(const Duration(hours: 2)), end: at, unitsPerHour: 0.0),
      ];

      final net = iob.fromBasal(netBasalSegments(suspended, settings), at);

      expect(net.activityUnitsPerMin, lessThan(0.0));
      expect(net.units, lessThan(0.0));
    });
  });
}
