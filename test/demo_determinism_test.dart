/// TASK-220: the demo seam must be deterministic given a fixed `now` -- this is what
/// makes an on-device displayed-value assertion (integration_test/) safe to write at
/// all, instead of flaking depending on when the suite happens to run. This proves the
/// underlying claim at the pure-Dart level (runs here, no emulator needed); the actual
/// on-device stability proof (AC#4's "run twice on a device") is a separate,
/// emulator-blocked verification step -- see the TASK-220 backlog comment.
library;

import 'package:bgdude/dev/demo_history.dart';
import 'package:bgdude/dev/sim_data.dart';
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
}
