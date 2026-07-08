/// TASK-170 convention guard: tests must be deterministic regardless of when
/// they run. `DateTime.now()` in a test couples behaviour to the wall clock
/// (and DST/local-midnight edges) and rots into flakiness.
///
/// Convention: anchor to a fixed instant (e.g. `DateTime(2026, 7, 4, 12)`).
/// When production code itself reads the wall clock (until TASK-39 injects
/// clocks) a relative `now` is unavoidable — mark the line with a justification
/// comment: `DateTime.now(); // now-ok: <why>`.
///
/// TASK-237: walks both `test/` and `integration_test/` (demo mode advances
/// on real time there, the highest-risk spot) and every `.dart` file in each
/// (not just `*_test.dart`) — a stray `DateTime.now()` in a support/fixture
/// file couples every test that imports it.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every DateTime.now() under test/ and integration_test/ carries a '
      'now-ok justification', () {
    final offenders = <String>[];
    final files = ['test', 'integration_test']
        .expand((root) => Directory(root).listSync(recursive: true))
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('.dart') &&
            !f.path.endsWith('no_wall_clock_guard_test.dart'));
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!line.contains('DateTime.now()')) continue;
        if (line.contains('now-ok')) continue;
        offenders.add('${f.path}:${i + 1}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Anchor these to fixed instants, or justify with '
            '"// now-ok: <reason>" if production reads the wall clock:\n'
            '${offenders.join('\n')}');
  });
}
