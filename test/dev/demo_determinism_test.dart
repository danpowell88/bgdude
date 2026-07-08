/// The demo seam must be deterministic given a fixed `now` -- this is what
/// makes an on-device displayed-value assertion (integration_test/) safe to write at
/// all, instead of flaking depending on when the suite happens to run. This proves the
/// underlying claim at the pure-Dart level (runs here, no emulator needed); the actual
/// on-device stability proof ("run twice on a device") is a separate,
/// emulator-blocked verification step -- see the backlog task's comment.
library;

import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/dev/demo_history.dart';
import 'package:bgdude/dev/sim_data.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 8, 9, 15);

  group('SimulatedDay.generate is deterministic for a fixed now', () {
    test('two independent calls with the same now produce an identical CGM trace',
        () {
      final a = SimulatedDay.generate(now: now);
      final b = SimulatedDay.generate(now: now);

      expect(a.cgm.length, b.cgm.length);
      for (var i = 0; i < a.cgm.length; i++) {
        expect(a.cgm[i].mgdl, b.cgm[i].mgdl,
            reason: 'sample $i diverged between two calls with the same now');
        expect(a.cgm[i].time, b.cgm[i].time);
      }
      // The specific value a displayed-value assertion would check.
      expect(a.cgm.last.mgdl, b.cgm.last.mgdl);
    });

    test('a different now produces a different trace (sanity check -- the fixture '
        'is not just a hardcoded constant)', () {
      final a = SimulatedDay.generate(now: now);
      final c = SimulatedDay.generate(now: now.add(const Duration(hours: 6)));
      expect(a.cgm.last.time, isNot(c.cgm.last.time));
    });
  });

  group('DemoHistory.build is deterministic for a fixed now', () {
    test('two independent calls with the same now produce identical bundles', () {
      final a = DemoHistory.build(now: now);
      final b = DemoHistory.build(now: now);

      expect(a.cgm.length, b.cgm.length);
      expect(a.cgm.map((s) => s.mgdl), b.cgm.map((s) => s.mgdl));
      expect(a.predictions.length, b.predictions.length);
      expect(a.predictions.map((p) => p.predictedMgdl.value),
          b.predictions.map((p) => p.predictedMgdl.value));
    });
  });

  // DemoHistory.demoMeals seeds the demo meal library (via
  // MealLibraryNotifier._restore, providers.dart) -- this was the one demo-seed path
  // that missed routing through demoClockProvider, so a fixed-now integration test
  // checking a meal's "logged X ago"/outcome time still flaked by wall-clock run time.
  group('DemoHistory.demoMeals is deterministic for a fixed now', () {
    test('two independent calls with the same now produce identical meals '
        '(names, ids and outcome timestamps)', () {
      final a = DemoHistory.demoMeals(now: now);
      final b = DemoHistory.demoMeals(now: now);

      expect(a.length, b.length);
      expect(a, isNotEmpty, reason: 'the fixture must actually seed something');
      for (var i = 0; i < a.length; i++) {
        expect(a[i].id, b[i].id, reason: 'meal $i id diverged');
        expect(a[i].name, b[i].name, reason: 'meal $i name diverged');
        expect(a[i].outcomes.length, b[i].outcomes.length,
            reason: 'meal $i outcome count diverged');
        for (var j = 0; j < a[i].outcomes.length; j++) {
          expect(a[i].outcomes[j].eatenAt, b[i].outcomes[j].eatenAt,
              reason: 'meal $i outcome $j eatenAt diverged -- this is exactly '
                  'what a "logged X ago" display assertion would flake on');
        }
      }
    });

    test('a different now produces different outcome timestamps (sanity check '
        '-- not just a hardcoded fixture)', () {
      final a = DemoHistory.demoMeals(now: now);
      final c = DemoHistory.demoMeals(now: now.add(const Duration(days: 3)));
      expect(
          a.expand((m) => m.outcomes).map((o) => o.eatenAt),
          isNot(c.expand((m) => m.outcomes).map((o) => o.eatenAt)));
    });
  });

  // DemoHistory.demoMeals was always deterministic as a pure function --
  // the actual bug was one caller (MealLibraryNotifier._restore) passing the raw
  // wall clock instead of the injected one. This exercises the REAL fix site, not
  // just the already-correct pure function -- and specifically checks the notifier's
  // seeded meals against the PURE function's own fixed-`now` output directly (not
  // just two notifiers against each other), since a real wall-clock read would
  // essentially never coincidentally match a fixed test fixture down to the
  // millisecond, whereas two notifier constructions microseconds apart still might.
  // Deliberately a DIFFERENT fixture than `now` above (a clearly-historical date, not
  // whatever today happens to be) -- a fixed fixture that coincidentally shares
  // today's date would let a reversion to the real wall clock pass undetected if
  // demoMeals only varies by day, not exact time.
  group('MealLibraryNotifier seeds deterministically for a fixed clock', () {
    final fixedNow = DateTime(2020, 1, 15, 9, 15);
    setUp(KvStore.useMemory);

    test(
        "a notifier's seeded meals match DemoHistory.demoMeals' direct output "
        'for the same fixed clock', () async {
      final expected = DemoHistory.demoMeals(now: fixedNow);
      final notifier = MealLibraryNotifier(demo: true, now: () => fixedNow);
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero); // let _restore() finish

      expect(notifier.state.meals.length, expected.length);
      expect(notifier.state.meals, isNotEmpty);
      for (var i = 0; i < expected.length; i++) {
        expect(
            notifier.state.meals[i].outcomes.map((o) => o.eatenAt),
            expected[i].outcomes.map((o) => o.eatenAt),
            reason: 'meal $i outcome timestamps do not match the pure '
                "function's fixed-now output -- the notifier must be reading "
                'the real wall clock instead of the injected one');
      }
    });
  });
}
