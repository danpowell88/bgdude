/// TASK-185: the main isolate (read/write) and the WorkManager summary backstop
/// (read-only, see `background_summary.dart`) open independent connections to the
/// same encrypted WAL file. WAL lets readers and a writer proceed concurrently, but
/// a reader can still collide briefly with a writer mid-checkpoint; without
/// `busy_timeout` that raises SQLITE_BUSY immediately instead of waiting the
/// checkpoint out.
///
/// Note: this deliberately does NOT test two connections both *writing* — drift
/// itself warns that multiple live `AppDatabase` instances on one file race and can
/// corrupt data (see the "multiple databases" warning in its FAQ), no matter how
/// long `busy_timeout` is. If a second writer is ever introduced, it needs a shared
/// connection (e.g. drift's isolate-remoting), not just this PRAGMA.
library;

import 'dart:io';

import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/database.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the shared open path sets busy_timeout', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final rows = await db.customSelect('PRAGMA busy_timeout').get();
    final timeout = rows.single.data.values.first as int;
    expect(timeout, greaterThanOrEqualTo(5000));
  });

  test(
      'a writer and a concurrent reader on one file DB never hit SQLITE_BUSY',
      () async {
    final dir = Directory.systemTemp.createTempSync('bgdude_db_test');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    final file = File('${dir.path}${Platform.pathSeparator}shared.db');

    // Two independent connections — the main-isolate (writer) + backstop
    // (read-only) shape from background_summary.dart.
    final writer = AppDatabase(NativeDatabase(file));
    final reader = AppDatabase(NativeDatabase(file));

    final repoWriter = DriftHistoryRepository(writer);
    final repoReader = DriftHistoryRepository(reader);
    final t0 = DateTime(2026, 7, 4);
    final window = t0.add(const Duration(hours: 2));

    // Interleave 25 writes on one connection with 25 reads on the other.
    await Future.wait([
      for (var i = 0; i < 25; i++) ...[
        repoWriter.saveCgm(
            [CgmSample(time: t0.add(Duration(minutes: 2 * i)), mgdl: 100)]),
        repoReader.cgm(t0, window),
      ],
    ]);

    final all = await repoWriter.cgm(t0, window);
    expect(all, hasLength(25), reason: 'every write must land');

    await writer.close();
    await reader.close();
  });
}
