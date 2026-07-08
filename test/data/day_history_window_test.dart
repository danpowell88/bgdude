/// The live day window must stay bounded and honest — `state.cgm` trims
/// to the rolling 24 h window on every ingest (the persisted repository keeps the
/// full history), and crossing local midnight re-anchors the window so "today"
/// never quietly becomes "since app launch".
library;

import 'package:bgdude/data/database.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:bgdude/state/day_history_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/samples.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DriftHistoryRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftHistoryRepository(db);
  });
  tearDown(() => db.close());

  PumpSnapshot snapAt(DateTime t, {int mgdl = 120}) =>
      PumpSnapshot(time: t, cgmMgdl: mgdl, cgmTime: t);

  test('state.cgm is trimmed to the rolling 24 h window on ingest', () async {
    var now = DateTime(2026, 7, 6, 6); // 06:00, so a 26 h run stays mid-day
    final controller = DayHistoryController(
      repo: repo,
      settings: testTherapySettings(),
      clock: () => now,
    );
    await Future<void>.delayed(Duration.zero); // let the initial reload finish

    // 26 hours of 5-min readings — unbounded growth would reach 313 samples.
    final start = now;
    for (var i = 0; i <= 26 * 12; i++) {
      now = start.add(Duration(minutes: 5 * i));
      await controller.ingestSnapshot(snapAt(now));
    }

    final window = controller.state.end.difference(controller.state.cgm.first.time);
    expect(window.inHours, lessThanOrEqualTo(24));
    // 24 h at 5-min cadence is 289 samples inclusive; the cap must hold there.
    expect(controller.state.cgm.length, lessThanOrEqualTo(289));
    expect(controller.state.cgm.last.time, now);
    expect(controller.state.start,
        now.subtract(const Duration(hours: 24)));
  });

  test('crossing local midnight rolls the window (reload re-anchors)', () async {
    var now = DateTime(2026, 7, 6, 23, 50);
    final controller = DayHistoryController(
      repo: repo,
      settings: testTherapySettings(),
      clock: () => now,
    );
    await Future<void>.delayed(Duration.zero);

    await controller.ingestSnapshot(snapAt(now));
    expect(controller.state.cgm, hasLength(1));

    // Next reading lands after midnight → the window must re-anchor via reload.
    now = DateTime(2026, 7, 7, 0, 5);
    await controller.ingestSnapshot(snapAt(now));

    expect(controller.state.end, now);
    expect(controller.state.start, now.subtract(const Duration(hours: 24)));
    // Both readings are inside the rolled window and survive the reload.
    expect(controller.state.cgm.length, 2);
  });

  test('a same-day gap does not trigger a roll', () async {
    var now = DateTime(2026, 7, 6, 8);
    final controller = DayHistoryController(
      repo: repo,
      settings: testTherapySettings(),
      clock: () => now,
    );
    await Future<void>.delayed(Duration.zero);

    await controller.ingestSnapshot(snapAt(now));
    now = DateTime(2026, 7, 6, 15); // hours later, same local date
    await controller.ingestSnapshot(snapAt(now));
    expect(controller.state.cgm.length, 2);
  });
}
