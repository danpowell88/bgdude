import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/integrations/glucose_meter.dart';
import 'package:bgdude/integrations/glucose_meter_service.dart';
import 'package:bgdude/integrations/glucose_meter_transport.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTransport implements GlucoseMeterTransport {
  _FakeTransport(this.records);
  List<GlucoseMeterReading> records;
  int? lastSinceSeq;

  @override
  Future<bool> isAvailable() async => true;
  @override
  Stream<MeterDevice> scan({Duration timeout = const Duration(seconds: 12)}) =>
      const Stream.empty();
  @override
  Future<void> stopScan() async {}
  @override
  Future<List<GlucoseMeterReading>> fetchRecords(String deviceId,
      {int? sinceSeq}) async {
    lastSinceSeq = sinceSeq;
    return records;
  }
}

GlucoseMeterReading _r(int seq, int hour, double mgdl) => GlucoseMeterReading(
    sequenceNumber: seq, time: DateTime(2026, 7, 5, hour), mgdl: mgdl);

void main() {
  setUp(KvStore.useMemory);

  test('first sync imports all records as calibration samples', () async {
    final repo = InMemoryHistoryRepository();
    final transport = _FakeTransport([_r(1, 8, 100), _r(2, 12, 140), _r(3, 18, 90)]);
    final svc = GlucoseMeterService(transport: transport, repository: repo);

    final out = await svc.sync('meter-1');
    expect(out.imported, 3);
    expect(out.lastSeq, 3);
    expect(transport.lastSinceSeq, isNull); // nothing synced before

    final saved = await repo.cgm(DateTime(2026, 7, 4), DateTime(2026, 7, 6));
    expect(saved.length, 3);
    expect(saved.every((s) => s.isCalibration), isTrue);
  });

  test('incremental sync only imports records past the high-water mark', () async {
    final repo = InMemoryHistoryRepository();
    final transport = _FakeTransport([_r(1, 8, 100), _r(2, 12, 140)]);
    final svc = GlucoseMeterService(transport: transport, repository: repo);
    await svc.sync('meter-1'); // lastSeq = 2

    // Meter re-reports 2 (already seen) plus two new ones.
    transport.records = [_r(2, 12, 140), _r(3, 15, 110), _r(4, 20, 75)];
    final out = await svc.sync('meter-1');
    expect(out.imported, 2); // only 3 and 4
    expect(out.lastSeq, 4);
    expect(transport.lastSinceSeq, 2); // asked the meter for records after 2

    final saved = await repo.cgm(DateTime(2026, 7, 4), DateTime(2026, 7, 6));
    expect(saved.length, 4); // 2 + 2, no duplicate of seq 2
  });

  test('re-syncing already-seen records imports nothing', () async {
    final repo = InMemoryHistoryRepository();
    final transport = _FakeTransport([_r(1, 8, 100), _r(2, 12, 140)]);
    final svc = GlucoseMeterService(transport: transport, repository: repo);
    await svc.sync('meter-1');

    final out = await svc.sync('meter-1'); // same records again
    expect(out.imported, 0);
    expect(out.lastSeq, 2);
  });

  test('a reading stamped in the future flags meter clock skew', () async {
    final repo = InMemoryHistoryRepository();
    // Newest reading is at 18:00 while the phone thinks it's 10:00 → meter clock ~8h fast.
    final transport = _FakeTransport([_r(1, 8, 100), _r(2, 18, 140)]);
    final svc = GlucoseMeterService(transport: transport, repository: repo);
    final out = await svc.sync('meter-1', now: () => DateTime(2026, 7, 5, 10));
    expect(out.clockSkew, isNotNull);
    expect(out.clockSkew!.inHours, 8);
    expect(out.imported, 2); // still imported
  });

  test('readings within tolerance report no clock skew', () async {
    final repo = InMemoryHistoryRepository();
    final transport = _FakeTransport([_r(1, 8, 100), _r(2, 18, 140)]);
    final svc = GlucoseMeterService(transport: transport, repository: repo);
    // Phone is at 20:00 — the newest reading (18:00) is in the past, no skew.
    final out = await svc.sync('meter-1', now: () => DateTime(2026, 7, 5, 20));
    expect(out.clockSkew, isNull);
  });

  test('reset clears the high-water mark (re-import from scratch)', () async {
    final repo = InMemoryHistoryRepository();
    final transport = _FakeTransport([_r(5, 8, 100)]);
    final svc = GlucoseMeterService(transport: transport, repository: repo);
    await svc.sync('meter-1');
    expect(await svc.lastSequence(), 5);

    await svc.reset();
    expect(await svc.lastSequence(), isNull);
    final out = await svc.sync('meter-1');
    expect(out.imported, 1); // seq 5 re-imported after reset
  });
}
